package main

import "core:testing"

Lexer :: struct {
	source: string,
	file:   string,
	start:  int,
	pos:    int,
	line:   int,
	column: int,
}

lexer :: struct {
	init:              proc(source: string, file := "<input>") -> Lexer,
	scan_all:          proc(l: ^Lexer) -> [dynamic]Token,
	scan_token:        proc(l: ^Lexer) -> Token,
	identifier:        proc(l: ^Lexer, line: int, column: int) -> Token,
	number:            proc(l: ^Lexer, line: int, column: int) -> Token,
	string:            proc(l: ^Lexer, line: int, column: int) -> Token,
	make_token:        proc(l: ^Lexer, kind: Token_Kind, line: int, column: int) -> Token,
	skip_line_comment: proc(l: ^Lexer),
	match:             proc(l: ^Lexer, expected: u8) -> bool,
	advance:           proc(l: ^Lexer) -> u8,
	peek:              proc(l: ^Lexer) -> u8,
	peek_next:         proc(l: ^Lexer) -> u8,
	at_end:            proc(l: ^Lexer) -> bool,
	is_alpha:          proc(ch: u8) -> bool,
	is_digit:          proc(ch: u8) -> bool,
} {
	init = proc(source: string, file := "<input>") -> Lexer {
		return Lexer{source = source, file = file, line = 1, column = 1}
	},
	scan_all = proc(l: ^Lexer) -> [dynamic]Token {
		tokens := make([dynamic]Token)

		for !lexer.at_end(l) {
			l.start = l.pos
			tok := lexer.scan_token(l)
			if tok.kind != .Illegal || len(tok.lexeme) > 0 {
				append(&tokens, tok)
			}
		}

		append(&tokens, Token{kind = .Eof, line = l.line, column = l.column})
		return tokens
	},
	scan_token = proc(l: ^Lexer) -> Token {
		start_line := l.line
		start_column := l.column
		ch := lexer.advance(l)

		switch ch {
		case ' ', '\t', '\r':
			return Token{kind = .Illegal}
		case '\n':
			return Token{kind = .Newline, lexeme = "\n", line = start_line, column = start_column}
		case ':':
			return lexer.make_token(l, .Colon, start_line, start_column)
		case ',':
			return lexer.make_token(l, .Comma, start_line, start_column)
		case '.':
			return lexer.make_token(l, .Dot, start_line, start_column)
		case '(':
			return lexer.make_token(l, .Left_Paren, start_line, start_column)
		case ')':
			return lexer.make_token(l, .Right_Paren, start_line, start_column)
		case '{':
			return lexer.make_token(l, .Left_Brace, start_line, start_column)
		case '}':
			return lexer.make_token(l, .Right_Brace, start_line, start_column)
		case '-':
			if lexer.match(l, '>') {
				return lexer.make_token(l, .Arrow, start_line, start_column)
			}
			return lexer.make_token(l, .Illegal, start_line, start_column)
		case '#':
			lexer.skip_line_comment(l)
			return Token{kind = .Illegal}
		case '/':
			if lexer.match(l, '/') {
				lexer.skip_line_comment(l)
				return Token{kind = .Illegal}
			}
			return lexer.make_token(l, .Illegal, start_line, start_column)
		case '"':
			return lexer.string(l, start_line, start_column)
		}

		if lexer.is_alpha(ch) || ch == '_' {
			return lexer.identifier(l, start_line, start_column)
		}

		if lexer.is_digit(ch) {
			return lexer.number(l, start_line, start_column)
		}

		return lexer.make_token(l, .Illegal, start_line, start_column)
	},
	identifier = proc(l: ^Lexer, line: int, column: int) -> Token {
		for !lexer.at_end(l) {
			ch := lexer.peek(l)
			if !(lexer.is_alpha(ch) || lexer.is_digit(ch) || ch == '_' || ch == '-') {
				break
			}
			lexer.advance(l)
		}

		lexeme := l.source[l.start:l.pos]
		kind, ok := token.keyword_kind(lexeme)
		if !ok {
			kind = .Identifier
		}

		return Token{kind = kind, lexeme = lexeme, line = line, column = column}
	},
	number = proc(l: ^Lexer, line: int, column: int) -> Token {
		for lexer.is_digit(lexer.peek(l)) {
			lexer.advance(l)
		}

		if lexer.peek(l) == '.' && lexer.is_digit(lexer.peek_next(l)) {
			lexer.advance(l)
			for lexer.is_digit(lexer.peek(l)) {
				lexer.advance(l)
			}
		}

		return Token {
			kind = .Number,
			lexeme = l.source[l.start:l.pos],
			line = line,
			column = column,
		}
	},
	string = proc(l: ^Lexer, line: int, column: int) -> Token {
		value_start := l.pos

		for !lexer.at_end(l) && lexer.peek(l) != '"' {
			lexer.advance(l)
		}

		if lexer.at_end(l) {
			return Token {
				kind = .Illegal,
				lexeme = l.source[value_start:l.pos],
				line = line,
				column = column,
			}
		}

		value_end := l.pos
		lexer.advance(l)
		return Token {
			kind = .String,
			lexeme = l.source[value_start:value_end],
			line = line,
			column = column,
		}
	},
	make_token = proc(l: ^Lexer, kind: Token_Kind, line: int, column: int) -> Token {
		return Token{kind = kind, lexeme = l.source[l.start:l.pos], line = line, column = column}
	},
	skip_line_comment = proc(l: ^Lexer) {
		for !lexer.at_end(l) && lexer.peek(l) != '\n' {
			lexer.advance(l)
		}
	},
	match = proc(l: ^Lexer, expected: u8) -> bool {
		if lexer.at_end(l) || l.source[l.pos] != expected {
			return false
		}

		lexer.advance(l)
		return true
	},
	advance = proc(l: ^Lexer) -> u8 {
		ch := l.source[l.pos]
		l.pos += 1

		if ch == '\n' {
			l.line += 1
			l.column = 1
		} else {
			l.column += 1
		}

		return ch
	},
	peek = proc(l: ^Lexer) -> u8 {
		if lexer.at_end(l) {
			return 0
		}
		return l.source[l.pos]
	},
	peek_next = proc(l: ^Lexer) -> u8 {
		if l.pos + 1 >= len(l.source) {
			return 0
		}
		return l.source[l.pos + 1]
	},
	at_end = proc(l: ^Lexer) -> bool {
		return l.pos >= len(l.source)
	},
	is_alpha = proc(ch: u8) -> bool {
		return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
	},
	is_digit = proc(ch: u8) -> bool {
		return ch >= '0' && ch <= '9'
	},
}

//****************************************/
// Tests
//****************************************/

@(test)
lexer_init_test :: proc(t: ^testing.T) {
	lx := lexer.init("story", "story.saga")
	testing.expect(t, lx.source == "story")
	testing.expect(t, lx.file == "story.saga")
	testing.expect(t, lx.start == 0)
	testing.expect(t, lx.pos == 0)
	testing.expect(t, lx.line == 1)
	testing.expect(t, lx.column == 1)
}

@(test)
lexer_scan_all_test :: proc(t: ^testing.T) {
	lx := lexer.init(
		"story \"Saga\"\nscene intro:\n# ignored\nsay Odin: \"Hi\"\nchoice:\n\"Go\" -> next\n",
	)
	tokens := lexer.scan_all(&lx)
	defer delete(tokens)

	expected := [?]Token_Kind {
		.Keyword_Story,
		.String,
		.Newline,
		.Keyword_Scene,
		.Identifier,
		.Colon,
		.Newline,
		.Newline,
		.Keyword_Say,
		.Identifier,
		.Colon,
		.String,
		.Newline,
		.Keyword_Choice,
		.Colon,
		.Newline,
		.String,
		.Arrow,
		.Identifier,
		.Newline,
		.Eof,
	}

	testing.expect(t, len(tokens) == len(expected))
	for kind, index in expected {
		testing.expect(t, tokens[index].kind == kind)
	}
}

@(test)
lexer_scan_token_test :: proc(t: ^testing.T) {
	sources := [?]string {
		"\n",
		":",
		",",
		".",
		"(",
		")",
		"{",
		"}",
		"->",
		"-",
		"/",
		"@",
		"story",
		"scene-name",
		"123.45",
		"\"hello\"",
	}
	kinds := [?]Token_Kind {
		.Newline,
		.Colon,
		.Comma,
		.Dot,
		.Left_Paren,
		.Right_Paren,
		.Left_Brace,
		.Right_Brace,
		.Arrow,
		.Illegal,
		.Illegal,
		.Illegal,
		.Keyword_Story,
		.Identifier,
		.Number,
		.String,
	}

	for source, index in sources {
		lx := lexer.init(source)
		tok := lexer.scan_token(&lx)
		testing.expect(t, tok.kind == kinds[index])
	}
}

@(test)
lexer_identifier_test :: proc(t: ^testing.T) {
	lx := lexer.init("scene-name_1 ")
	lexer.advance(&lx)
	tok := lexer.identifier(&lx, 1, 1)
	testing.expect(t, tok.kind == .Identifier)
	testing.expect(t, tok.lexeme == "scene-name_1")
	testing.expect(t, tok.line == 1)
	testing.expect(t, tok.column == 1)

	lx = lexer.init("goto ")
	lexer.advance(&lx)
	tok = lexer.identifier(&lx, 1, 1)
	testing.expect(t, tok.kind == .Keyword_Goto)
	testing.expect(t, tok.lexeme == "goto")
}

@(test)
lexer_number_test :: proc(t: ^testing.T) {
	lx := lexer.init("123.45 ")
	lexer.advance(&lx)
	tok := lexer.number(&lx, 1, 1)
	testing.expect(t, tok.kind == .Number)
	testing.expect(t, tok.lexeme == "123.45")

	lx = lexer.init("123.story")
	lexer.advance(&lx)
	tok = lexer.number(&lx, 1, 1)
	testing.expect(t, tok.lexeme == "123")
	testing.expect(t, lexer.peek(&lx) == '.')
}

@(test)
lexer_string_test :: proc(t: ^testing.T) {
	lx := lexer.init("\"hello world\"")
	lexer.advance(&lx)
	tok := lexer.string(&lx, 1, 1)
	testing.expect(t, tok.kind == .String)
	testing.expect(t, tok.lexeme == "hello world")
	testing.expect(t, lexer.at_end(&lx))

	lx = lexer.init("\"unterminated")
	lexer.advance(&lx)
	tok = lexer.string(&lx, 1, 1)
	testing.expect(t, tok.kind == .Illegal)
	testing.expect(t, tok.lexeme == "unterminated")
}

@(test)
lexer_make_token_test :: proc(t: ^testing.T) {
	lx := lexer.init(":")
	lexer.advance(&lx)
	tok := lexer.make_token(&lx, .Colon, 1, 1)
	testing.expect(t, tok.kind == .Colon)
	testing.expect(t, tok.lexeme == ":")
	testing.expect(t, tok.line == 1)
	testing.expect(t, tok.column == 1)
}

@(test)
lexer_skip_line_comment_test :: proc(t: ^testing.T) {
	lx := lexer.init("comment\nnext")
	lexer.skip_line_comment(&lx)
	testing.expect(t, lexer.peek(&lx) == '\n')
	testing.expect(t, lx.line == 1)
}

@(test)
lexer_match_test :: proc(t: ^testing.T) {
	lx := lexer.init(">")
	testing.expect(t, lexer.match(&lx, '>'))
	testing.expect(t, lx.pos == 1)
	testing.expect(t, lexer.at_end(&lx))

	lx = lexer.init("x")
	testing.expect(t, !lexer.match(&lx, '>'))
	testing.expect(t, lx.pos == 0)
}

@(test)
lexer_advance_test :: proc(t: ^testing.T) {
	lx := lexer.init("a\nb")
	testing.expect(t, lexer.advance(&lx) == 'a')
	testing.expect(t, lx.line == 1)
	testing.expect(t, lx.column == 2)
	testing.expect(t, lexer.advance(&lx) == '\n')
	testing.expect(t, lx.line == 2)
	testing.expect(t, lx.column == 1)
}

@(test)
lexer_peek_test :: proc(t: ^testing.T) {
	lx := lexer.init("ab")
	testing.expect(t, lexer.peek(&lx) == 'a')
	lexer.advance(&lx)
	testing.expect(t, lexer.peek(&lx) == 'b')
	lexer.advance(&lx)
	testing.expect(t, lexer.peek(&lx) == 0)
}

@(test)
lexer_peek_next_test :: proc(t: ^testing.T) {
	lx := lexer.init("ab")
	testing.expect(t, lexer.peek_next(&lx) == 'b')
	lexer.advance(&lx)
	testing.expect(t, lexer.peek_next(&lx) == 0)
}

@(test)
lexer_at_end_test :: proc(t: ^testing.T) {
	lx := lexer.init("a")
	testing.expect(t, !lexer.at_end(&lx))
	lexer.advance(&lx)
	testing.expect(t, lexer.at_end(&lx))
}

@(test)
is_alpha_test :: proc(t: ^testing.T) {
	testing.expect(t, lexer.is_alpha('a'))
	testing.expect(t, lexer.is_alpha('Z'))
	testing.expect(t, !lexer.is_alpha('9'))
	testing.expect(t, !lexer.is_alpha('_'))
}

@(test)
is_digit_test :: proc(t: ^testing.T) {
	testing.expect(t, lexer.is_digit('9'))
	testing.expect(t, lexer.is_digit('0'))
	testing.expect(t, !lexer.is_digit('a'))
}
