package main

import "core:testing"

Lexer :: struct {
	source: string,
	file:   string,
}

lexer :: struct {
	init:          proc(source: string, file := "<input>") -> Lexer,
	scan_lines:    proc(l: ^Lexer) -> Lexer_Result,
	strip_comment: proc(line: string, pos: Source_Pos) -> (string, bool, Diagnostic),
	trim:          proc(s: string) -> string,
	trim_left:     proc(s: string) -> string,
	trim_right:    proc(s: string) -> string,
	count_indent:  proc(s: string) -> int,
	starts_with:   proc(s: string, prefix: string) -> bool,
	index_of:      proc(s: string, needle: string) -> int,
} {
	init = proc(source: string, file := "<input>") -> Lexer {
		return Lexer{source = source, file = file}
	},
	scan_lines = proc(l: ^Lexer) -> Lexer_Result {
		result := Lexer_Result {
			lines  = make([dynamic]Source_Line),
			errors = make([dynamic]Diagnostic),
		}

		line_start := 0
		line_no := 1
		for i := 0; i <= len(l.source); i += 1 {
			if i != len(l.source) && l.source[i] != '\n' {
				continue
			}

			raw := l.source[line_start:i]
			if len(raw) > 0 && raw[len(raw) - 1] == '\r' {
				raw = raw[:len(raw) - 1]
			}

			pos := Source_Pos {
				file   = l.file,
				line   = line_no,
				column = 1,
			}
			without_comment, ok, err := lexer.strip_comment(raw, pos)
			if !ok {
				append(&result.errors, err)
			}

			trimmed_right := lexer.trim_right(without_comment)
			trimmed := lexer.trim_left(trimmed_right)
			append(
				&result.lines,
				Source_Line {
					raw = raw,
					text = trimmed,
					indent = lexer.count_indent(without_comment),
					pos = pos,
				},
			)

			line_start = i + 1
			line_no += 1
		}

		return result
	},
	strip_comment = proc(line: string, pos: Source_Pos) -> (string, bool, Diagnostic) {
		in_expr := false
		for i := 0; i < len(line); i += 1 {
			ch := line[i]
			if ch == '`' {
				in_expr = !in_expr
				continue
			}

			if ch == '/' && i + 1 < len(line) && line[i + 1] == '/' {
				if in_expr {
					return line, false, Diagnostic {
						message = "comments are not allowed inside backtick expressions",
						pos = Source_Pos{file = pos.file, line = pos.line, column = i + 1},
					}
				}

				if i == 0 || token.is_space(line[i - 1]) {
					return line[:i], true, Diagnostic{}
				}
			}
		}

		if in_expr {
			return line, false, Diagnostic{message = "unterminated backtick expression", pos = pos}
		}

		return line, true, Diagnostic{}
	},
	trim = proc(s: string) -> string {
		return lexer.trim_left(lexer.trim_right(s))
	},
	trim_left = proc(s: string) -> string {
		start := 0
		for start < len(s) && token.is_space(s[start]) {
			start += 1
		}
		return s[start:]
	},
	trim_right = proc(s: string) -> string {
		end := len(s)
		for end > 0 && token.is_space(s[end - 1]) {
			end -= 1
		}
		return s[:end]
	},
	count_indent = proc(s: string) -> int {
		count := 0
		for count < len(s) && (s[count] == ' ' || s[count] == '\t') {
			count += 1
		}
		return count
	},
	starts_with = proc(s: string, prefix: string) -> bool {
		if len(prefix) > len(s) {
			return false
		}
		return s[:len(prefix)] == prefix
	},
	index_of = proc(s: string, needle: string) -> int {
		if len(needle) == 0 || len(needle) > len(s) {
			return -1
		}
		for i := 0; i <= len(s) - len(needle); i += 1 {
			if s[i:i + len(needle)] == needle {
				return i
			}
		}
		return -1
	},
}

//****************************************/
// Tests
//****************************************/

@(test)
lexer_scan_lines_test :: proc(t: ^testing.T) {
	lx := lexer.init("# Main\n  > Text // comment\n  `x = 1`\n", "main.saga")
	result := lexer.scan_lines(&lx)
	defer delete(result.lines)
	defer delete(result.errors)

	testing.expect(t, len(result.errors) == 0)
	testing.expect(t, len(result.lines) == 4)
	testing.expect(t, result.lines[0].text == "# Main")
	testing.expect(t, result.lines[1].text == "> Text")
	testing.expect(t, result.lines[1].indent == 2)
	testing.expect(t, result.lines[2].text == "`x = 1`")
	testing.expect(t, result.lines[2].pos.line == 3)
}

@(test)
lexer_comment_rules_test :: proc(t: ^testing.T) {
	line, ok, _ := lexer.strip_comment("> Text // ok", Source_Pos{})
	testing.expect(t, ok)
	testing.expect(t, lexer.trim(line) == "> Text")

	line, ok, _ = lexer.strip_comment("> https://example.com", Source_Pos{})
	testing.expect(t, ok)
	testing.expect(t, lexer.trim(line) == "> https://example.com")

	_, bad_ok, err := lexer.strip_comment("`x // bad`", Source_Pos{line = 7})
	testing.expect(t, !bad_ok)
	testing.expect(t, err.pos.line == 7)
}

@(test)
lexer_string_helpers_test :: proc(t: ^testing.T) {
	testing.expect(t, lexer.trim("  hello \t") == "hello")
	testing.expect(t, lexer.count_indent("  hello") == 2)
	testing.expect(t, lexer.starts_with("abcdef", "abc"))
	testing.expect(t, !lexer.starts_with("ab", "abc"))
	testing.expect(t, lexer.index_of("one -> two", "->") == 4)
	testing.expect(t, lexer.index_of("one", "->") == -1)
}
