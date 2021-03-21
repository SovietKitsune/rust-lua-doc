-- Generates a document
local fs = require('tealdoc-cli.fs')

local logger = require('tealdoc.logger')
local etlua = require('etlua')

local generator = {
   _cache = {} as {string: function},
   _current = nil as string,
   _prefix = '',
   baseState = {} as {string: any}
}

function generator.load(file: string, noPrefix: boolean): string
   if not noPrefix then
      file = generator._prefix .. '/' .. file .. '.etlua'
   end

   if generator._cache[file] then
      return file
   end

   local data = fs.read(file)

   local fn, err = (etlua.compile as function(any): string, string)(data)

   if not fn then
      logger.error('Failed to parse ' .. file .. ': ' .. err as string)
      os.exit(-1)
   end

   generator._cache[file] = fn as function(any): any

   return file
end

function generator.gen(file: string, data: table): string
   file = generator.load(file)

   for i, v in pairs(generator.baseState) do
      data[i] = v
   end

   generator._current = file

   data.include = function(f: string, d: table): string
      d = d or {}

      for i, v in pairs(data) do
         d[i] = v
      end

      return generator.gen(f, d)
   end

   local succ, err = true, ''
   local res: string
   
   xpcall(function()
      res = generator._cache[file](data) as string
   end, function(er: string)
      err = er .. '\n' .. debug.traceback()
      succ = false
   end)

   if not succ then
      logger.error('Failed to load ' .. file .. ':\n' .. err as string)
      os.exit(-1)
   end

   return res
end

function generator.loadBase(project: table, templates: string)
   generator.baseState.highlight = require('tealdoc-cli.highlight')
   generator.baseState.markdown = require('tealdoc-cli.markdown')
   generator.baseState.humanize = require('tealdoc-cli.humanize')(project)
   generator.baseState.misc = require('tealdoc-cli.misc')

   generator.baseState.project = project

   generator._prefix = templates

   logger.debug('Compiling templates')

   local files = fs.searchAll(templates, '%.etlua$')

   for i = 1, #files do
      generator.load(files[i], true)
      logger.debug('Compiled ' .. files[i])
   end
end

return generator
