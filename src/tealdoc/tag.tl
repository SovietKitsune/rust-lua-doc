local parser = require('tealdoc.parser')
local logger = require('tealdoc.logger')

local type ruleReturn = function(parser.Type): boolean

local record TagConfig
   selector: string
   allowed: ruleReturn
   fn: function(parser.Type, ...: string)
   err: string
end

local function parse(typ:  parser.Type, tags: {TagConfig})
   if not typ.description then return end

   for i = 1, #tags do
      local tag = tags[i]

      -- If you want it to be at the start just do
      -- `\n@<stuff>\n?`
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

   -- Wipe tags away

   for i = 1, #tags do
      typ.description = typ.description:gsub(tags[i].selector, '')
   end
end

local function traverse(types: {string: parser.Type}, tags: {TagConfig})
   for _, tp in pairs(types) do
      if tp.kind == 'nominal' then
         tp = tp.ref
      end

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

function rules.kind(name: string): ruleReturn
   return function(typ: parser.Type): boolean
      return typ.kind as string == name
   end
end

function rules.any(...: ruleReturn): ruleReturn
   local anyRule = {...}

   return function(typ: parser.Type): boolean
      for i = 1, anyRule do
         if anyRule[i](typ) then
            return true
         end
      end

      return false
   end
end

function rules.anyKind(): boolean
   return true
end

function rules.parentMustBe(parent: string): ruleReturn
   return function(typ: parser.Type): boolean
      return typ.parent and (typ.parent as parser.Type).kind as string == parent
   end
end

return {
   rules = rules,
   traverse = traverse,
   TagConfig = TagConfig
}
