local rules = require('tealdoc.tag').rules
local parser = require('tealdoc.parser')

return {
   selector = '@{deprecated (.-)}',
   allowed = rules.any(
      rules.kind('function'),
      rules.parentMustBe('custom'),
      rules.parentMustBe('enum')
   ),
   fn = function(typ: parser.Type, reason: string)
      typ.deprecated = reason or true
   end,
   err = 'The `deprecated` tag must be used on either a function or a child of a record/table/enum!'
}
