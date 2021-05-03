# Tealdoc

An documentation generator for Teal.

## Tealdocs status on [#233](https://github.com/teal-language/tl/issues/233)

* [x] - Syntax for doc comments
  * Tealdoc syntax and (soon) LDoc syntax
* [x] - Syntax to start codeblocks
  * Uses markdown fenced codeblocks
* [x] - Generate documentation for all public types
  * [ ] - Throw warnings on leaking private types
* [ ] - Doc-tests/Example tests
  * They would be similar to rustdoc tests
* [ ] - Link to used libraries
  * [ ] - Internal linking
    * The only current form of internal linking is within source inspection
  * [ ] - External linking
    * Reading from the rockspec wouldn't be needed
      * Falling-back the search function to the default search would suffice for searching
    * The approach would be like rustdoc and storing modules like `docs/<mod-name>` instead of just `docs/`

## Minimum Teal version

* Compiling: `0.13.0`
* Running: `0.12.0`

## Demo

* tealdoc (self-hosted) - <https://sovietkitsune.github.io/tealdoc/tealdoc>

## Motivation

I like Teal and don't like LDoc/py-lua-doc.

## LDoc support

Tealdoc will Soon™️ support LDoc (and by extension LuaDoc) syntax (for the most part).

Somethings like MoonScript and C extension support won't work due to the parser using Teal.

### Not planned

* `@module`/`@classmod`/`@submodule` - Module names are automatically collected and can't be changed (unless explicitly within rockspec (TODO))
* `@script` - No point (to me)
* `@author`/`@copyright`/`@license`/`@release` - Can be specified in `tealdoc.lua` (TODO)
* `@function`/`@lfunction` - Functions are automatically found
* `@section` - No point (to me)

Not planned items would throw a warning with a suggested fix

### Other planned changes

* `@local` aliased to `@hidden`
* `@type` aliased to `@table`
