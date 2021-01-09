# Notes

Just some notes how the AST parses certain functions

## Functions

### Syntax sugar local

```lua
local function func() end
```

```rust
StatInfo {
   stat: FuncStat(
         FuncStat {
            func_type: Local,
            func_name: FuncName {
               fields: [
                     "func",
               ],
               method: None,
            },
            body: FuncBody {
               params: [],
               block: Block {
                     stats: [],
               },
            },
         },
   ),
   source: Source {
         pos: 0,
         length: 25,
         line: 1,
         col: 1,
   },
}
```

### Syntax sugar global

```lua
function func() end
```

```rust
StatInfo {
   stat: FuncStat(
         FuncStat {
            func_type: Global,
            func_name: FuncName {
               fields: [
                     "func",
               ],
               method: None,
            },
            body: FuncBody {
               params: [],
               block: Block {
                     stats: [],
               },
            },
         },
   ),
   source: Source {
         pos: 0,
         length: 19,
         line: 1,
         col: 1,
   },
}
```

## Functions in tables

### Syntax sugar

* LDoc: ✔️
* Py-Lua-Doc: ✔️

```lua
local x = {}

function x.func() end
```

```rust
StatInfo {
   stat: FuncStat(
         FuncStat {
            func_type: Global,
            func_name: FuncName {
               fields: [
                     "x",
                     "func",
               ],
               method: None,
            },
            body: FuncBody {
               params: [],
               block: Block {
                     stats: [],
               },
            },
         },
   ),
   source: Source {
         pos: 0,
         length: 35,
         line: 1,
         col: 1,
   },
}
```

### Without syntax sugar

* LDoc: ✔️
* Py-Lua-Doc: ✖️

```lua
local x = {}

x.func = function() end
```

```rust
StatInfo {
   stat: AssignStat(
         AssignStat {
            left: [
               SuffixedExpr(
                     SuffixedExpr {
                        primary: Name(
                           "x",
                        ),
                        suffixes: [
                           Attr(
                                 "func",
                           ),
                        ],
                     },
               ),
            ],
            right: [
               FuncBody(
                     FuncBody {
                        params: [],
                        block: Block {
                           stats: [],
                        },
                     },
               ),
            ],
         },
   ),
   source: Source {
         pos: 0,
         length: 37,
         line: 1,
         col: 1,
   },
}
```

### Table inline

* LDoc: ✔️
* Py-Lua-Doc: ✖️

```lua
local x = {
   func = function() end
}
```

```rust
StatInfo {
   stat: LocalStat(
         LocalStat {
            names: [
               "x",
            ],
            exprs: [
               Table(
                     Table {
                        fields: [
                           RecFileld(
                                 RecField {
                                    key: Name(
                                       "func",
                                    ),
                                    value: FuncBody(
                                       FuncBody {
                                             params: [],
                                             block: Block {
                                                stats: [],
                                             },
                                       },
                                    ),
                                 },
                           ),
                        ],
                     },
               ),
            ],
         },
   ),
   source: Source {
         pos: 0,
         length: 38,
         line: 1,
         col: 1,
   },
}
```