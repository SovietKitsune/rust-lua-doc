# Tealdoc

*Demo can be found at <https://sovietkitsune.github.io/tealdoc/>*

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

## Customizing

Customizing the output of the generator is quite simple:

### General structure

This would be the HTML that is used within the generator. Since its written with etlua, no extra dependencies are needed.

All of these are located in `tealdoc/templates`. Everything within `tealdoc/html/templates` is rebuilt every time.

* `document.etlua` - A document contains information about a single type
* `footer.etlua` - The footer used on most pages
* `main.etlua` - The index page which links to the top-level documents
* `navbar.etlua` - The navbar used on most pages
* `prism.etlua` - Prism.js configuration
* `srcdoc.etlua` - The file used to generate linking to sources

### Types

To customize how types look, edit the `humanize` function or the `genFn` function in `tealdoc/humanize.tl`.
