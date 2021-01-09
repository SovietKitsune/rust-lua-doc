use rslua::{ast::*, lexer::Lexer, lexer::LexerConfig, parser::Parser};
use std::io::{self, Read};

fn try_parse(input: &str) -> Block {
    let mut lexer = Lexer::new();
    lexer.set_debug(true);
    lexer.set_config(LexerConfig {
        reserve_comments: true,
        use_origin_string: true,
    });
    if let Ok(tokens) = lexer.run(input) {
        let mut parser = Parser::new();
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

    try_parse(&buffer);
}
