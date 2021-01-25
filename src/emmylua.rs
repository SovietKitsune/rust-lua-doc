//! # EmmyLua comment parser
//!
//! EmmyLua is a popular comment style for IDEs.
//! Each EmmyLua has its own differences. For example, `@version` doesn't exist in standard EmmyLua.
//! while it does in LuaAnalyze and Sumneko's Lua. In LuaAnalyze, `@version` specifies which version the context was added.
//! In Sumneko's Lua, it's the Lua version which the context requires.
//!
//! For the most part, Sumneko's Lua will be followed as it causes the least issues. LuaAnalyze adds new EmmyLua syntax like more generics.
//! In standard EmmyLua, there is the `@module` which doesn't exist in Sumneko's Lua.
//!
//! ## Syntax / Annotations
//!
//! ### Markdown
//!
//! Rust-lua-doc uses [Markdown-it](https://github.com/markdown-it/markdown-it) to render markdown.
//!
//! Along with Markdown-it, [Markdown-it-container](https://github.com/markdown-it/markdown-it-container) is also used.
//!
//! The following containers are supported:
//! * error - There is something important that the reader should know, ie the function uses `debug`.
//! * warning - There is something of less importance like a deprecated function
//! * info - Something like a tip or just something useful in general
//!
//! Example:
//!
//! ```lua
//! --- ::: error
//! --- # Warning
//! ---
//! --- This function uses debug!
//! --- :::
//! ```
//!
//! ### Annotations
//!
//! #### `@class`
//!
//! Format: `---@class TYPE[:PARENT]`
//!
//! #### `@param`
//!
//! Requires: function context
//!
//! Format: `---@param name TYPE [comment]`
//!
//! #### `@return`
//!
//! Requires: function context
//!
//! Format: `---@return TYPE [name [comment]]`
//!
//! #### `@field`
//!
//! Requires: class context
//!
//! Format: `---@field public|protected|private name TYPE [comment]`
//!
//! #### `@generic`
//!
//! Requires: function context
//!
//! Format: `---@generic T1 [:PARENT] [,...]`
//!
//! #### `@vararg`
//!
//! Requires: function context
//!
//! Format: `---@vararg TYPE`
//!
//! #### `@see`
//!
//! Format: `---@see Class#property`
//!
//! #### `@overload`
//!
//! Requires: `TYPE` must be [inline function](#function)
//!
//! Format: `---@overload TYPE`
//!
//! #### `@deprecated`
//!
//! Excludes: Standard EmmyLua
//!
//! Format: `---@deprecated [comment]`
//!
//! #### `@module`
//!
//! Format: `---@class module`
//!
//! Reason: Intellisense
//!
//!
//!
//! Format 2: `---@module`
//!
//! Reason: Readability
//!
//! #### `@struct`
//!
//! Format: `---@class struct`
//!
//! Reason: Intellisense
//!
//!
//!
//! Format 2: `---@shape`
//!
//! Reason: Intellisense
//!
//! ### Syntax
//!
//! #### Array
//!
//! Format: `TYPE[]`
//!
//! #### Table
//!
//! Format: `table<KEY_TYPE, VALUE_TYPE>`
//!
//! #### Function
//!
//! Format: `fun([param: TYPE...]):TYPE...`
//!
//! #### Type
//!
//! Format: `[a-zA-Z0-9._]` / `ASCII_ALPHANUMERIC | "." | "_"`

use crate::models::{
    LuaType,
    LuaVisibility
};

enum Name {
    Plain(String),
    Index(Vec<String>),
}

/// Raw EmmyLua tags
///
/// Enums should be mixed together like mixing `Class` with `Description`
///
/// TODO; should this be separate structures instead?
enum EmmyLuaTags {
    // Both classes and modules need to be tracked to collect properties and functions.
    // Structures are not tracked as they are described within the definition (hopefully)
    Class {
        name: Name,
        inherits: Vec<Name>,
        tracking: Name
    },
    Module {
        name: Name,
        tracking: Name
    },
    Param {
        name: Name,
        int_type: Box<dyn LuaType>,
        comment: String
    },
    Return {
        int_type: Box<dyn LuaType>,
        name: Name,
        comment: String
    },
    Field {
        visibility: LuaVisibility,
        name: Name,
        int_type: Box<dyn LuaType>,
        comment: String
    },
    Generic {
        types: Vec<(String, Option<String>)>
    },
    Vararg {
        int_type: Box<dyn LuaType>,
    },
    See {
        class: String,
        property: String
    },
    Overload {
        int_type: Box<dyn LuaType>, // Must be callable
    },
    Deprecated {
        comment: String
    },
    Struct {
        name: Name
    }
}