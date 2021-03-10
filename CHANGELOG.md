# Changelog

## dev-4

* Fix issues causing left-hosting to fail
  * Now tables use AST parsing instead of token parsing
  * Records keep on using token parsing as the AST doesn't expose positions
  * Don't let the Teal developers know about `parser.tl`
* Added more accurate titles for output
* Added `head.etlua` template

## dev-3

* Add tag support
  * Deprecated tag puts a warning near the deprecated type
  * Hidden tag doesn't generate the document/module file and any links to it
  * Metamethod tag marks a function to be a metamethod instead of a normal method
  * Param overrides a functions parameter
  * Return adds a new function return

## dev-2

* Add fix for metamethods

## dev-1

* Allow for submodules
* Descriptions for fields (records, tables, enums)
* Cleanup `parser.Type`
* Switch to using a Lua file instead of a TOML file for configs
* Fix some markdown issues
