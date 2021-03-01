local parser = require 'out.parser'
local etlua = require 'etlua'
local render = require 'sundown'.render

local markdown = function(str)
   local rendered = render(str)

   -- Questionable code here we go!
   rendered = rendered:gsub('<pre><code class="lua">', '<pre><code class="language-lua">')

   return rendered
end

local function read(file)
   local f = io.open(file, 'r')
   local data = f:read('*a')
   f:close()

   return data
end

local template = etlua.compile(read 'assets/document.etlua')
local srcTemplate = etlua.compile(read 'assets/srcdoc.etlua')

local modules = {
   typed = 'assets/typed.tl'
}

local project = {
   name = 'Typed',
   version = '1.0.0',
   deprecated = false,
   description = 'Free types!',
   modules = {},
   sources = {},
   functionStyle = 'lua'
}

local state = parser.getReport(modules)
local mods = parser.extractModules(state, modules)

local cache = {}

project.sources = state.files

for i, v in pairs(mods) do
   project.modules[i] = parser.createType(v, state)
end

for i, v in pairs(project.sources) do
   -- /tmp/aaa.tl -> -tmp-aaa-tl
   local f = io.open('out/' .. i:gsub('/', '-') .. '.html', 'w')

   f:write(srcTemplate({
      code = v,
      include = function(file)
         if cache[file] then
            return cache[file]()
         end

         local data = read(file)

         cache[file] = assert(etlua.compile(data))

         return cache[file]()
      end
   }))

   f:close()
end

for i, v in pairs(project.modules) do
   local f = io.open('out/' .. i .. '.html', 'w')

   v.name = i
   v.srcDoc = v.src

   local templateState

   templateState = {
      project = project,
      current = v,
      markdown = markdown,
      include = function(file)
         if cache[file] then
            return cache[file](templateState)
         end

         local data = read(file)

         cache[file] = assert(etlua.compile(data))

         return cache[file](templateState)
      end
   }

   f:write(template(templateState))

   f:close()
end
