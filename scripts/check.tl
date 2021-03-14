-- Whitespace and (basic) casing

local tl = require('tl')

local file: string
local exit = 0

local function splitLines(str: string): {string}
   local split = {}

   do
      local pos = 1

      while true do
         local nextNewline = str:find('\n', pos, true)

         if not nextNewline then
            break
         end

         table.insert(split, str:sub(pos, nextNewline - 1))

         pos = nextNewline + 1
      end
   end

   return split
end

local function buildReport(code: string, str: string, line: integer, col: integer, stopCol: integer): string
   exit = -1

   local split = splitLines(code)

   local currentLine = split[line]

   local posInformation = ' ' .. file .. ':' .. line .. ':' .. col

   local pos = str .. posInformation .. '\n '
      .. line .. ' | ' .. currentLine .. '\n '
      .. string.rep(' ', #tostring(line)) .. ' | '

   local bottom = string.rep(' ', col - 1) .. string.rep('^', stopCol - col)

   return pos .. bottom
end

local function out(str: string)
   io.stderr:write(str .. '\n')
end

local stages = {}

function stages.whitespace(code: string)
   local lines = splitLines(code)

   for i = 1, #lines do
      local line = lines[i]

      if line:match('^%s+$') then
         local start, stop = line:match('^()%s+()$') as (integer, integer)
         out(buildReport(code, 'Line contains only whitespace', i, start, stop))
      elseif line:match('.*%s$') then
         local start, stop = line:match('.-()%s+()$') as (integer, integer)

         out(buildReport(code, 'Line contains trailing whitespace', i, start, stop))
      end
   end
end

function stages.case(code: string)
   -- Makes sure that all non-blocks are in camel case
   local function isCamel(str: string): boolean
      return not str:match('_') and str:sub(1, 1):lower() == str:sub(1, 1) or str == '_'
   end

   local function isPascal(str: string): boolean
      -- Only difference is :upper instead of :lower
      return not str:match('_') and str:sub(1, 1):upper() == str:sub(1, 1) or str == '_'
   end

   local tokens = tl.lex(code)
   local lines = splitLines(code)

   for i = 1, #tokens do
      local current = tokens[i]
      local before = tokens[i - 1]
      local future = tokens[i + 1]
      if current.kind == 'identifier' and before then
         if before.tk == 'record' or before.tk == 'enum' then
            if not isPascal(current.tk) then
               out(buildReport(
                  code,
                  'Records/enums/types names must be PascalCase',
                  current.y,
                  current.x, future and future.x or current.x
               ))
            end
         elseif 
            before.tk == 'local' or -- Variable declarations
            before.tk == 'function' or -- Function declarations
            future and future.tk == '=' and current.tk ~= tokens[i + 2].tk and tokens[i - 2] and tokens[i - 2].tk ~= 'tl' or -- Assignments
            future and future.tk == ':' and before.kind == 'identifier' -- Record fields
         then
            local canIgnore = false

            if lines[current.y]:match('%-%-;ignore$') then
               canIgnore = true
            end

            if not isCamel(current.tk) and not canIgnore then
               out(buildReport(
                  code,
                  'Variables must be camelCase',
                  current.y,
                  current.x,
                  future and future.x or current.x
               ))
            end
         end
      end
   end
end

for i = 1, #arg do
   file = arg[i]

   local f = io.open(file)
   local data = f:read('*a')
   f:close()

   for _, v in pairs(stages as {string: function}) do
      v(data)
   end
end

os.exit(exit)
