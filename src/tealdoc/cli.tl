local parser = require('tealdoc.parser')
local logger = require('tealdoc.logger')
local lunamark = require('lunamark')
local argparse = require('argparse')
local etlua = require('etlua')
local lfs = require('lfs')

--- The configuration passed to templates
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
   output: string
end

--- The user-provided configuration
local record Config
   --- The name of the project, if not provided this will be taken from a rockspec
   name: string
   --- The version of the project, if not provided this will be taken from a rockspec
   version: string
   --- If the project is deprecated and why it was deprecated
   deprecated: boolean | string
   --- The description of the project, if not provided this will be taken from:
   ---
   --- `descriptionFile -> rockspec.description.detailed -> rockspec.description.summary -> readme.md`
   description: string
   --- The file to use for the description
   descriptionFile: string
   --- If the project is written in Lua, defaults to false
   isLua: boolean
   --- The function style, defaults to `lua`
   ---
   --- `lua`:
   ---
   --- ```lua
   --- function foo(bar: baz): baz
   --- ```
   ---
   --- `moon`:
   ---
   --- ```moon
   --- foo = (bar: baz) -> baz
   --- ```
   functionStyle: Project.FunctionStyle
   --- The output directory, defaults to `docs/`
   output: string
   --- Where to find all the project source files, defaults to current working directory
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

local function loadConfig(contents: string): Config
   -- Dynamic requires in teal
   local fn = assert(load(contents, 'config'))

   return fn() as Config
end

local function currentLocation(): string
   local str = debug.getinfo(2, 'S').source:sub(2)

   -- The CLI is **never** ran directly from the interpreter

   return str:match('(.*/)')
end

-- Everything is described in the config
local argParser = argparse('tealdoc', 'A documentation generator for Teal and by extension Lua')

argParser:option('-c --config', 'The configuration file location', 'tealdoc.lua', io.open)
argParser:flag('-q --quiet', 'Suppress output')

--- The entry-point of the CLI
---
--- Flags:
---
--- * `-c`/`--config` - The configuration file location
--- * `-q`/`--quiet` - Suppress output
local function main()
   local parsed = argParser:parse()

   logger.level = 
      (parsed.quiet and 1) or
      (os.getenv('DEBUG') and 5) or
      3

   logger.color = not os.getenv('NO_COLOR')

   local fileContents = (parsed.config as FILE):read('*a')

   local config = loadConfig(fileContents)

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
      (config.descriptionFile and read(config.descriptionFile)) or
      (rockspec.description and rockspec.description.detailed or rockspec.description.summary) or
      (lfs.attributes('readme.md') and read('readme.md')) or
      ''
   project.deprecated = config.deprecated
   project.functionStyle = config.functionStyle or 'lua'

   if not config.source then
      config.source = tostring(config.name)
   end

   config.output = config.output or 'docs'

   project.output = config.output

   if not config.output then
      lfs.mkdir(config.output)
   end

   assert(lfs.attributes(config.source))

   local tree = dirTree(config.source)

   local state = parser.getReport(tree, false, config.isLua)

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

   -- Change some defaults since of tailwind messing with them

   writer.link = function(label: string, uri: string, title: string): {string}
      local titleAtt = ''

      if type(title) == 'string' and #title > 0 then
         titleAtt = 'title="' .. title .. '"'
      end

      return {'<a href="', uri, '" class="text-blue-500" ', titleAtt, '>', label, '</a>'}
   end

   writer.header = function(str: string, level: number): {string}
      local textMaps = {
         '3xl',
         '2xl',
         'xl',
         'lg',
         'base',
         'base'
      }

      return {'<h', tostring(level), ' class="text-', textMaps[level], '">', str, '</h', tostring(level), '>'}
   end

   -- We don't want anything else
   writer.template = '$body'

   writer.paragraph = function(str: string): {string}
      return {'<p class="py-2">', str, '</p>'}
   end

   local markdown = lunamark.reader.markdown.new(writer, {
      fenced_code_blocks = true
   })

   local scriptDir = currentLocation()
   local cache: {string: function(any): string} = {}

   local function include(filename: string, base: table): string
      base = base or {}

      base.project = project

      cache[filename] = cache[filename] or etlua.compile(read(scriptDir .. 'templates/' .. filename))

      return cache[filename](base)
   end

   -- Templates --
   local humanize = require('tealdoc.humanize')(project as table)

   local module = assert(etlua.compile(read(scriptDir .. 'templates/module.etlua')))
   local document = assert(etlua.compile(read(scriptDir .. 'templates/document.etlua')))
   local srcdoc = assert(etlua.compile(read(scriptDir .. 'templates/srcdoc.etlua')))

   local function genDocument(name: string, tp: parser.Type)
      local location: string

      -- I feel like this will lead to recursion
      tp.tree = tp.parent and (tp.parent as parser.Type).tree or ''

      tp.name = name

      if tp.kind == 'custom' and not tp.struct.isRecord then
         tp.tree = tp.tree .. '/' .. name

         lfs.mkdir(config.output .. '/' .. tp.tree)

         location = config.output .. tp.tree .. '/index.html'

         write(location, module({
            project = project,
            current = tp,
            include = include,
            humanize = humanize,
            markdown = markdown
         }))

         for i, v in pairs(tp.struct.fields) do
            -- Generate children
            genDocument(i, v)
         end
      else
         -- Non-modules get a document
         location = config.output .. tp.tree .. '/' .. name .. '.html'

         write(location, document({
            project = project,
            current = tp,
            humanize = humanize,
            markdown = markdown,
            include = include
         }))
      end

      logger.info('Generated ' .. location)
   end

   write(config.output .. '/index.html', module({
      current = project,
      project = project,
      include = include,
      humanize = humanize,
      markdown = markdown
   }))

   logger.info('Generated ' .. config.output .. '/index.html')

   if project.module then
      genDocument(project.name, project.module as parser.Type)
   else
      for i, v in pairs((project.modules as {string: parser.Type})) do
         genDocument(i, v)
      end
   end

   -- Generate sources

   lfs.mkdir(config.output .. '/' .. 'sources')

   for i, v in pairs(project.sources) do
      write(config.output .. '/sources/' .. i:gsub('/', '-') .. '.html', srcdoc({
         code = v,
         include = include
      }))

      logger.info('Generated ' .. config.output .. '/sources/' .. i:gsub('/', '-') .. '.html')
   end
end

--- The main function of the documentation generator as well as the project config
return {
   Project = Project,
   Config = Config,
   main = main
}
