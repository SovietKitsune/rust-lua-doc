local tl = require 'tl'

-- Functions
--{{{
local record Function
   description: string
   params: {Param}
   returns: {Type}
   vararg: boolean
end

local record Param
   name: string
   type: Type
end
--}}}

-- Records
--{{{
local record Record
   name: string
   description: string
   fields: {string: Field}
end

local record Field
   type: Type
   description: string
end
--}}}

-- Types
local record Type
   enum TypeNames
      'nil'
      'boolean'
      'number'
      'string'
      'function' -- Recursion is cool
      'userdata'
      'thread'
      'table'
      'any'
      'unknown'
      'custom' -- Records
      'union' -- T | V
      'tuple' -- {T, V}
      'poly' -- ?
      'nominal' -- Reference
      'enum'
      'generic' -- T
   end
   kind: TypeNames
   -- Exists on function types
   func: Function | nil
   -- Exists on table types
   key: Type | nil
   value: Type | nil
   -- Exists on custom types or generics
   name: string | nil
   -- Exists on custom types
   struct: Record | nil
   -- Exists on unions, tuples, and polys
   types: {Type} | nil
   -- Exists on enums
   values: {string} | nil
end

local record State
   report: tl.TypeReport
   files: {string: string}
end

-- Token isn't exposed
local record Token
   x: number
   y: number
   i: number
   tk: string
   kind: string
end

local function generateGlobals(modules: {string}): string
   local mod = {}

   for i = 1, #modules do
      local str = modules[i]
      -- globals are easier to find
      table.insert(mod, 'global ' .. str .. ' = require \'' .. str .. '\'')
   end

   return table.concat(mod, '\n')
end

-- Replaces teals search for one which indexes the virtual modules
local function new_search(modules: {string: string}, virtual: boolean, state: State): function(module: string): string, FILE, {string}
   return function(module: string): string, FILE, {string}
      if modules[module] then
         local mod = modules[module]

         local f: FILE
         local filename: string

         -- Virtual
         if virtual then 
            local name = os.tmpname() .. '.tl'
            do
               local tmp = io.open(name, 'w')
               tmp:write(mod)
               tmp:close()
               state.files[name] = mod
            end
            f = io.open(name, 'r')
            filename = name
         else
            do
               local tmp = io.open(mod, 'r')
               state.files[mod] = tmp:read('*a')
               tmp:close()
            end
            f = io.open(mod, 'r')
            filename = mod
         end

         return filename, f
      else 
         return nil, nil, {'We tried everything...'}
      end
   end
end

local function getReport(modules: {string: string}, virtual: boolean): State
   local keys: {string} = {}

   for i in pairs(modules) do
      table.insert(keys, i)
   end

   local str = generateGlobals(keys)

   local oldSearch = tl.search_module

   local state: State = {
      files = {}
   }

   tl.search_module = new_search(modules, virtual, state)

   local result = tl.process_string(str)

   if #result.syntax_errors > 1 then
      error(result.syntax_errors[1].msg)
   end

   local types = tl.get_types(result)

   tl.search_module = oldSearch

   state.report = types

   return state
end

local function extractModules(state: State, mods: {string: string}): {string: number}
   local collected: {string: number} = {}

   for i, v in pairs(state.report.globals) do
      if mods[i] then
         collected[i] = v
      end
   end

   return collected
end

local function getDescription(contents: string, y: number): string
   local split = {}

   do
      local pos = 1

      while true do
         local nextNewline = contents:find('\n', pos, true)

         if not nextNewline then
            break
         end

         table.insert(split, contents:sub(pos, nextNewline - 1))

         pos = nextNewline + 1
      end
   end

   local descLines: {string} = {}

   local i = y - 1

   while true do
      local line = split[i]

      if i < 0 then
         break
      else
         i = i - 1

         if line and line:match('%s*%-%-%-%.*') then
            table.insert(descLines, line:match('%s*%-%-%- ?(.*)'))
         else
            break
         end
      end
   end

   local reversed = {}

   for i = #descLines, 1, -1 do
      table.insert(reversed, descLines[i])
   end

   return table.concat(reversed, '\n')
end

local function getTokensAtLine(tokens: {Token}, y: number, x: number): {Token}
   --; TODO, use a binary search
   local started = false
   local tokensAtSig = {}

   for i = 1, #tokens do
      local token = tokens[i]

      if token.y == y and token.x >= x then
         started = true
         table.insert(tokensAtSig, token)
      elseif token.y ~= y and started then
         break
      end
   end

   return tokensAtSig
end

local function createType(index: number, report: State, noNominal: boolean): Type
   local tp = report.report.types[index]
   local codes = tl.typecodes

   local conversions = {
      [codes.NIL] = 'nil',
      [codes.BOOLEAN] = 'boolean',
      [codes.NUMBER] = 'number',
      [codes.STRING] = 'string',
      [codes.USERDATA] = 'userdata',
      [codes.THREAD] = 'thread',
      [codes.TABLE] = 'table',
      [codes.ANY] = 'any',
      [codes.UNKNOWN] = 'unknown'
   }

   if conversions[tp.t] then
      -- Basic type
      return {
         kind = conversions[tp.t]
      }
   elseif tp.t == codes.FUNCTION then
      local params = {}
      local rets = {}

      local tokens = tl.lex(report.files[tp.file])

      local paramNames = {}

      local started = false
      local tokensAtSig = getTokensAtLine(tokens as {Token}, tp.y, tp.x)

      for i = 1, #tokensAtSig do
         if tokensAtSig[i].tk == '(' then
            started = true
         elseif started and tokensAtSig[i].tk == ')' then
            break
         elseif started and tokensAtSig[i].kind == 'identifier' and tokensAtSig[i - 1].kind ~= ':' then
            table.insert(paramNames, tokensAtSig[i].tk)
         end
      end

      for i = 1, #tp.args do
         table.insert(params, {
            type = createType(tp.args[i][1], report, noNominal),
            name = paramNames[i]
         })
      end

      for i = 1, #tp.rets do
         table.insert(rets, createType(tp.rets[i][1], report, noNominal))
      end

      return {
         kind = 'function',
         func = {
            description = getDescription(report.files[tp.file], tp.y),
            params = params,
            returns = rets,
            vararg = tp.vararg
         }
      }
   elseif tp.t == codes.ARRAY then
      return {
         kind = 'table',
         key = {
            kind = 'number'
         },
         value = createType(tp.elements, report, noNominal)
      }
   elseif tp.t == codes.RECORD or tp.t == codes.ARRAYRECORD then
      local tokens = tl.lex(report.files[tp.file])

      local tokensAtSig = getTokensAtLine(tokens as {Token}, tp.y, tp.x)

      local name: string

      for i = 1, #tokensAtSig do
         if tokensAtSig[i].kind == 'identifier' and tokensAtSig[i - 1] and tokensAtSig[i - 1].tk == 'record' then
            name = tokensAtSig[i].tk
            break
         end
      end

      local fields = {}

      for i, v in pairs(tp.fields) do
         fields[i] = {
            --; TODO - get description of field
            description = '',
            type = createType(v, report, noNominal)
         }
      end

      return {
         kind = 'custom',
         struct = {
            name = name,
            description = getDescription(report.files[tp.file], tp.y),
            fields = fields
         }
      }
   elseif tp.t == codes.MAP then
      return {
         kind = 'table',
         key = createType(tp.keys, report, noNominal),
         value = createType(tp.values, report, noNominal)
      }
   elseif tp.t == codes.TUPLE or tp.t == codes.IS_UNION or tp.t == codes.IS_POLY then
      local types = {}

      for i = 1, #tp.types do
         table.insert(types, createType(tp.types[i], report, noNominal))
      end
      
      return {
         kind =
            tp.t == codes.TUPLE and 'tuple' or
            tp.t == codes.IS_UNION and 'union' or
            tp.t == codes.IS_POLY and 'poly',
         types = types
      }
   elseif tp.t == codes.NOMINAL and not noNominal then
      -- Reference to another record
      local ref = createType(tp.ref, report, true)

      local struct = ref and ref.struct as Record

      return {
         type = 'nominal',
         ref = struct and struct.name or 'recursion',
      }
   elseif tp.t == codes.ENUM then
      return {
         type = 'enum',
         types = tp.enums
      }
   elseif tp.t == codes.TYPE_VARIABLE then
      return {
         type = 'generic',
         name = tp.str
      }
   end
end

return {
   getReport = getReport,
   extractModules = extractModules
}
