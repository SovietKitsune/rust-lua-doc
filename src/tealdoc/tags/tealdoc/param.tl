local rules = require('tealdoc.tag').rules
local parser = require('tealdoc.parser')

--- @{hidden}
return {
   selector = '@{param (%a[%w_]*) (%a[%w_]*)}',
   allowed = rules.kind('function'),
   fn = function(typ: parser.Type, name: string, paramType: string)
      local params = (typ.func as parser.Function).params

      for i = 1, #params do
         if params[i].name == name then
            params[i].kind = 'named'
            params[i].customName = paramType

            break
         end
      end
   end,
   err = 'Parameters can only exist on functions!'
}
