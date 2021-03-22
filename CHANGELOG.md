# Changelog

## 0.0.1

* Implement token and AST cache
* Semver!
* Some memory optimizations
  * `tl.tl` (Running on 5.4)
    * `compiling`   - `86708kb`
    * `documenting` - `95252kb`
  * `tealdoc` (Running on 5.4)
    * `compiling`   - `77576kb` (`cyan build` - clean build)
    * `documenting` - `23036kb`
* Fix Lua 5.1 cli issues

## dev-11

* Fix some responsive issues
* Change some theming
* Realize that maybe I should use semver

## dev-10

* New pages that display markdown (maybe stolen from LDoc)
* Revised sidebar (less dizzy)
  * New search bar
  * New theme chooser
* Cleanup tealdoc cli
  * Separate the core logic and the command-line logic
  * New init command to generate a base `tealdoc.lua` file
* Small commits are stupid
* Temporally disable "typed" highlights (until Teal's lexer preserves comments [#233](https://github.com/teal-language/tl/issues/233#issuecomment-709385425))
* More efficient assets
  * Assets are now stored in `output/assets` instead of copied between each file

## dev-9

* Fixed issues with single-module/file projects/rocks
* Generate math example and generate tl compiler docs
* Added `forceRootModule` option for single-module/file projects/rocks

## dev-8

* Changed layout
  * Instead of a navbar, there is a sidebar/sidenav
* New nordic theme

## dev-7

* Introduce dark mode!
* Update readme
* Add new keywords to `pl.lexer`
* Remove the use of prism
* Fix for Teal's new integer type
* Cleanup `highlight.tl`
  * Moved themes to `theme.tl`
  * Moved tippy configuration to `tippy.tl`

## dev-6

* Added improved source inspection
  * Gives some type information as well as goto
  * (Mostly) server-side highlighting (soon to be completely server-side)
* Cleanup `tag.tl`
* Removed `srcdoc.tl`
* ~~increased document times~~

## dev-5

* Fix links (uses save path instead of parents)
* Remove `nominal` kind as it caused too many issues
* Some code cleanup

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
