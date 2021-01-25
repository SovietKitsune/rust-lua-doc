#[macro_use]
extern crate pest_derive;

use pest::Parser;
use rslua::{ast::*, lexer::Lexer, lexer::LexerConfig, parser::Parser as PParser};
use std::io::{self, Read};

#[derive(Parser)]
#[grammar = "../emmylua.pest"]
pub struct EmmyLuaParser;

fn try_parse(input: &str) -> Block {
    let mut lexer = Lexer::new();
    lexer.set_debug(true);
    lexer.set_config(LexerConfig {
        reserve_comments: true,
        use_origin_string: true,
    });
    if let Ok(tokens) = lexer.run(input) {
        let mut parser = PParser::new();
        parser.set_debug(true);
        if let Ok(ast) = parser.run(tokens) {
            println!("{:#?}", ast);
            return ast;
        }
    }
    unreachable!()
}

fn main() {
    let mut input = Vec::new();
    io::stdin()
        .read_to_end(&mut input)
        .expect("couldn't read from stdin");

    let buffer = String::from_utf8(input).expect("failed to convert buffer");

    let data = EmmyLuaParser::parse(Rule::file, &buffer)
        .expect("failed to parse")
        .next()
        .unwrap();

    println!("{:#?}", data)

    // try_parse(&buffer);
}
