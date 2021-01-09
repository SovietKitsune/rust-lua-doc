//! Data models for raw documentation (aka stage 1)
use std::boxed::Box;

// Traits

/// A Lua type
pub trait LuaType {}

// Enums

/// The visibility of Lua types
pub enum LuaVisibility {
    PUBLIC = 1,
    PROTECTED = 2,
    PRIVATE = 3,
}

// Structures

/// A type representing nil
pub struct LuaTypeNil;
impl LuaType for LuaTypeNil {}
/// A type representing a boolean
pub struct LuaTypeBoolean;
impl LuaType for LuaTypeBoolean {}
/// A type representing a number
pub struct LuaTypeNumber;
impl LuaType for LuaTypeNumber {}
/// A type representing a string
pub struct LuaTypeString;
impl LuaType for LuaTypeString {}
/// A type representing a generic, unknown function
pub struct LuaTypeFunction;
impl LuaType for LuaTypeFunction {}
/// A type representing userdata
pub struct LuaTypeUserdata;
impl LuaType for LuaTypeUserdata {}
/// A type representing a thread
pub struct LuaTypeThread;
impl LuaType for LuaTypeThread {}
/// A type representing a generic table
pub struct LuaTypeTable;
impl LuaType for LuaTypeTable {}
/// A type representing anything
pub struct LuaTypeAny;
impl LuaType for LuaTypeAny {}
/// An array of types
pub struct LuaArray {
    /// The internal type
    pub int_type: Box<dyn LuaType>,
}
impl LuaType for LuaArray {}
/// A custom type like classes
pub struct LuaCustom {
    pub name: String,
}
impl LuaType for LuaCustom {}
/// A dictionary with keys and values
pub struct LuaDict {
    pub key: Box<dyn LuaType>,
    pub value: Box<dyn LuaType>,
}
impl LuaType for LuaDict {}
/// An inline function eg one defined within a field
pub struct LuaCallable {
    pub args: (String, Box<dyn LuaType>),
    pub returns: Vec<Box<dyn LuaType>>,
}
impl LuaType for LuaCallable {}
/// A logical or, `number | string`
pub struct LuaOr {
    pub types: Vec<Box<dyn LuaType>>,
}
impl LuaType for LuaOr {}
/// A parameter to a function
pub struct LuaParam {
    pub name: String,
    pub desc: String,
    pub int_type: Box<dyn LuaType>,
    pub is_opt: bool,
    pub default: Option<Box<dyn LuaType>>,
}
impl LuaType for LuaParam {}
/// A return to a function
pub struct LuaReturn {
    pub desc: String,
    pub int_type: Box<dyn LuaType>,
}
impl LuaType for LuaReturn {}
/// A full Lua function
pub struct LuaFunction {
    pub name: String,
    pub desc: String,
    pub params: Vec<LuaParam>,
    pub returns: Vec<LuaReturn>,
    pub is_abstract: bool,
    pub is_static: bool,
    pub is_deprecated: (bool, Option<String>),
    pub visibility: LuaVisibility,
}
impl LuaType for LuaFunction {}
/// A field part of a class or module
pub struct LuaField {
    pub name: String,
    pub desc: String,
    pub int_type: Box<dyn LuaType>,
    pub visibility: LuaVisibility,
}
/// A class containing methods
pub struct LuaClass {
    pub name: String,
    pub methods: Vec<LuaFunction>,
    pub desc: String,
    pub inherits: Vec<String>,
    pub fields: Vec<LuaField>,
    pub is_deprecated: (bool, Option<String>),
}
/// A module containing methods and data
pub struct LuaModule {
    pub file_path: String,
    pub classes: Vec<LuaClass>,
    pub functions: Vec<LuaFunction>,
    pub data: Vec<LuaField>,
    pub name: String,
    pub desc: String,
}
