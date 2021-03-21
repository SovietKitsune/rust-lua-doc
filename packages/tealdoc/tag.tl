local parser = require('tealdoc.parser')
local logger = require('tealdoc.logger')

local type ruleReturn = function(parser.Type): boolean

local record TagConfig
   --- The Lua pattern to match by
   selector: string
   --- The types that are allowed, this comes from `tealdoc.tag.rules`
   allowed: ruleReturn
   --- The callback function
   fn: function(parser.Type, ...: string)
   --- An error message if `allowed` fails
   err: string
end

local function parse(typ:  parser.Type, tags: {TagConfig})
   if not typ.description then return end

   for i = 1, #tags do
      local tag = tags[i]

      if typ.description:match(tag.selector) then
         local isAllowed = tag.allowed(typ)

         if not isAllowed then
            logger.warn(
               (tag.err or 'Failed to pass rules for ' .. tag.selector) ..
               '\nPassed in kind: ' .. typ.kind ..
               '\nFile: ' .. typ.tp.file
            )
         else
            tag.fn(typ, typ.description:match(tag.selector))
         end
      end
   end

   for i = 1, #tags do
      typ.description = typ.description:gsub(tags[i].selector, '')
   end
end

local function traverse(types: {string: parser.Type}, tags: {TagConfig})
   for _, tp in pairs(types) do
      parse(tp, tags)

      -- Has children we care about
      if tp.kind == 'custom' then
         traverse(tp.struct.fields, tags)
      elseif tp.kind == 'enum' then
         traverse(tp.values as {string: parser.Type}, tags)
      end
   end
end

local rules = {}

--- Require the type be a certain kind
function rules.kind(name: string): ruleReturn
   return function(typ: parser.Type): boolean
      return typ.kind as string == name
   end
end

--- If any of the passed rules pass, return true
function rules.any(...: ruleReturn): ruleReturn
   local anyRule = {...}

   return function(typ: parser.Type): boolean
      for i = 1, #anyRule do
         if anyRule[i](typ) then
            return true
         end
      end

      return false
   end
end

--- Wildcard
function rules.anyKind(): boolean
   return true
end

--- Assert that the parent of a type must be a certain kind
function rules.parentMustBe(parent: string): ruleReturn
   return function(typ: parser.Type): boolean
      return typ.parent and (typ.parent as parser.Type).kind as string == parent
   end
end

--- The tag api to allow certain pieces of text to modify a type
return {
   --- All the supported rules
   rules = rules,
   --- Traverse the module tree in search of descriptions
   traverse = traverse,
   --- The configuration all tags have
   TagConfig = TagConfig
}
