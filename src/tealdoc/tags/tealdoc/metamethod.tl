local rules = require('tealdoc.tag').rules
local parser = require('tealdoc.parser')

--- @{hidden}
return {
   selector = '@{metamethod}',
   allowed = rules.kind('function'),
   fn = function(typ: parser.Type)
      (typ.func as parser.Function).isMetamethod = true
   end,
   err = 'Only functions are allowed to be a metamethod!'
}
