local parser = require('tealdoc.parser')
local logger = require('tealdoc.logger')
local lunamark = require('lunamark')
local argparse = require('argparse')
local etlua = require('etlua')
local toml = require('toml')
local lfs = require('lfs')

local record Project
   enum FunctionStyle
      'lua'
      'moon'
   end
   name: string
   version: string
   deprecated: boolean | string
   description: string
   module: parser.Type | nil
   modules: {string: parser.Type} | nil
   sources: {string: string}
   functionStyle: FunctionStyle
end

local record Config
   name: string
   version: string
   deprecated: boolean | string
   description: string
   ['description-file']: string
   ['is-lua']: boolean
   functionStyle: Project.FunctionStyle
   output: string
   source: string
end

local record ConfigRockspec
   record Description
      summary: string
      detailed: string
   end
   package: string
   version: string
   description: Description
end

-- Everything is described in the config
local argParser = argparse('tealdoc', 'A documentation generator for Teal and by extension Lua')

argParser:option('-c --config', 'The configuration file location', 'tealdoc.toml', io.open)
argParser:flag('-q --quiet', 'Suppress output')

local function dirTree(dir: string, current: {string: string}, depth: string): {string: string}
   local tree = current or {}

   depth = (depth or '') .. (dir:match('.*/(.*)$') or dir)

   if depth ~= '' then
      depth = depth .. '.'
   end

   depth = depth:match('%.*(.*)')

   for path in lfs.dir(dir) do
      if path ~= '.' and path ~= '..' then
         local attributes = lfs.attributes(dir .. '/' .. path)

         if attributes.mode == 'file' and (path:match('%.lua$') or path:match('%.tl$')) then
            tree[depth .. path:match('(.-)%.(.*)')] = dir .. '/' .. path
         elseif attributes.mode == 'directory' then
            dirTree(dir .. '/' .. path, tree, depth)
         end
      end
   end

   return tree
end

local function search(pat: string, dirs: {string}): string
   for i = 1, #dirs do
      if lfs.attributes(dirs[i]) and lfs.attributes(dirs[i]).mode == 'directory' then
         for path in lfs.dir(dirs[i]) do
            if path:match(pat) then
               return path
            end
         end
      end
   end
end

local function read(path: string): string
   local f = assert(io.open(path, 'r'))

   local data = f:read('*a')

   f:close()

   return data
end

local function write(path: string, data: string)
   local f = assert(io.open(path, 'w'))

   f:write(data)

   f:close()
end

local function loadSpec(spec: string): ConfigRockspec
   -- Lua 5.2+ supports passing in an env
   if tonumber(_VERSION:match('Lua ([%d%.]+)')) < 5.2 then
      return {}
   end

   local data = read(spec)

   local env = {}

   local fn = assert(load(data, 'rockspec', 't', env))

   pcall(fn)

   return env as ConfigRockspec
end

local function currentLocation(): string
   local str = debug.getinfo(2, 'S').source:sub(2)

   -- The CLI is **never** ran directly from the interpreter

   return str:match('(.*/)')
end

local function main()
   local parsed = argParser:parse()

   logger.level = 
      (parsed.quiet and 1) or
      (os.getenv('DEBUG') and 5) or
      3

   logger.color = not os.getenv('NO_COLOR')

   local fileContents = (parsed.config as FILE):read('*a')

   local config = toml.parse(fileContents).project as Config
   local rockspec: ConfigRockspec
   -- Fallback to rockspec
   local spec = search('.*%.rockspec', {'.', 'rockspecs'})

   if spec then
      rockspec = loadSpec(spec)
   end

   if not config then
      logger.error('Expected config to have a `[project]` section')

      os.exit(-1)
   end

   local project = {} as Project

   project.name = config.name or rockspec.package or error('Expected package to have a name')
   project.version = config.version or rockspec.version or ''
   project.description =
      config.description or
      (rockspec.description and rockspec.description.detailed or rockspec.description.summary) or
      (config['description-file'] and read(config['description-file'])) or
      (lfs.attributes('readme.md') and read('readme.md')) or
      ''
   project.deprecated = config.deprecated
   project.functionStyle = config.functionStyle or 'lua'

   if not config.source then
      config.source = tostring(config.name)
   end

   config.output = config.output or 'docs'

   if not config.output then
      lfs.mkdir(config.output)
   end

   assert(lfs.attributes(config.source))

   local tree = dirTree(config.source)

   local state = parser.getReport(tree, false, config['is-lua'])

   project.sources = state.files

   local mods = parser.extractModules(state, tree)

   local types = {}
   local count = 0
   local first: string

   for i, v in pairs(mods) do
      types[i] = parser.createType(v, state)

      count = count + 1

      if not first then
         first = i
      end
   end

   if count == 1 then
      project.module = types[first]
   else
      project.modules = types
   end

   local writer = lunamark.writer.html.new({})

   writer.code = function(str: string): string
      local lang, code = str:match('(.-)\n(.*)')

      return '<pre class="language-' .. (lang or '') .. '"><code>' .. (code or '') .. '</code></pre>'
   end

   local markdown = lunamark.reader.markdown.new(writer, {})

   local scriptDir = currentLocation()
   local cache: {string: function(any): string} = {}

   local function include(filename: string): string
      cache[filename] = cache[filename] or etlua.compile(read(scriptDir .. 'templates/' .. filename))

      return cache[filename]({
         project = project
      })
   end

   -- Templates --
   local humanize = require('tealdoc.humanize')(project as table)

   local index = assert(etlua.compile(read(scriptDir .. 'templates/index.etlua')))
   local document = assert(etlua.compile(read(scriptDir .. 'templates/document.etlua')))
   local srcdoc = assert(etlua.compile(read(scriptDir .. 'templates/srcdoc.etlua')))

   local function genDocument(name: string, tp: parser.Type)
      tp.name = name

      write(config.output .. '/' .. name .. '.html', document({
         project = project,
         current = tp,
         humanize = humanize,
         markdown = markdown,
         include = include
      }))

      logger.info('Generated ' .. name .. '.html')
   end

   write(config.output .. '/index.html', index({
      project = project,
      include = include,
      humanize = humanize,
      markdown = markdown
   }))

   logger.info('Generated index.html')

   if project.module then
      --; TODO
   else
      for i, v in pairs((project.modules as {string: parser.Type})) do
         genDocument(i, v)
      end
   end

   -- Generate sources

   for i, v in pairs(project.sources) do
      write(config.output .. '/' .. i:gsub('/', '-') .. '.html', srcdoc({
         code = v,
         include = include
      }))

      logger.info('Generated ' .. i:gsub('/', '-') .. '.html')
   end
end

return {
   Project = Project,
   main = main
}
