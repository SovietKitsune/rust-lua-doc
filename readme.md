# Teal doc

A demo can be found at <https://sovietkitsune.github.io/tealdoc/>

This new idea will be based on some points brought up by [daelvn](https://github.com/daelvn) with the [documentation discussion](https://github.com/daelvn/meteor/discussions/7).

The new parser will be written in Teal using Teal's `get_type` function along with some manual parsing for comments.

The functions and properties used within the final document would be the ones returned from the module instead of whatever is.

## Customizing

Customizing the output of the generator is quite simple, some require no extra dependencies!

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

To customize how types look, edit the `humanize` function or the `genFn` function in `tealdoc/humanize.tl`

## TODO

* [ ] Cross-package linking
* [ ] Current-package linking
* [ ] Tag support
* [ ] Better source inspection
* [x] Field descriptions
* [x] Enum descriptions
* [x] Complete basic documentation generation
* [ ] Fix some record generation issues
* [ ] Cleanup (aka rewrite the code to be terrible)
* [ ] Full documentation generation (Generate sub-records and sub-enums)
* [ ] Side-navbar (config setting)
