package main

import "core:testing"

Parser :: struct {
	tokens:  []Token,
	current: int,
	errors:  [dynamic]Parse_Error,
}

parser :: struct {
	init:               proc(tokens: []Token) -> Parser,
	parse:              proc(p: ^Parser) -> Parse_Result,
	statement:          proc(p: ^Parser) -> (Statement, bool),
	scene_statement:    proc(p: ^Parser) -> Statement,
	dialogue_statement: proc(p: ^Parser) -> Statement,
	goto_statement:     proc(p: ^Parser) -> Statement,
	choice_statement:   proc(p: ^Parser) -> Statement,
	consume_identifier: proc(p: ^Parser, message: string) -> string,
	consume_string:     proc(p: ^Parser, message: string) -> string,
	consume:            proc(p: ^Parser, kind: Token_Kind, message: string) -> Token,
	match:              proc(p: ^Parser, kind: Token_Kind) -> bool,
	check:              proc(p: ^Parser, kind: Token_Kind) -> bool,
	advance:            proc(p: ^Parser) -> Token,
	at_end:             proc(p: ^Parser) -> bool,
	peek:               proc(p: ^Parser) -> Token,
	previous:           proc(p: ^Parser) -> Token,
	skip_newlines:      proc(p: ^Parser),
	synchronize:        proc(p: ^Parser),
	previous_safe:      proc(p: ^Parser) -> Token,
	error_at_current:   proc(p: ^Parser, message: string),
	error:              proc(p: ^Parser, tok: Token, message: string),
} {
	init = proc(tokens: []Token) -> Parser {
		return Parser{tokens = tokens, errors = make([dynamic]Parse_Error)}
	},
	parse = proc(p: ^Parser) -> Parse_Result {
		story := Story {
			statements = make([dynamic]Statement),
		}
		parser.skip_newlines(p)

		if parser.match(p, .Keyword_Story) {
			if parser.check(p, .String) || parser.check(p, .Identifier) {
				story.title = parser.advance(p).lexeme
			} else {
				parser.error_at_current(p, "expected story title after 'story'")
			}
		} else {
			parser.error_at_current(p, "expected story declaration")
		}

		for !parser.at_end(p) {
			parser.skip_newlines(p)
			if parser.at_end(p) {
				break
			}

			stmt, ok := parser.statement(p)
			if ok {
				append(&story.statements, stmt)
			} else {
				parser.synchronize(p)
			}
		}

		return Parse_Result{story = story, errors = p.errors}
	},
	statement = proc(p: ^Parser) -> (Statement, bool) {
		if parser.match(p, .Keyword_Scene) {
			return parser.scene_statement(p), true
		}
		if parser.match(p, .String) {
			prev := parser.previous(p)
			return Statement{kind = .Narration, text = prev.lexeme, token = prev}, true
		}
		if parser.match(p, .Keyword_Say) {
			return parser.dialogue_statement(p), true
		}
		if parser.match(p, .Keyword_Choice) {
			return parser.choice_statement(p), true
		}
		if parser.match(p, .Keyword_Goto) {
			return parser.goto_statement(p), true
		}
		if parser.match(p, .Keyword_End) {
			return Statement{}, false
		}

		parser.error_at_current(
			p,
			"expected scene, narration, dialogue, choice, or goto statement",
		)
		return Statement{}, false
	},
	scene_statement = proc(p: ^Parser) -> Statement {
		tok := parser.previous(p)
		name := parser.consume_identifier(p, "expected scene name after 'scene'")
		parser.match(p, .Colon)
		return Statement{kind = .Scene, name = name, token = tok}
	},
	dialogue_statement = proc(p: ^Parser) -> Statement {
		tok := parser.previous(p)
		speaker := parser.consume_identifier(p, "expected speaker name after 'say'")
		parser.consume(p, .Colon, "expected ':' after speaker name")
		line := parser.consume_string(p, "expected dialogue text after ':'")
		return Statement{kind = .Dialogue, name = speaker, text = line, token = tok}
	},
	goto_statement = proc(p: ^Parser) -> Statement {
		tok := parser.previous(p)
		target := parser.consume_identifier(p, "expected scene target after 'goto'")
		return Statement{kind = .Goto, target = target, token = tok}
	},
	choice_statement = proc(p: ^Parser) -> Statement {
		tok := parser.previous(p)
		stmt := Statement {
			kind    = .Choice_Block,
			choices = make([dynamic]Choice_Option),
			token   = tok,
		}
		parser.match(p, .Colon)
		parser.skip_newlines(p)

		for !parser.at_end(p) && parser.check(p, .String) {
			option_token := parser.advance(p)
			parser.consume(p, .Arrow, "expected '->' after choice text")
			target := parser.consume_identifier(p, "expected scene target after '->'")
			append(
				&stmt.choices,
				Choice_Option{text = option_token.lexeme, target = target, token = option_token},
			)
			parser.skip_newlines(p)
		}

		if len(stmt.choices) == 0 {
			parser.error(p, tok, "expected at least one choice option")
		}

		return stmt
	},
	consume_identifier = proc(p: ^Parser, message: string) -> string {
		if parser.check(p, .Identifier) {
			return parser.advance(p).lexeme
		}
		parser.error_at_current(p, message)
		return ""
	},
	consume_string = proc(p: ^Parser, message: string) -> string {
		if parser.check(p, .String) {
			return parser.advance(p).lexeme
		}
		parser.error_at_current(p, message)
		return ""
	},
	consume = proc(p: ^Parser, kind: Token_Kind, message: string) -> Token {
		if parser.check(p, kind) {
			return parser.advance(p)
		}
		parser.error_at_current(p, message)
		return parser.peek(p)
	},
	match = proc(p: ^Parser, kind: Token_Kind) -> bool {
		if !parser.check(p, kind) {
			return false
		}
		parser.advance(p)
		return true
	},
	check = proc(p: ^Parser, kind: Token_Kind) -> bool {
		if parser.at_end(p) {
			return kind == .Eof
		}
		return parser.peek(p).kind == kind
	},
	advance = proc(p: ^Parser) -> Token {
		if !parser.at_end(p) {
			p.current += 1
		}
		return parser.previous(p)
	},
	at_end = proc(p: ^Parser) -> bool {
		return parser.peek(p).kind == .Eof
	},
	peek = proc(p: ^Parser) -> Token {
		return p.tokens[p.current]
	},
	previous = proc(p: ^Parser) -> Token {
		return p.tokens[p.current - 1]
	},
	skip_newlines = proc(p: ^Parser) {
		for parser.match(p, .Newline) {}
	},
	synchronize = proc(p: ^Parser) {
		if !parser.at_end(p) {
			parser.advance(p)
		}

		for !parser.at_end(p) {
			if parser.previous(p).kind == .Newline {
				return
			}

			#partial switch parser.peek(p).kind {
			case .Keyword_Scene, .Keyword_Say, .Keyword_Choice, .Keyword_Goto, .String:
				return
			}

			parser.advance(p)
		}
	},
	previous_safe = proc(p: ^Parser) -> Token {
		if p.current == 0 {
			return parser.peek(p)
		}
		return parser.previous(p)
	},
	error_at_current = proc(p: ^Parser, message: string) {
		parser.error(p, parser.peek(p), message)
	},
	error = proc(p: ^Parser, tok: Token, message: string) {
		append(&p.errors, Parse_Error{message = message, token = tok})
	},
}

//****************************************/
// Tests
//****************************************/

test_token :: proc(kind: Token_Kind, lexeme := "") -> Token {
	return Token{kind = kind, lexeme = lexeme, line = 1, column = 1}
}

@(test)
parser_init_test :: proc(t: ^testing.T) {
	tokens := [?]Token{test_token(.Eof)}
	p := parser.init(tokens[:])
	defer delete(p.errors)

	testing.expect(t, len(p.tokens) == 1)
	testing.expect(t, p.current == 0)
	testing.expect(t, len(p.errors) == 0)
}

@(test)
parser_cursor_helpers_test :: proc(t: ^testing.T) {
	tokens := [?]Token {
		test_token(.Newline, "\n"),
		test_token(.Identifier, "intro"),
		test_token(.Eof),
	}
	p := parser.init(tokens[:])
	defer delete(p.errors)

	testing.expect(t, parser.peek(&p).kind == .Newline)
	testing.expect(t, parser.check(&p, .Newline))
	testing.expect(t, parser.match(&p, .Newline))
	testing.expect(t, parser.previous(&p).kind == .Newline)
	testing.expect(t, parser.previous_safe(&p).kind == .Newline)
	testing.expect(t, p.current == 1)

	parser.skip_newlines(&p)
	testing.expect(t, p.current == 1)
	testing.expect(t, parser.advance(&p).lexeme == "intro")
	testing.expect(t, parser.at_end(&p))
	testing.expect(t, parser.check(&p, .Eof))
	testing.expect(t, parser.previous_safe(&p).kind == .Identifier)
}

@(test)
parser_consume_helpers_test :: proc(t: ^testing.T) {
	tokens := [?]Token {
		test_token(.Identifier, "Odin"),
		test_token(.Colon, ":"),
		test_token(.String, "Hello"),
		test_token(.Eof),
	}
	p := parser.init(tokens[:])
	defer delete(p.errors)

	testing.expect(t, parser.consume_identifier(&p, "identifier expected") == "Odin")
	testing.expect(t, parser.consume(&p, .Colon, "colon expected").kind == .Colon)
	testing.expect(t, parser.consume_string(&p, "string expected") == "Hello")
	testing.expect(t, len(p.errors) == 0)

	parser.consume(&p, .Colon, "missing colon")
	testing.expect(t, len(p.errors) == 1)
	testing.expect(t, p.errors[0].message == "missing colon")
}

@(test)
parser_statement_test :: proc(t: ^testing.T) {
	scene_tokens := [?]Token {
		test_token(.Keyword_Scene, "scene"),
		test_token(.Identifier, "intro"),
		test_token(.Colon, ":"),
		test_token(.Eof),
	}
	p := parser.init(scene_tokens[:])
	stmt, ok := parser.statement(&p)
	testing.expect(t, ok)
	testing.expect(t, stmt.kind == .Scene)
	testing.expect(t, stmt.name == "intro")
	delete(p.errors)

	narration_tokens := [?]Token{test_token(.String, "Opening"), test_token(.Eof)}
	p = parser.init(narration_tokens[:])
	stmt, ok = parser.statement(&p)
	testing.expect(t, ok)
	testing.expect(t, stmt.kind == .Narration)
	testing.expect(t, stmt.text == "Opening")
	delete(p.errors)

	dialogue_tokens := [?]Token {
		test_token(.Keyword_Say, "say"),
		test_token(.Identifier, "Odin"),
		test_token(.Colon, ":"),
		test_token(.String, "Hi"),
		test_token(.Eof),
	}
	p = parser.init(dialogue_tokens[:])
	stmt, ok = parser.statement(&p)
	testing.expect(t, ok)
	testing.expect(t, stmt.kind == .Dialogue)
	testing.expect(t, stmt.name == "Odin")
	testing.expect(t, stmt.text == "Hi")
	delete(p.errors)

	choice_tokens := [?]Token {
		test_token(.Keyword_Choice, "choice"),
		test_token(.Colon, ":"),
		test_token(.Newline, "\n"),
		test_token(.String, "Go"),
		test_token(.Arrow, "->"),
		test_token(.Identifier, "next"),
		test_token(.Eof),
	}
	p = parser.init(choice_tokens[:])
	stmt, ok = parser.statement(&p)
	testing.expect(t, ok)
	testing.expect(t, stmt.kind == .Choice_Block)
	testing.expect(t, len(stmt.choices) == 1)
	testing.expect(t, stmt.choices[0].text == "Go")
	testing.expect(t, stmt.choices[0].target == "next")
	delete(stmt.choices)
	delete(p.errors)

	goto_tokens := [?]Token {
		test_token(.Keyword_Goto, "goto"),
		test_token(.Identifier, "next"),
		test_token(.Eof),
	}
	p = parser.init(goto_tokens[:])
	stmt, ok = parser.statement(&p)
	testing.expect(t, ok)
	testing.expect(t, stmt.kind == .Goto)
	testing.expect(t, stmt.target == "next")
	delete(p.errors)

	end_tokens := [?]Token{test_token(.Keyword_End, "end"), test_token(.Eof)}
	p = parser.init(end_tokens[:])
	stmt, ok = parser.statement(&p)
	testing.expect(t, !ok)
	delete(p.errors)

	bad_tokens := [?]Token{test_token(.Illegal, "?"), test_token(.Eof)}
	p = parser.init(bad_tokens[:])
	stmt, ok = parser.statement(&p)
	testing.expect(t, !ok)
	testing.expect(t, len(p.errors) == 1)
	delete(p.errors)
}

@(test)
parser_synchronize_test :: proc(t: ^testing.T) {
	tokens := [?]Token {
		test_token(.Illegal, "?"),
		test_token(.Illegal, "?"),
		test_token(.Newline, "\n"),
		test_token(.Keyword_Goto, "goto"),
		test_token(.Identifier, "next"),
		test_token(.Eof),
	}
	p := parser.init(tokens[:])
	defer delete(p.errors)

	parser.synchronize(&p)
	testing.expect(t, p.current == 3)
	testing.expect(t, parser.peek(&p).kind == .Keyword_Goto)

	tokens_2 := [?]Token {
		test_token(.Illegal, "?"),
		test_token(.Keyword_Scene, "scene"),
		test_token(.Identifier, "intro"),
		test_token(.Eof),
	}
	p_2 := parser.init(tokens_2[:])
	defer delete(p_2.errors)

	parser.synchronize(&p_2)
	testing.expect(t, p_2.current == 1)
	testing.expect(t, parser.peek(&p_2).kind == .Keyword_Scene)
}

@(test)
parser_error_test :: proc(t: ^testing.T) {
	tokens := [?]Token{test_token(.Identifier, "bad"), test_token(.Eof)}
	p := parser.init(tokens[:])
	defer delete(p.errors)

	parser.error_at_current(&p, "current error")
	parser.error(&p, tokens[1], "explicit error")

	testing.expect(t, len(p.errors) == 2)
	testing.expect(t, p.errors[0].message == "current error")
	testing.expect(t, p.errors[0].token.lexeme == "bad")
	testing.expect(t, p.errors[1].message == "explicit error")
	testing.expect(t, p.errors[1].token.kind == .Eof)
}

@(test)
parser_parse_test :: proc(t: ^testing.T) {
	lx := lexer.init(
		"story \"Saga\"\nscene intro:\n\"Opening\"\nsay Odin: \"Hi\"\nchoice:\n\"Go\" -> next\n\"Stay\" -> intro\ngoto next\n",
	)
	tokens := lexer.scan_all(&lx)
	defer delete(tokens)

	p := parser.init(tokens[:])
	result := parser.parse(&p)
	defer delete(result.errors)
	defer delete(result.story.statements)
	defer delete(result.story.statements[3].choices)

	testing.expect(t, len(result.errors) == 0)
	testing.expect(t, result.story.title == "Saga")
	testing.expect(t, len(result.story.statements) == 5)

	testing.expect(t, result.story.statements[0].kind == .Scene)
	testing.expect(t, result.story.statements[0].name == "intro")

	testing.expect(t, result.story.statements[1].kind == .Narration)
	testing.expect(t, result.story.statements[1].text == "Opening")

	testing.expect(t, result.story.statements[2].kind == .Dialogue)
	testing.expect(t, result.story.statements[2].name == "Odin")
	testing.expect(t, result.story.statements[2].text == "Hi")

	testing.expect(t, result.story.statements[3].kind == .Choice_Block)
	testing.expect(t, len(result.story.statements[3].choices) == 2)
	testing.expect(t, result.story.statements[3].choices[0].text == "Go")
	testing.expect(t, result.story.statements[3].choices[0].target == "next")
	testing.expect(t, result.story.statements[3].choices[1].text == "Stay")
	testing.expect(t, result.story.statements[3].choices[1].target == "intro")

	testing.expect(t, result.story.statements[4].kind == .Goto)
	testing.expect(t, result.story.statements[4].target == "next")
}

@(test)
parser_reports_errors_and_synchronizes_test :: proc(t: ^testing.T) {
	lx := lexer.init("story\n???\nscene recovered:\nchoice:\n")
	tokens := lexer.scan_all(&lx)
	defer delete(tokens)

	p := parser.init(tokens[:])
	result := parser.parse(&p)
	defer delete(result.errors)
	defer delete(result.story.statements)
	defer delete(result.story.statements[1].choices)

	testing.expect(t, len(result.errors) >= 3)
	testing.expect(t, len(result.story.statements) == 2)
	testing.expect(t, result.story.statements[0].kind == .Scene)
	testing.expect(t, result.story.statements[0].name == "recovered")
	testing.expect(t, result.story.statements[1].kind == .Choice_Block)
	testing.expect(t, len(result.story.statements[1].choices) == 0)
}
