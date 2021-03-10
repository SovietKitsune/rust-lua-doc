local rules = require('tealdoc.tag').rules
local parser = require('tealdoc.parser')

--- @{hidden}
return {
   selector = '@{hidden}',
   allowed = rules.anyKind,
   fn = function(typ: parser.Type)
      typ.hidden = true
   end
}
