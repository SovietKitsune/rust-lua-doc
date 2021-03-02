# New Idea

This new idea will be based on some points brought up by [daelvn](https://github.com/daelvn) with the [documentation discussion](https://github.com/daelvn/meteor/discussions/7).

The new parser will be written in Teal using Teal's `get_type` function along with some manual parsing for comments.

```lua
--- So this function adds 2 numbers together
local function add(x: number, y: number): number
   return x + y
end

return add
```

This would parse as

```lua
{
   func = {
      params = {
         { type = { kind = 'number' }, name = 'x' },
         { type = { kind = 'number' }, name = 'y' }
      },
      returns = {
         { kind = 'number' }
      },
      vararg = false,
      description = 'So this function adds 2 numbers together'
   },
   kind = 'function'
}
```

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
