# Teal doc

A demo can be found at <https://sovietkitsune.github.io/tealdoc/>

This new idea will be based on some points brought up by [daelvn](https://github.com/daelvn) with the [documentation discussion](https://github.com/daelvn/meteor/discussions/7).

The new parser will be written in Teal using Teal's `get_type` function along with some manual parsing for comments.

The functions and properties used within the final document would be the ones returned from the module instead of whatever is.

## TODO

* [ ] Cross-package linking
* [ ] Current-package linking
* [ ] (Better) Lua support
* [ ] Better source inspection
* [ ] Field descriptions
* [x] Complete basic documentation generation
* [ ] Fix some record generation issues
* [ ] Cleanup (aka rewrite the code to be terrible)
