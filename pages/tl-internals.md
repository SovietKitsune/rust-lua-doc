# Teal API (somewhat) explained

Some of these are just guesses for what structures in Teal actually are.

**This is a work in progress.**

## Exposed apis

### tl.LoadMode

Type: `enum`

Only used within [tl.load](#tl.load). Equivalent to the `mode` option of [load](https://www.lua.org/manual/5.4/manual.html#pdf-load).

- `b` - The input data is binary
- `t` - The input data is text
- `bt` - The input data is both text and binary

### tl.LoadFunction

Type: `type`

Only used within [tl.load](#tl.load) and is the return value of [load](https://www.lua.org/manual/5.4/manual.html#pdf-load).

### tl.CompatMode

Type: `enum`

Defines whether the compiler should either:

- `off` - Don't generate any code to attempt to load `compat53`
- `optional` - Only generate code to load `compat53` if Lua 5.3 features are used
- `required` - Require that code to load `compat53` is generated

### tl.TargetMode

Type: `enum`

The Lua version that should be target. Teal will attempt to polyfill any missing apis that are not supported by the target version.

Teal is designed to be a language that can target all modern Lua versions (5.1 to 5.4 including LuaJIT) so compatibility is needed.

- `5.1` - Intended for both Lua 5.1 and Lua 5.2, polyfills missing syntax and apis.

  ```tl
  -- Input
  print(1 << 2)
  -- Output
  print(bit32.lshift(1, 2))
  ```

- `5.3` - Indented for 5.3 and above. This should touch any syntax.

  ```tl
  -- Input
  print(1 << 2)
  -- Output
  print(1 << 2)
  ```

### tl.TypeCheckOptions

Type: `record`

Defines what options to use when type checking a Teal/Lua script.

Since Teal is a Superset of Lua, being able to write plain Lua is important.

- `lax` - `boolean`

  Tell the type checker to be more lax on types.

  - Allow normal Lua files to pass through `required_module`
    - Mark `utf8` as the only library that needs `compat53`
    - Allow `unknown` types (they won't throw errors)
      - `invalid` types will instead of `unknown`

- `filename` - `string`

  The filename that will be attached to all types

- `gen_compat` - [tl.CompatMode](#tl.CompatMode)
- `gen_target` - [tl.TargetMode](#tl.TargetMode)
- `env` - [tl.Env](#tl.Env)
- `run_internal_compiler_checks` - `boolean`

  Tell the teal compiler to not run internal/runtime type checking by setting `visit_node` and `visit_type` to nil.

  ```tl
  -- visit_type.after
  after = function(typ: Type, _children: {Type}, ret: Type): Type
      if type(ret) ~= "table" then
          error(typ.typename .. " did not produce a type")
      end
      if type(ret.typename) ~= "string" then
          error("type node does not have a typename")
      end
      return ret
  end
  -- visit_node.after
  visit_node.after = function(node: Node, _children: {Type}): Type
      if type(node.type) ~= "table" then
          error(node.kind .. " did not produce a type")
      end
      if type(node.type.typename) ~= "string" then
          error(node.kind .. " type does not have a typename")
      end
      return node.type
  end
  ```

### tl.Env

Type: `record`

The environment that the type checker write and reads from. The record may also contain information on if the parser should keep going on fails or generation details.

- `globals` - `{ string:` [Variable](#private.Variables) `}`

  The globals that are defined (`global x = ...`) and the standard library.

- `modules` - `{` [Types](#private.Type) `}`

  A module is defined as a required file (`require '...'`).

- `loaded` - `{` [Result](#tl.Result) `}`

  Unlike `modules`, `loaded` stored the current file as well. `loaded` also stores Results instead of Types (although Results do contain a type field).

- `loaded_order` - Array of the filenames of loaded modules (stored as strings)

  Every time a file is loaded, a new string is pushed onto this array allowing the order of loads to be guaranteed.

- `gen_compat` - [tl.CompatMode](#tl.CompatMode)
- `gen_target` - [tl.GenTarget](#tl.GenTarget)
- `keep_going` - `boolean`

  Prevents syntax errors from causing the compiler to return in panic. This is usually only used within `tl types` (technically text editors since anywhere else invalid syntax is bad).

### tl.Symbol

Type: `record`

A symbol can be thought of a variable (not to be confused with the [Variable](#private.Variable) type). Symbols can also represent an opening or closing of a scope (with the name of `@{` or `@}`).

- `x` - `integer`

  The position of the symbol in terms of the `x` axis (or column)

- `y` - `integer`

  The position of the symbol in terms of the `y` axis (or line)

- `name` - `string`

  The name of the symbol. There are some special names such as `@{` and `@}` for specifying which symbols are within a certain scope.

- `typ` - [Type](#private.Type)

  The specific type of the symbol.

- `other` - `integer`

  Unused? (The creation of symbols doesn't specify any sort of `other` field and no other field is ever created)

- `skip` - `boolean`

  Signifies that the symbol should be skipped (Only used internally to resolve scopes)

### tl.Result

Type: `record`

Results are what is returned from functions which process teal code ([tl.process](#tl.process), [tl.process_string](#tl.process_string), and [tl.type_check](#tl.type_check)).

- `filename` - `string`

  The filename of the file that was processed (usually an argument of processor functions)

- `ast` - [Node](#private.Node)

  The AST of the processed file.

- `type` - [Type](#private.Type)

  The type of the data that was returned from the processed code (if anything was returned).

- `syntax_errors` - `{` [Error](#tl.Error) `}`

  All the syntax errors that were encountered when processing the file. Example:

  > syntax error, expected '='

- `type_errors` - `{` [Error](#tl.Error) `}`

  All the type errors that were encountered when processing the file. Example:

  > in assignment: got string 'hi', expected integer

- `warnings` - `{` [Error](#tl.Error) `}`

  Warnings are items that are technically valid but should be changed or hints on how to fix an error. Examples:

  - > hint: if you want to iterate over fields of a record, cast it to {string:any}
  - > unused variable i: string

- `symbol_list` - `{` [Symbol](#tl.Symbol) `}`

  All the symbols within the file.

- `env` - [Env](#tl.Env)

  The environment used when processing the file.

- `dependencies` - `{ string: string }`

  All the dependencies of the file, sorted as module name to the file found.

### tl.WarningKind

Type: `enum`

The different kinds of warnings that could arise during parsing/processing.

- `unknown` - An unknown variable is found (isn't a warning when lax mode is enabled).
- `unused` - An unused variable is found.
- `redeclaration` - A variable is redeclared (ie `local x = 5; local x = 2`)
- `branch` - A branch that will either always be true or always be false is encountered.
- `hint` - A hint is something that can help the user fix another warning.
- `debug` - A debug warning is only used to figure out what type a certain variable is. (This is thrown when the special function of `print_type` is called.)

### tl.warning_kinds

Type: `{ string: boolean }`

A map from warning kinds to boolean values in order to do a quick check if a certain warning exists (Used only within the CLI).

### tl.Error

Type: `record`

An error gives positions and a message to what went wrong within a file.

- `x` - `integer`

  The position of the error in terms of the `x` axis (or column)

- `y` - `integer`

  The position of the error in terms of the `y` axis (or line)

- `msg` - `string`

  The message associated with the error

- `filename` - `string`

  The file that generated the error message

- `tag` - [tl.WarningKind](#tl.WarningKind)

  The kind of warning that was thrown

- `i` - `integer`

  > used temporarily for stable-sorting

### tl.typecodes

Type: `{ string: number }`

A dictionary linking names of types to their associated number values.

> Implementation rationale:
>
> - bit 31: (MSB) special ("any", "unknown", "invalid")
> - "any" satisfies all Lua masks
> - bits 30-27: if valid: other Teal types ("nominal", "poly", "union", "typevar")
> - bits 24-26: reserved
> - bits 16-19: if valid: Teal types ("array", "record", "arrayrecord", "map", "tuple", "enum") that map to a Lua type ("table", "string")
> - bit 15: if not valid: value is unknown
> - bits 8-14: reserved
> - bits 0-7: (LSB) Lua types, one bit for each ("nil", "number", "boolean", "string", table, "function", "userdata", "thread")
> - every valid value has a Lua type bit set

- `NIL` - `0x00000001`
- `NUMBER` - `0x00000002`
- `BOOLEAN` - `0x00000004`
- `STRING` - `0x00000008`
- `TABLE` - `0x00000010`
- `FUNCTION` - `0x00000020`
- `USERDATA` - `0x00000040`
- `IS_TABLE` - `0x00000008`
- `IS_NUMBER` - `0x00000002` or `NUMBER`
- `IS_STRING` - `0x00000004`
- `LUA_MASK` - `0x00000fff`
- `INTEGER` - `0x00010002`
- `ARRAY` - `0x00010008`
- `RECORD` - `0x00020008`
- `ARRAYRECORD` - `0x00030008`
- `MAP` - `0x00040008`
- `TUPLE` - `0x00080008`
- `EMPTY_TABLE` - `0x00000008` or `IS_TABLE`
- `ENUM` - `0x00010004`
- `IS_ARRAY` - `0x00010008` or `ARRAY`
- `IS_POLY` - `0x20000020`
- `ANY` - `0xffffffff`
- `UNKNOWN` - `0x80008000`
- `INVALID` - `0x80000000`
- `IS_SPECIAL` - `0x80000000` or `INVALID`
- `IS_VALID` - `0x00000fff` or `LUA_MASK`

### tl.TypeInfo

Type: `record`

TypeInfo is the more bare-bones version of [Type](#private.Type). It contains the more needed information of [Type](#private.Type) and none of the debug information (like where the type was inferred). Unlike [Type](#private.Type), however, it relies on the parent construct ([TypeReport](#tl.TypeReport)) as all of the types are relative to `TypeReport.types`.

- `t` - `integer`

  The specific typecode of the type. See [tl.typecodes](#tl.typecodes).

- `str` - `string`

  The more humanized representation of the type (extracted from `show_type_base`).

- `file` - `string`

  The file where this type came from (usually provided by `require` and the processor functions).

- `x` - `integer`

  The position of the error in terms of the `x` axis (or column)

- `y` - `integer`

  The position of the error in terms of the `y` axis (or line)

- `ref` - `integer` (index to `TypeReport.types`)

  The type which this type refers to. This only exists on nominals.

- `fields` - `{ string: integer }` (index to `TypeReport.types`)

  A dictionary linking from the name of the field to an index to `TypeReport.types`. This only exists on records or arrayrecords.

# TODO; rest
