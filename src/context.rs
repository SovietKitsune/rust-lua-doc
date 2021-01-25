use std::boxed::Box;
use std::option::NoneError;

use crate::models::*;
use rslua::ast::*;

enum Name {
    Plain(String),
    Index(Vec<String>),
}

/// TODO; should this be separate structures instead?
enum Context {
    /// Represents a bare variable, no sort of comments have been looked at so types and visibility are a guess.
    Variable {
        /// The type is only inferred if the type is assigned directly.
        ///
        /// ```lua
        /// local myVar = 5 -- Will have type of number
        /// local myNewVar = myVar -- Will have type of any
        /// ```
        int_type: Box<dyn LuaType>,
        /// The name of the variable, if part of a table then it will be a `Vector`, else `String`
        name: Name,
        /// The visibility of the variable inferred by the name being prefixed with an underscore, eg `_myPrivateVar`
        visibility: LuaVisibility,
    },
    /// Represents a bare function, no sort of comments have been looked at so what the function returns is unknown and visibility a guess.
    Function {
        /// The name of the parameters the function has not taking into account overloads
        params: Vec<String>,
        /// The name of the variable, if part of a table then it will be a `Vector`, else `String`
        name: Name,
        /// The visibility of the variable inferred by the name being prefixed with an underscore, eg `_myPrivateVar`
        visibility: LuaVisibility,
        /// If this function is vararg
        vararg: bool,
        /// If this function is static
        is_static: bool,
    },
}

enum HasContext {
    Assignment(AssignStat),
    Function(FuncStat),
    Inline(LocalStat),
}

enum Error {
    UnexpectedNone(NoneError),
    UnexpectedExpression,
}

impl From<NoneError> for Error {
    fn from(e: NoneError) -> Self {
        Error::UnexpectedNone(e)
    }
}

fn from_func_body(name: Name, body: &FuncBody, m_is_static: Option<bool>) -> Context {
    let mut params: Vec<String> = vec![];
    let mut is_vararg = false;
    let mut is_static = m_is_static.unwrap_or(true);

    for param in body.params.iter() {
        match param {
            Param::VarArg => is_vararg = true,
            Param::Name(name) => {
                params.push(name.to_string());

                if name == "self" {
                    is_static = false;
                }
            }
        }
    }

    let visibility = match name {
        Name::Plain(ref name_str) => {
            if name_str.starts_with('_') {
                LuaVisibility::PRIVATE
            } else {
                LuaVisibility::PUBLIC
            }
        }
        Name::Index(ref names) => {
            if names.last().unwrap_or(&String::from("")).starts_with('_') {
                LuaVisibility::PRIVATE
            } else {
                LuaVisibility::PUBLIC
            }
        }
    };

    Context::Function {
        params,
        name,
        visibility,
        is_static,
        vararg: is_vararg,
    }
}

fn parse_context(ctx: HasContext) -> Result<Context, Error> {
    match ctx {
        HasContext::Assignment(stat) => {
            let name = match stat.left.first()? {
                Assignable::Name(name_str) => Name::Plain(name_str.to_string()),
                Assignable::ParenExpr(expr) => {
                    match &**expr {
                        Expr::Name(name) => Name::Plain(name.to_string()),
                        _ => todo!(), // TODO; figure out what could also appear here
                    }
                }
                Assignable::SuffixedExpr(expr) => {
                    let mut names: Vec<String> = vec![];

                    match &*expr.primary {
                        Expr::Name(name) => names.push(name.to_string()),
                        _ => todo!(), // TODO; figure out what could also appear here
                    };

                    for suffix in expr.suffixes.iter() {
                        match suffix {
                            Suffix::Attr(name) => names.push(name.to_string()),
                            Suffix::Index(expr) => {
                                match expr {
                                    Expr::Name(name) => names.push(name.to_string()),
                                    _ => todo!(), // TODO; figure out what could also appear here
                                }
                            }
                            Suffix::Method(name) => names.push(name.to_string()),
                            _ => todo!(), // TODO; figure out what could also appear here
                        }
                    }

                    Name::Index(names)
                }
            };

            let body = stat.right.first()?;

            let int_type: Box<dyn LuaType>;

            match body {
                Expr::FuncBody(body) => return Ok(from_func_body(name, body, None)),
                Expr::Nil => int_type = Box::new(LuaTypeNil),
                Expr::True => int_type = Box::new(LuaTypeBoolean),
                Expr::False => int_type = Box::new(LuaTypeBoolean),
                Expr::Float(_) => int_type = Box::new(LuaTypeNumber), // TODO; use arguments
                Expr::Int(_) => int_type = Box::new(LuaTypeNumber),
                Expr::String(_) => int_type = Box::new(LuaTypeString),
                Expr::Table(_) => int_type = Box::new(LuaTypeTable),
                _ => return Err(Error::UnexpectedExpression),
            };

            let visibility = match name {
                Name::Plain(ref name_str) => {
                    if name_str.starts_with('_') {
                        LuaVisibility::PRIVATE
                    } else {
                        LuaVisibility::PUBLIC
                    }
                }
                Name::Index(ref names) => {
                    if names.last()?.starts_with('_') {
                        LuaVisibility::PRIVATE
                    } else {
                        LuaVisibility::PUBLIC
                    }
                }
            };

            Ok(Context::Variable {
                name,
                int_type,
                visibility,
            })
        }
        HasContext::Function(stat) => {
            let mut fields: Vec<String> = stat.func_name.fields;
            let mut is_static = true;

            if stat.func_name.method.is_some() {
                fields.push(stat.func_name.method.unwrap());
                is_static = false;
            }

            let name = match fields.len() {
                1 => Name::Plain(fields.get(1)?.clone()),
                _ => Name::Index(fields),
            };

            Ok(from_func_body(name, &stat.body, Some(is_static)))
        }
        _ => todo!(), // TODO; tables can hold multiple functions while this function currently only returns a singular context
    }
}
