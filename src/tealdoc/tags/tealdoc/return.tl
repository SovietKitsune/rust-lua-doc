local rules = require('tealdoc.tag').rules
local parser = require('tealdoc.parser')

--- @{hidden}
return {
   selector = '@{return (%a[%w_]*)}',
   allowed = rules.kind('function'),
   fn = function(typ: parser.Type, retType: string)
      table.insert((typ.func as parser.Function).returns, {
         kind = 'named',
         customName = retType
      })
   end,
   err = 'Returns can only exist on functions!'
}
