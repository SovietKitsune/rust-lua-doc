-- Builds documentation output
local generator = require('tealdoc-cli.generator')
local logger = require('tealdoc.logger')
local util = require('tealdoc-cli.util')
local fs = require('tealdoc-cli.fs')

local parser = require('tealdoc.parser')
local tag = require('tealdoc.tag')

local json = require('dkjson')

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
   pages: {string}
   genSources: boolean
   enableSearch: boolean
end

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
   --- `moonlight`:
   ---
   --- This is the "dark" theme inspired by <https://github.com/atomiks/moonlight-vscode-theme>
   ---
   --- `nordic`:
   ---
   --- This is between a "dark" and a "light" them inspired by <https://www.nordtheme.com/>
   theme: Theme
   --- **Only for singular module projects**
   ---
   --- If the type should be flagged as a module forcefully
   forceRootModule: boolean
   --- The extra markdown pages to add to the output
   ---
   --- By default the `readme.md` file will be included
   pages: {string}
   --- Prevent `readme.md` from being included
   noIncludeReadme: boolean
   --- Disables the generation of source files
   noSource: boolean
   --- Disables the search box
   noSearch: boolean
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

local function loadTags(config: Config): {tag.TagConfig}
   local files = {}

   local defaultTags = fs.scriptLocation() .. 'tags/'

   if config.tagStyle == 'ldoc' then
      logger.warn('LDoc support hasn\'t been implemented yet!')
   elseif config.tagStyle == 'tealdoc' or not config.tagStyle then
      fs.searchAll(defaultTags .. 'tealdoc', '%.lua$', files)
   elseif config.tagStyle ~= 'none' then
      logger.error('Unrecognized tag style: ' .. tostring(config.tagStyle))
   end

   config.tags = config.tags or {}

   for i = 1, #config.tags do
      fs.searchAll(config.tags[i], '%.lua$', files)
   end

   local tags = {}

   for i = 1, #files do
      table.insert(tags, util.require(files[i]))
   end

   return tags as {tag.TagConfig}
end

local function main()
   local config = util.require('tealdoc.lua') as Config

   local scriptDir = fs.scriptLocation()

   local spec = fs.search('.*%.rockspec', {'.', 'rockspecs'})

   local rockspec: ConfigRockspec = {}

   if spec then
      rockspec = util.loadGlobalConfig(spec) as ConfigRockspec
   end

   local project: Project = {}

   project.name = config.name or rockspec.package or error('Expected a package name')
   project.version = config.version or rockspec.version or 'Unknown'
   project.functionStyle = config.functionStyle or 'lua'
   project.output = config.output or 'docs'
   project.theme = config.theme or 'moonlight'
   project.pages = config.pages or {}
   project.genSources = not config.noSource
   project.enableSearch = not config.noSearch

   config.source = config.source or fs.exists(config.name) and config.name or '.'

   do
      local hasReadme = false

      for i = 1, #project.pages do
         if project.pages[i] == 'readme.md' then
            hasReadme = true
            break
         end
      end

      if not hasReadme and not config.noIncludeReadme and fs.exists('readme.md') then
         table.insert(project.pages, 'readme.md')
      end
   end

   if not fs.exists(project.output) then
      fs.mkdir(project.output)
   end

   assert(fs.exists(config.source), 'Unable to locate source')

   local tree = fs.dirTree(config.source)

   local state = parser.getReport(tree, false, config.isLua)

   project.sources = state.files

   local mods = parser.extractModules(state, tree)

   local types = {}

   do
      local count = 0
      local first: string

      for i, v in pairs(mods) do
         types[i] = parser.createType(v, state)

         count = count + 1

         first = first or i
      end

      if count == 1 then
         project.module = types[first]
      else
         project.modules = types
      end
   end

   generator.loadBase(project as table, scriptDir .. 'templates')

   local tags = loadTags(config)

   tag.traverse(project.modules or {
      [project.name] = project.module as parser.Type
   }, tags)

   local function genDocument(name: string, tp: parser.Type, save: string)
      local location: string

      -- I feel like this will lead to recursion
      tp.tree = tp.parent and (tp.parent as parser.Type).tree or ''

      tp.name = name

      if tp.kind == 'custom' and not tp.struct.isRecord then
         tp.tree = tp.tree .. '/' .. (save and save or name)

         fs.mkdir(config.output .. '/' .. tp.tree)

         location = config.output .. tp.tree .. '/index.html'

         fs.write(location, generator.gen('module', {
            current = tp
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

         fs.write(location, generator.gen('document', {
            current = tp
         }))
      end

      logger.info('Generated ' .. location)
   end

   if project.module then
      local mod = (project.module as parser.Type)

      assert(not mod.hidden, 'Hiding the entire project sounds a bit stupid doesn\'t it?')

      logger.info('Generating for single module project')

      fs.write(config.output .. '/index.html', generator.gen('module', {
         current = mod
      }))

      logger.info('Generated ' .. config.output .. '/index.html')

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
      fs.write(config.output .. '/index.html', generator.gen('module', {
         current = project
      }))

      logger.info('Generated ' .. config.output .. '/index.html')

      for i, v in pairs((project.modules as {string: parser.Type})) do
         if not v.hidden then
            genDocument(i, v)
         end
      end
   end

   fs.mkdir(config.output .. '/sources')

   if project.genSources then
      for i, v in pairs(project.sources) do
         fs.write(config.output .. '/sources/' .. i:gsub('/', '-') .. '.html', generator.gen('srcdoc', {
            code = v,
            src = true
         }))

         logger.info('Generated ' .. config.output .. '/sources/' .. i:gsub('/', '-') .. '.html')
      end
   end

   fs.copyDir(scriptDir .. 'assets', config.output .. '/assets')

   logger.info('Copied assets to ' .. config.output .. '/assets')

   fs.write(config.output .. '/assets/themes.css', require('tealdoc-cli.theme').css)

   logger.info('Generated ' .. config.output .. '/assets/themes.css')

   if #project.pages > 0 then
      fs.mkdir(config.output .. '/pages')
   end

   for i = 1, #project.pages do
      local name = project.pages[i]

      local contents = fs.read(name)

      fs.write(config.output .. '/pages/' .. name:gsub('/', '-') .. '.html', generator.gen('page', {
         contents = contents,
         page = name
      }))

      logger.info('Generated ' .. config.output .. '/pages/' .. name .. '.html')
   end

   if project.enableSearch then
      logger.info('Generating search indexes')

      local record Index
         name: string
         kind: string
         url: string
         description: string
      end

      local indexes = {} as {Index}

      local function recursiveIndex(current: parser.Type, path: string)
         path = path or ''

         local name: string

         if current.name then
            name = (path ~= '' and path .. '.' or '') .. current.name
         elseif path ~= '' then
            name = path
         end

         if name then
            local location: string

            location = '.' .. (current.tree or current.parent and (current.parent as parser.Type).tree or '')

            if current.kind == 'custom' and not current.struct.isRecord then
               location = location .. '/index.html'
            elseif current.parent and (current.parent as parser.Type).kind == 'custom' and not (current.parent as parser.Type).struct.isRecord then
               location = location .. '/' .. current.name .. '.html'
            elseif current.parent then
               location = location .. '/' .. (current.parent as parser.Type).name .. '.html#' .. (current.kind == 'function' and 'fn.' or 'prop.') .. current.name .. '.html' 
            else
               location = location .. '/' .. current.name .. '.html'
            end

            table.insert(indexes, {
               name = name,
               description = current.description,
               kind = current.kind,
               url = location
            })
         end

         if current.kind == 'custom' then
            for _, tp in pairs(current.struct.fields) do
               if not tp.hidden then
                  if current.name then
                     recursiveIndex(tp, (path ~= '' and path .. '.' or '') .. current.name)
                  else
                     recursiveIndex(tp, path)
                  end
               end
            end
         end
      end

      if project.module then
         recursiveIndex(project.module)
      else
         recursiveIndex({
            kind = 'custom',
            struct = {
               fields = project.modules
            }
         })
      end

      fs.write(config.output .. '/assets/indexes.json', json.encode(indexes as {string: any}))

      logger.info('Generated indexes')
   end
end

--- @{hidden}
return {
   name = 'build',
   main = main
}
