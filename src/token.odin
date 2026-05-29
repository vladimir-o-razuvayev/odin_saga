package main

import "core:testing"

Token_Kind :: enum {
	Illegal,
	Eof,
	Identifier,
	String,
	Number,
	Newline,
	Colon,
	Comma,
	Dot,
	Arrow,
	Left_Paren,
	Right_Paren,
	Left_Brace,
	Right_Brace,
	Keyword_Story,
	Keyword_Scene,
	Keyword_Say,
	Keyword_Choice,
	Keyword_Goto,
	Keyword_End,
}

Token :: struct {
	kind:   Token_Kind,
	lexeme: string,
	line:   int,
	column: int,
}

token :: struct {
	keyword_kind: proc(ident: string) -> (Token_Kind, bool),
} {
	keyword_kind = proc(ident: string) -> (Token_Kind, bool) {
		switch ident {
		case "story":
			return .Keyword_Story, true
		case "scene":
			return .Keyword_Scene, true
		case "say":
			return .Keyword_Say, true
		case "choice":
			return .Keyword_Choice, true
		case "goto":
			return .Keyword_Goto, true
		case "end":
			return .Keyword_End, true
		}

		return .Identifier, false
	},
}

//****************************************/
// Tests
//****************************************/

@(test)
keyword_kind_test :: proc(t: ^testing.T) {
	kind, ok := token.keyword_kind("story")
	testing.expect(t, ok)
	testing.expect(t, kind == .Keyword_Story)

	kind, ok = token.keyword_kind("scene")
	testing.expect(t, ok)
	testing.expect(t, kind == .Keyword_Scene)

	kind, ok = token.keyword_kind("say")
	testing.expect(t, ok)
	testing.expect(t, kind == .Keyword_Say)

	kind, ok = token.keyword_kind("choice")
	testing.expect(t, ok)
	testing.expect(t, kind == .Keyword_Choice)

	kind, ok = token.keyword_kind("goto")
	testing.expect(t, ok)
	testing.expect(t, kind == .Keyword_Goto)

	kind, ok = token.keyword_kind("end")
	testing.expect(t, ok)
	testing.expect(t, kind == .Keyword_End)

	kind, ok = token.keyword_kind("odin")
	testing.expect(t, !ok)
	testing.expect(t, kind == .Identifier)
}
