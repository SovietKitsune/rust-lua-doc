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

local template = assert(etlua.compile(read 'assets/document.etlua'))
local srcTemplate = assert(etlua.compile(read 'assets/srcdoc.etlua'))

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
   functionStyle = 'lua',
   out = 'docs/'
}

local state = parser.getReport(modules)
local mods = parser.extractModules(state, modules)

local cache = {}

project.sources = state.files

local moduleCount = 0
local first

for i, v in pairs(mods) do
   moduleCount = moduleCount + 1
   if not first then first = i end
   project.modules[i] = parser.createType(v, state)
end

if moduleCount == 1 then
   project.modules = project.modules[first]

   if project.modules.kind == 'custom' then
      project.description = project.modules.struct.description
   elseif project.modules.kind == 'function' then
      project.description = project.modules.func.description
   else
      error 'Projects must be a table or function!'
   end
end

local main = io.open(project.out .. '/index.html', 'w')
local mainTemplate = assert(etlua.compile(read 'assets/main.etlua'))

main:write(mainTemplate({
   project = project,
   markdown = markdown,
   include = function(file)
      if cache[file] then
         return cache[file]()
      end

      local data = read(file)

      cache[file] = assert(etlua.compile(data))

      return cache[file]({
         project = project
      })
   end
}))

main:close()

for i, v in pairs(project.sources) do
   -- /tmp/aaa.tl -> -tmp-aaa-tl
   local f = io.open(project.out .. i:gsub('/', '-') .. '.html', 'w')

   f:write(srcTemplate({
      code = v,
      project = project,
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

local function generateDocument(i, v)
   local f = io.open(project.out .. i .. '.html', 'w')

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

if moduleCount > 1 then
   for i, v in pairs(project.modules) do
      generateDocument(i, v)
   end
else
   if project.modules.kind == 'custom' then
      for i, v in pairs(project.modules.struct.fields) do
         generateDocument(i, v)
      end
   end
end
