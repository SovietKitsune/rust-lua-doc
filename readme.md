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
         { type = { kind = 'number' } },
         { type = { kind = 'number' } }
      },
      returns = {
         { kind = 'number' }
      },
      description = 'So this function adds 2 numbers together'
   },
   kind = 'function'
}
```

Currently parameter names are not extracted due to `tl.get_types` not exposing them.

This would change in the future by using `tl.get_tokens_at` or `TypeInfo.symbols`.

With the change, comments for record fields should also come.

The functions and properties used within the final document would be the ones returned from the module instead of whatever is.
