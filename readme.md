# New Idea

This new idea will be based on some points brought up by [daelvn](https://github.com/daelvn) with the [documentation discussion](https://github.com/daelvn/meteor/discussions/7)

The new parser will be written in Lua using Teal's `get_type` function along with some manual parsing for comments.

In order for everything to be all within a single tool, as brought up within the discussion, this would be a single tool.

Ideally the format will be like within [rustdoc](https://doc.rust-lang.org/rustdoc/index.html).

```lua
--- So this function adds 2 numbers together
local function add(x: number, y: number): number
   return x + y
end

return add
```

In plain Lua, type annotations could be added within the comments

```lua
---@param x number
---@param y number
---@return number
```

The functions and properties used within the final document would be the ones returned from the module instead of whatever is
