local highlight = require('tealdoc.highlight')
local parser = require('tealdoc.parser')
local logger = require('tealdoc.logger')
local tag = require('tealdoc.tag')

local lunamark = require('lunamark')
local argparse = require('argparse')
local etlua = require('etlua')
local lfs = require('lfs')

--- The configuration passed to templates
local record Project
   name: string
   version: string
   deprecated: boolean | string
   description: string
   module: parser.Type | nil
   modules: {string: parser.Type} | nil
   sources: {string: string}
   functionStyle: string
   output: string
   theme: string
end

--- The user-provided configuration
local record Config
   --- @{hidden}
   enum FunctionStyle
      'lua'
      'moon'
   end
   --- @{hidden}
   enum TagStyle
      'ldoc'
      'tealdoc'
      'none'
   end
   --- @{hidden}
   enum Theme
      'moonlight'
      'light'
   end
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
   functionStyle: FunctionStyle
   --- The output directory, defaults to `docs/`
   output: string
   --- Where to find all the project source files, defaults to current working directory
   source: string
   --- The tag format that should be used, this usually doesn't matter for Teal besides for hiding and deprecations
   ---
   --- The default is `tealdoc`
   ---
   --- `tealdoc`:
   ---
   --- Note that the `-` after `@` is only there to escape the tag
   ---
   --- ```lua
   --- --- This is a cool function
   --- -- @-{param y number}
   --- -- @-{return number}
   --- local function x(y)
   ---    return y
   --- end
   --- ```
   ---
   --- `ldoc`:
   ---
   --- ```lua
   --- --- This is a cool function
   --- -- @tparam number y
   --- -- @treturn number
   --- local function x(y)
   ---    return y
   --- end
   --- ```
   ---
   --- `none`:
   ---
   --- Doesn't preload any tags
   tagStyle: TagStyle
   --- The directories where extra tags are located
   tags: {string}
   --- The theme to use, the theme can be changed on the client side as all styles are loaded
   ---
   ---The theme defaults to `light`.
   ---
   --- `light`:
   ---
   --- This is like one-light but with some changed elements
   ---
   --- `moonlight`
   ---
   --- This is the "dark" theme inspired by <https://github.com/atomiks/moonlight-vscode-theme>
   theme: Theme
   --- **Only for singular module projects**
   ---
   --- If the type should be flagged as a module forcefully
   forceRootModule: boolean
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

local function recursiveDir(path: string, pat: string | nil, current: {string}): {string}
   current = current or {}

   for location in lfs.dir(path) do
      if location ~= '.' and location ~= '..' then

         if lfs.attributes(path .. '/' .. location).mode == 'directory' then
            recursiveDir(path .. '/' .. location, pat, current)
         elseif lfs.attributes(path .. '/' .. location).mode == 'file' and location:match(pat) then
            table.insert(current, path .. '/' .. location)
         end
      end
   end

   return current
end

local function currentLocation(): string
   local str = debug.getinfo(2, 'S').source:sub(2)

   -- The CLI is **never** ran directly from the interpreter

   return str:match('(.*/)')
end

local function read(path: string): string
   local f = assert(io.open(path, 'r'))

   local data = f:read('*a')

   f:close()

   return data
end

local function loadTag(file: string): any
   local data = read(file)

   local fn = assert(load(data, 'tag'))

   return fn()
end

local function loadTags(config: Config): {tag.TagConfig}
   local files = {}

   local defaultTags = currentLocation() .. '/tags/'

   if config.tagStyle == 'ldoc' then
      logger.warn('LDoc support hasn\'t been implemented yet!')
      recursiveDir(defaultTags .. 'ldoc', '%.lua$', files)
   elseif config.tagStyle == 'tealdoc' then
      recursiveDir(defaultTags .. 'tealdoc', '%.lua$', files)
   elseif config.tagStyle ~= 'none' then
      logger.error('Unrecognized tag style: ' .. config.tagStyle)
   end

   config.tags = config.tags or {}

   for i = 1, #config.tags do
      recursiveDir(config.tags[i], '%.lua$', files)
   end

   local tags = {}

   for i = 1, #files do
      table.insert(tags, loadTag(files[i]))
   end

   return tags as {tag.TagConfig}
end

local function write(path: string, data: string)
   local f = assert(io.open(path, 'w'))

   f:write(data)

   f:close()
end

local function loadSpec(spec: string): ConfigRockspec
   local data = read(spec)

   local env = {}

   local fn = assert(load(data, 'rockspec', 't', env))

   if tonumber(_VERSION:match('Lua ([%d%.]+)')) < 5.2 then
      global setfenv: function(function, table)

      -- Lua 5.1 compat
      setfenv(fn, env)
   end

   pcall(fn)

   return env as ConfigRockspec
end

local function loadConfig(contents: string): Config
   -- Dynamic requires in teal
   local fn = assert(load(contents, 'config'))

   return fn() as Config
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
   config.tagStyle = config.tagStyle or 'tealdoc'

   project.output = config.output
   project.theme = config.theme or 'moonlight'

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

   local modSearch = parser.newSearch(tree, false, state)
   local writer = lunamark.writer.html.new({})

   local currentSource: string

   -- Change some defaults since of tailwind messing with them

   writer.link = function(label: string, uri: string, title: string): {string}
      local titleAtt = ''

      if type(title) == 'string' and #title > 0 then
         titleAtt = 'title="' .. title .. '"'
      end

      return {'<a href="', uri, '" class="text-blue-500" ', titleAtt, '>', label, '</a>'}
   end

   writer.header = function(str: string, level: integer): {string}
      local textMaps = {
         '3xl',
         '2xl',
         'xl',
         'lg',
         'base',
         'base'
      }

      return {'<h', tostring(level), ' class="text-', textMaps[level], ' pt-2">', str, '</h', tostring(level), '>'}
   end

   -- We don't want anything else
   writer.template = '$body'

   writer.paragraph = function(str: string): {string}
      return {'<p class="py-2">', str, '</p>'}
   end

   writer.fenced_code = function(code: string, language: string): {string} --;ignore
      if language == 'teal' then
         local tmp = os.tmpname()

         -- *virtual*
         local f = io.open(tmp, 'w')
         f:write(code)
         f:close()

         local root: string

         if not currentSource then
            root = './'
         else
            local currentSlashes = 0

            for i = 1, #currentSource do
               if currentSource:sub(i, i) == '/' then
                  currentSlashes = currentSlashes + 1
               end
            end

            root = './' .. string.rep('../', currentSlashes)
         end

         local tokens = highlight.parse(tmp, modSearch)

         local contents = highlight.fullDocument(tokens, tmp, project.theme, true, root)

         return {'<pre class="code-block"><code>', contents, '</code></pre>'}
      elseif language == 'lua' then
         return {highlight.fastHighlight(code)}
      else
         return {'<pre class="code-block"><code>', code, '</code></pre>'}
      end
   end

   local markdown = lunamark.reader.markdown.new(writer, {
      fenced_code_blocks = true --;ignore
   })

   local scriptDir = currentLocation()
   local cache: {string: function(any): string} = {}

   local function include(filename: string, base: table): string
      base = base or {}

      base.project = project
      base.include = function(f: string, b: table): string
         b = b or {}

         for i, v in pairs(base) do
            b[i] = v
         end

         return include(f, b)
      end

      cache[filename] = cache[filename] or assert(etlua.compile(read(scriptDir .. 'templates/' .. filename)))

      return cache[filename](base)
   end

   -- Templates --
   local humanize = require('tealdoc.humanize')(project as table)

   local module = assert(etlua.compile(read(scriptDir .. 'templates/module.etlua')))
   local document = assert(etlua.compile(read(scriptDir .. 'templates/document.etlua')))

   local function genDocument(name: string, tp: parser.Type, save: string)
      local location: string

      -- I feel like this will lead to recursion
      tp.tree = tp.parent and (tp.parent as parser.Type).tree or ''

      tp.name = name

      currentSource = tp.tree

      if tp.kind == 'custom' and not tp.struct.isRecord then
         tp.tree = tp.tree .. '/' .. (save and save or name)

         currentSource = tp.tree

         lfs.mkdir(config.output .. '/' .. tp.tree)

         location = config.output .. tp.tree .. '/index.html'

         write(location, module({
            project = project,
            current = tp,
            include = include,
            humanize = humanize,
            markdown = markdown,
            highlight = highlight.fastHighlight
         }))

         for i, v in pairs(tp.struct.fields) do
            -- Generate children
            if not v.hidden then
               genDocument(i, v)
            end
         end
      else
         -- Non-modules get a document
         location = config.output .. tp.tree .. '/' .. (save and save or name) .. '.html'

         write(location, document({
            project = project,
            current = tp,
            humanize = humanize,
            markdown = markdown,
            include = include,
            highlight = highlight.fastHighlight
         }))
      end

      logger.info('Generated ' .. location)
      currentLocation = nil
   end

   local tags = loadTags(config)

   tag.traverse(project.modules or {
      [project.name] = project.module as parser.Type
   }, tags)

   if project.module then
      logger.info('Single module project detected!')

      write(config.output .. '/index.html', module({
         current = project.module,
         project = project,
         include = include,
         humanize = humanize,
         markdown = markdown
      }))

      logger.info('Generated ' .. config.output .. '/index.html')

      local mod = (project.module as parser.Type)

      assert(not mod.hidden, 'Hiding the entire project sounds a bit stupid doesn\'t it?')

      if config.forceRootModule then
         mod.struct.isRecord = false
      end

      if mod.struct.isRecord then
         genDocument(project.name, project.module as parser.Type, 'index')
      else
         for i, v in pairs(mod.struct.fields) do
            -- Generate children
            if not v.hidden then
               genDocument(i, v)
            end
         end
      end
   else
      write(config.output .. '/index.html', module({
         current = project,
         project = project,
         include = include,
         humanize = humanize,
         markdown = markdown
      }))

      logger.info('Generated ' .. config.output .. '/index.html')

      for i, v in pairs((project.modules as {string: parser.Type})) do
         if not v.hidden then
            genDocument(i, v)
         end
      end
   end

   -- Generate sources

   lfs.mkdir(config.output .. '/' .. 'sources')

   for i in pairs(project.sources) do
      local tokens = highlight.parse(i, modSearch)

      local contents = highlight.fullDocument(tokens, i, project.theme)

      write(config.output .. '/sources/' .. i:gsub('/', '-') .. '.html', contents)

      logger.info('Generated ' .. config.output .. '/sources/' .. i:gsub('/', '-') .. '.html')
   end
end

--- The main function of the documentation generator as well as the project config
return {
   Project = Project,
   Config = Config,
   main = main
}
