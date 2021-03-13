local logger = require('tealdoc.logger')
local tl = require('tl')

--- A structure that represents a bare function
local record Function
   params: {Type}
   returns: {Type}
   vararg: boolean
   isMetamethod: boolean
end

--- A structure that represents a bare record or table
local record Struct
   fields: {string: Type}
   isRecord: boolean
end

--- A structure that represents every type
local record Type
   --- A list of all valid type names
   enum Kinds
      'nil'
      'boolean'
      'number'
      'string'
      'userdata'
      'thread'
      'table'
      --- Explicit type as any
      'any'
      --- A type which couldn't be figured out
      'unknown'
      --- Either an inline function or an actual function
      'function'
      --- A custom type like a record or module
      'custom'
      --- A union type that combines multiple types
      'union'
      --- A table which must contain a certain number of types in the correct order
      'tuple'
      'poly'
      --- A list of strings of what the string could be
      'enum'
      --- A generic found within function definitions
      'generic'
      --- A type provided from outside the teal compiler
      'named'
   end

   --- The kind of type this is
   kind: Kinds
   --- The description of the type, every type can have a description since of records
   description: string
   --- The name of the type, usually inherited from their parent
   name: string
   --- The custom name of a type
   customName: string | nil
   --- The parent of the type, this doesn't exist for top-level types
   parent: Type | nil
   --- The file-system tree that needs to be followed
   tree: string
   --- If the type is hidden or not
   hidden: boolean
   --- The Y position of a type
   yPos: number | nil
   --- The stopping point of a type
   stopY: number | nil
   --- The source of where the type was found
   source: string | nil
   --- Exists on function types
   func: Function | nil
   --- Either a record or a module
   struct: Struct
   --- The key of the table
   key: Type | nil
   --- The value of the table
   value: Type | nil
   --- The types that form this type, eg `type1 | type2` or `{type1, type2}`
   types: {Type} | nil
   --- The values of an enum, its separate from types due to enums being "complex" aka blocked
   values: {Type} | nil
   --- Signify that a type has been deprecated
   deprecated: boolean | string
   --- @{hidden}
   tp: tl.TypeInfo
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

-- Same with Node
local record Node
   {Node}

   y: number
   x: number
   tk: string
   kind: string
end

local function generateGlobals(modules: {string}): string
   local mod = {'global toLoad = {'}

   for i = 1, #modules do
      local str = modules[i]
      -- globals are easier to find
      table.insert(mod, '["' .. str .. '"] = require \'' .. str .. '\',')
   end

   table.insert(mod, '}')

   return table.concat(mod, '\n')
end

-- Replaces teals search for one which indexes the virtual modules
local function newSearch(modules: {string: string}, virtual: boolean, state: State): function(module: string): string, FILE, {string}
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

--- Get a report on all the files
---
--- The report contains all indexed files as well as the types
---
--- If the modules being passed don't exist on disk, pass `true` to the virtual flag
---
--- If the files are Lua, pass `true` to the isLua flag
local function getReport(modules: {string: string}, virtual: boolean, isLua: boolean): State
   local keys: {string} = {}

   for i in pairs(modules) do
      table.insert(keys, i)
   end

   local str = generateGlobals(keys)

   local oldSearch = tl.search_module

   local state = {
      files = {}
   } as State

   tl.search_module = newSearch(modules, virtual, state)

   local result = tl.process_string(str, isLua)

   if #result.syntax_errors > 1 then
      for i= 1, #result.syntax_errors do
         logger.error(result.syntax_errors[i].msg)
      end

      os.exit(-1)
   end

   local types = tl.get_types(result)

   tl.search_module = oldSearch

   state.report = types

   return state
end

--- Extract all the indexes of generated modules
local function extractModules(state: State, mods: {string: string}): {string: number}
   local collected: {string: number} = {}

   local pos = state.report.globals.toLoad

   for i, v in pairs(state.report.types[pos].fields) do
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

local function getTokensAtLine(tokens: {Token}, y: number, x: number): {Token}, {Token}
   --; TODO, use a binary search
   local started = false
   local tokensAtSig = {}
   local before = {}

   for i = 1, #tokens do
      local token = tokens[i]

      if token.y == y and token.x >= x then
         started = true
         table.insert(tokensAtSig, token)
      elseif token.y ~= y and started then
         break
      elseif not started then
         table.insert(before, token)
      end
   end

   return tokensAtSig, before
end

local function getTokensBetween(tokens: {Token}, y1: number, y2: number, x1: number, x2: number): {Token}
   --; TODO, use a binary search
   local started = false
   local tokensBetween = {}

   for i = 1, #tokens do
      local token = tokens[i]

      if token.y >= y1 and token.x >= x1 then
         started = true
      end

      if token.y > y2 or (token.y == y2 and token.x >= x2) then
         break
      end

      if started then
         table.insert(tokensBetween, token)
      end
   end

   return tokensBetween
end

local function getStop(tokens: {Token}, y: number, x: number, allowFunction: boolean): Token, number
   local canStart = false
   local started = false

   -- These are what you can use **within a record** which can open a scope
   local opensScope: {string: boolean} = {
      ['enum'] = true,
      ['record'] = true,
      -- This expects a record and records can only have inline functions
      ['function'] = allowFunction
   }

   local deepness = 0
   local lastToken: Token

   for i = 1, #tokens do
      local token = tokens[i]

      if token.y == y and token.x >= x then
         canStart = true
      end

      if canStart and opensScope[token.tk] then
         started = true
      end

      if started and (token.kind == 'keyword' and token.tk == 'end') then
         deepness = deepness - 1
      elseif started and opensScope[token.tk] then
         deepness = deepness + 1
      end

      if started and deepness == 0 then
         lastToken = token

         return lastToken, i
      end
   end
end

local function parseKind(toParse: Node, lines: {string: number})
   if toParse.kind == 'expression_list' then
      for i = 1, #toParse do
         parseKind(toParse[i], lines)
      end
   elseif toParse.kind == 'table_literal' then
      for i = 1, #toParse do
         lines[toParse[i].tk] = toParse[i].y
      end
   else
      -- `local_type` would be a record which we can already parse
      -- Records are easier to parse since it isn't the entire Lua syntax
      error('Unexpected kind: ' .. toParse.kind)
   end
end

local function recursiveFind(node: Node, x: number, y: number, visited: {Node: boolean}, depth: number): node, string
   visited = visited or {}
   depth = depth or 0

   if depth > 10000 then
      return nil, 'max-depth'
   end

   if visited[node] then
      return nil, 'visited'
   end

   visited[node] = true

   local viewed = {}

   for _, v in pairs(node as {string: Node}) do
      if type(v) == 'table' and v.x and v.y then
         table.insert(viewed, v)

         if v.x == x and v.y == y then
            return v
         else
            local succ = recursiveFind(v, x, y, visited, depth + 1)

            if succ then
               return succ
            end
         end
      end
   end

   return nil, 'viewed-all'
end

--- Create a (parsable) type from an index and a report
local function createType(index: number, report: State, noNominal: boolean): Type
   local tp = report.report.types[index]

   local codes = tl.typecodes

   local conversions: {number: Type.kind} = {
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

   local out: Type

   if not tp then
      -- if we don't have a tp, get out of here
      return {
         kind = 'unknown'
      }
   end

   if conversions[tp.t] then
      -- Basic type
      out = {
         kind = conversions[tp.t]
      }
   elseif tp.t == codes.FUNCTION then
      local tokens = tl.lex(report.files[tp.file])

      local paramNames = {}

      local started = false
      local tokensAtSig = getTokensAtLine(tokens as {Token}, tp.y, tp.x)

      for i = 1, #tokensAtSig do
         local token = tokensAtSig[i]
         if token.tk == '(' then
            started = true
         elseif started and token.tk == ')' then
            break
         elseif started and (token.kind == 'identifier' or token.kind == '...') and (tokensAtSig[i - 1].kind == ',' or tokensAtSig[i - 1].kind == '(') then
            table.insert(paramNames, tokensAtSig[i].tk)
         end
      end

      local params = {}

      for i = 1, #tp.args do
         local argType = createType(tp.args[i][1], report, noNominal)

         argType.name = paramNames[i]
         table.insert(params, argType)
      end

      local rets = {}

      for i = 1, #tp.rets do
         table.insert(rets, createType(tp.rets[i][1], report, noNominal))
      end

      --; TODO - get functions stop

      out = {
         kind = 'function',
         description = getDescription(report.files[tp.file], tp.y),
         source = tp.file,
         yPos = tp.y,
         func = {
            params = params,
            returns = rets,
            vararg = tp.vararg
         }
      }
   elseif tp.t == codes.ARRAY then
      out = {
         kind = 'table',
         key = {
            kind = 'number'
         },
         value = createType(tp.elements, report, noNominal)
      }
   elseif tp.t == codes.RECORD and tp.file == nil then
      -- Files are the only "class" in Lua
      out = {
         kind = 'named',
         customName = 'file'
      }
   elseif (tp.t == codes.RECORD or tp.t == codes.ARRAYRECORD) and tp.file then
      local tokens = tl.lex(report.files[tp.file])

      local tokensAtSig, before = getTokensAtLine(tokens as {Token}, tp.y, tp.x)

      local name: string
      local lastSig = tokens[#tokensAtSig + #before + 1] as Token

      local isRecord = false

      for i = 1, #tokensAtSig do
         if tokensAtSig[i].tk == 'record' then
            isRecord = true
         end

         if tokensAtSig[i].kind == 'identifier' and tokensAtSig[i - 1] and tokensAtSig[i - 1].tk == 'record' then
            name = tokensAtSig[i].tk
            break
         end
      end

      if not name then
         -- It's a sub-record
         if before[#before].kind == 'identifier' and before[#before - 1] and before[#before - 1].tk == 'record' then
            name = before[#before].tk
            -- Correct the X position to include `record`
            tp.x = before[#before - 1].x
            -- Same with the Y
            tp.y = before[#before - 1].y

            lastSig = tokensAtSig[1]
         end
      end

      out = {
         kind = 'custom',
         name = name,
         description = getDescription(report.files[tp.file], tp.y),
         source = tp.file,
         yPos = tp.y,
         struct = {
            fields = {},
            isRecord = isRecord
         }
      }

      for i, v in pairs(tp.fields) do
         local typ = createType(v, report, noNominal)

         typ.name = i
         typ.parent = out

         out.struct.fields[i] = typ
      end

      -- This part is (more) likely to fail
      xpcall(function()
         if name then
            local lastToken = getStop(tokens as {Token}, tp.y, tp.x)

            out.stopY = lastToken.y

            local tokensBetween = getTokensBetween(tokens as {Token}, lastSig.y, lastToken.y, lastSig.x, lastToken.x)

            local i = 1

            while i <= #tokensBetween do
               if tokensBetween[i].kind == 'identifier' and (tokensBetween[i].tk == 'record' or tokensBetween[i].tk == 'enum') and
                  tokensBetween[i + 1] and tokensBetween[i + 1].kind == 'identifier'
               then
                  local _, pos = getStop(tokensBetween, tokensBetween[i].y, tokensBetween[i].x)

                  -- They already get documented since they are records

                  i = pos + 1
               else
                  local fieldToken = tokensBetween[i]

                  if fieldToken.tk == 'metamethod' then
                     i = i + 1

                     out.struct.fields[tokensBetween[i].tk] = {
                        kind = 'function',
                        source = tp.file,
                        name = tokensBetween[i].tk,
                        yPos = fieldToken.y,
                        func = { --; TODO - Extract these
                                 --; Teal doesn't expose metamethods within requires
                           params = {},
                           returns = {},
                           vararg = {},
                           isMetamethod = true
                        } as Function
                     }
                  else

                     local found = false

                     local outField = out.struct.fields[fieldToken.tk]

                     outField.description = getDescription(report.files[tp.file], fieldToken.y)

                     local stack = 0
                     local ignoreNext = outField.kind == 'function'
                     -- logger.debug(atLine)

                     for k = i + 2, #tokensBetween do
                        -- We need to watchout for composition types eg functions, tables

                        local token = tokensBetween[k]

                        if token.kind == '{' or token.kind == '(' then
                           stack = stack + 1
                        elseif token.kind == '}' or token.kind == ')' then
                           stack = stack - 1
                        end

                        if token.kind == ':' and token.tk == ':' and stack == 0 and not ignoreNext then
                           i = k - 1

                           found = true

                           break
                        elseif ignoreNext and token.kind == ':' and token.tk == ':' then
                           ignoreNext = false
                        end
                     end

                     if not found then
                        break
                     end
                  end
               end
            end
         else
            local _, node = tl.parse_program(tokens)

            local collectedNode, reason = recursiveFind(node as Node, tp.x, tp.y)

            if not collectedNode then
               error('Unable to find node: ' .. tostring(reason))
            end

            local lines = {}

            parseKind(collectedNode, lines)

            for i, v in pairs(lines) do
               out.struct.fields[i].description = getDescription(report.files[tp.file], v)
            end
         end
      end, function(err)
         logger.error(string.format(
            'Parsing error with field comments!\n' ..
            '  Error: %s\n' ..
            '  Report this to https://github.com/SovietKitsune/tealdoc/issues\n\n%s',
            err,
            debug.traceback()
         ))

         os.exit(-1)
      end)
   elseif tp.t == codes.MAP then
      out = {
         kind = 'table',
         key = createType(tp.keys, report, noNominal),
         value = createType(tp.values, report, noNominal)
      }
   elseif tp.t == codes.TUPLE or tp.t == codes.IS_UNION or tp.t == codes.IS_POLY then
      local types = {}

      for i = 1, #tp.types do
         local parsed = createType(tp.types[i], report, noNominal)

         table.insert(types, parsed)
      end

      out = {
         kind =
            tp.t == codes.TUPLE and 'tuple' or
            tp.t == codes.IS_UNION and 'union' or
            tp.t == codes.IS_POLY and 'poly',
         types = types
      }
   elseif tp.t == codes.NOMINAL and not noNominal then
      -- Reference to another record
      -- As long as its not recursion we *should* be fine

      -- We don't set the parent on this one since it would be mostly pointless
      local ref = createType(tp.ref, report, true)

      -- This caused too many issues
      out = ref
   elseif tp.t == codes.ENUM then
      local tokens = tl.lex(report.files[tp.file])

      local tokensAtSig, before = getTokensAtLine(tokens as {Token}, tp.y, tp.x)

      local name: string
      local lastSig = tokens[#tokensAtSig + #before + 1] as Token

      for i = 1, #tokensAtSig do
         if tokensAtSig[i].kind == 'identifier' and tokensAtSig[i - 1] and tokensAtSig[i - 1].tk == 'enum' then
            name = tokensAtSig[i].tk
            break
         end
      end

      if not name then
         -- It's a sub-record
         if before[#before].kind == 'identifier' and before[#before - 1] and before[#before - 1].tk == 'enum' then
            name = before[#before].tk
            -- Correct the X position to include `record`
            tp.x = before[#before - 1].x
            -- Same with the Y
            tp.y = before[#before - 1].y

            lastSig = tokensAtSig[1]
         end
      end

      local lastToken = getStop(tokens as {Token}, tp.y, tp.x)

      local between = getTokensBetween(tokens as {Token}, lastSig.y, lastToken.y, lastSig.x, lastToken.x)

      local values = {}

      for i = 1, #between do
         local token = between[i]

         table.insert(values, {
            kind = 'string',
            name = token.tk,
            yPos = token.y,
            stopY = token.y,
            description = getDescription(report.files[tp.file], token.y)
         })
      end

      out = {
         kind = 'enum',
         values = values,
         name = name,
         description = getDescription(report.files[tp.file], tp.y),
         source = tp.file,
         yPos = tp.y
      }
   elseif tp.t == codes.TYPE_VARIABLE then
      out = {
         kind = 'generic',
         name = tp.str
      }
   else
      out = {
         kind = 'unknown'
      }
   end

   out.description = out.description or ''
   out.tp = tp

   return out
end

--- Utilities for extracting all the types from either virtual files or real files
return {
   newSearch = newSearch,
   getReport = getReport,
   createType = createType,
   extractModules = extractModules,
   Type = Type,
   Function = Function,
   Struct = Struct,
   State = State
}
