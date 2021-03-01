--- A module to aid in allowing for typed code
---
--- Typed gives clean errors that look like errors from misused standard functions
---
--- ```
--- bad argument #1 to 'tostring' (string | function expected, got nil)
--- ```
---
--- ## Quick example
---
--- ```lua
--- local typed = require 'typed'
---
--- local function hi(msg)
---    typed.func(_, 'string')(msg)
---
---    print(msg)
--- end
---
--- hi('hello') -- No errors
--- hi(1) -- bad argument #1 to 'hi' (string expected, got number)
--- ```
local typed = {}

-- Utilities

local function split(str: string, separator: string): {string}
   local ret = {}

   if not str then
      return ret
   end

   if not separator or separator == '' then
      for c in string.gmatch(str, '.') do
         table.insert(ret, c)
      end

      return ret
   end

   local n = 1

   while true do
      local i, j = string.find(str, separator, n)

      if not i then
         break
      end

      table.insert(ret, string.sub(str, n, i - 1))

      n = j + 1
   end

   table.insert(ret, string.sub(str, n))

   return ret
end

local function trim(str: string): string
   return string.match(str, '^%s*(.-)%s*$')
end

local function tblTypesEq(left: string, right: string): boolean
   local key, val = left:match('table<(.-), (.-)>')
   local rKey, rVal = right:match('table<(.-), (.-)>')

   if key == 'any' and val == rVal then
      return true
   elseif val == 'any' and key == rKey then
      return true
   elseif key == 'any' and val == 'any' then
      return true
   elseif key:match('table') and rKey:match('table') then
      return tblTypesEq(key, rKey)
   elseif val:match('table') and rVal:match('table') then
      return tblTypesEq(val, rVal)
   else
      -- TODO; handle primitives
      return false
   end
end


--- Is this an array?
function typed.isArray(tbl: any): boolean
   if type(tbl) ~= 'table' then return false end

   for i in pairs((tbl as table)) do
      if type(i) ~= 'number' then
         return false
      end
   end

   return true
end

--- What is this specific item?
---
--- Note: This can be overridden with `__name` or `__type` field.
---
--- Arrays are represented with `type[]` and tables with `table<keyType, valueType>`.
function typed.whatIs(this: any): string
   if type(this) == 'table' and ((this as table).__name or (this as table).__type) then
      local given = ((this as table).__name or (this as table).__type) as string

      if given == 'Array' then
         return typed.whatIs((this as table)._data)
      else
         return given
      end
   else
      if type(this) == 'table' then
         if typed.isArray(this) then
            if #(this as {any}) > 0 then
               local currentType = typed.whatIs((this as {any})[1])

               for _, v in pairs((this as {number: any})) do
                  if typed.whatIs(v) ~= currentType and currentType ~= 'any' then
                     currentType = 'any'
                  end
               end

               return currentType .. '[]'
            else
               return 'unknown[]'
            end
         else
            local keyType: string
            local valueType: string

            for i, v in pairs((this as table)) do
               if not keyType then
                  keyType = typed.whatIs(i)
                  valueType = typed.whatIs(v)
               end

               if typed.whatIs(i) ~= keyType and keyType ~= 'any' then
                  keyType = 'any'
               end

               if typed.whatIs(v) ~= valueType and valueType ~= 'any' then
                  valueType = 'any'
               end
            end

            return 'table<' .. keyType .. ', ' .. valueType .. '>'
         end
      else
         return type(this)
      end
   end
end

--- Check if the `value` matches the `validator`.
function typed.is(validator: string, value: any): boolean
   -- Handle logical or statements by recalling the function until one of them is true or we go through them all
   if validator:match('|') then
      for _, v in ipairs(split(validator, '|')) do
         local part = trim(v)

         if typed.is(part, value) then
            return true
         end
      end

      return false
   end

   -- Any checks are troublesome as they can be anywhere
   if validator == 'any' then
      return true
   end

   -- We match the amount of `[]` as arrays can be nested
   if validator:sub(0, 3) == 'any' and type(value) == 'table' and typed.isArray(value) then
      local left, right = validator:match('.-([%[%]].*)'), typed.whatIs(value):match('.-([%[%]].*)')

      if left:match('table') and right:match('table') then
         return tblTypesEq(left, right)
      elseif left:match('table') or right:match('table') then
         return false -- If something has a table while something else doesn't, they can't be similar
      else
         return left == right:sub(0, #left) -- Since its any, any[][] should accept any[][][] as any is anything
      end
   end

   -- Table checks are handled differently due to them being able to be nested
   -- Recursion is used to handle the nesting
   if validator:match('table') and type(value) == 'table' and not typed.isArray(value) then
      return tblTypesEq(validator, typed.whatIs(value))
   end

   -- Logical not
   if validator:sub(0, 1) == '!' then
      return validator:sub(2, #validator) ~= typed.whatIs(value)
   end

   return validator == typed.whatIs(value)
end

--- Create a new function to validate types
---
--- This is commonly piped into assert and should be used in environments without `debug`.
function typed.resolve(validator: string, pos: number, name: string): function(x: any): boolean, nil | string
   local parts = split(validator, '|')

   for i, v in ipairs(parts) do
      parts[i] = trim(v)
   end

   local expects = 'bad argument #' ..
      (pos or 1) .. ' to \'' .. (name or '?') ..
      '\' (' .. table.concat(parts, ' | ') .. ' expected, got %s)'

   return function(x: any): boolean, nil | string
      local matches = typed.is(validator, x)

      if matches == false then
         return nil, string.format(expects, typed.whatIs(x))
      else
         return true
      end
   end
end

--- Create a new typed function.
---
--- **This function uses the debug library**
---
--- You can override the inferred name by passing a first argument.
---
--- The rest of the arguments are validation strings.
---
--- This returns a function which would take those arguments defined in the validation string.
function typed.func(name: string, ...: string): function(...: any)
   local info = debug.getinfo(2)

   typed.resolve('string | nil', 1, 'typed.func')(name or info.name)

   for i, v in ipairs {...} do
      assert(typed.resolve('string', i + 1, 'typed.func')(v))
   end

   local arr = {...}

   return function(...)
      local input = {...}
      for i = 1, #arr do
         local newInfo = debug.getinfo(2)

         local succ, err = typed.resolve(arr[i], i, name or newInfo.name)(input[i])

         if not succ then
            error(err)
         end
      end
   end
end

--- Create a typed dictionary allowing only specific key and value types
function typed.typedDict(keyType: string, valueType: string): table
   local tbl: table = {}

   tbl.__name = 'table<' .. keyType .. ', ' .. valueType .. '>'
   tbl.__keys = keyType
   tbl.__values = valueType

   local mt = {}

   function mt.__newindex(self: table, k: string, v: any)
      typed.func(nil, (self.__keys as string), (self.__values as string))(k, v)
      tbl[k] = v
   end

   setmetatable(tbl, mt)

   return tbl
end

return typed
