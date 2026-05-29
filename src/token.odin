package main

import "core:testing"

token :: struct {
	is_scene_label: proc(label: string) -> bool,
	is_space:       proc(ch: u8) -> bool,
	is_alpha:       proc(ch: u8) -> bool,
	is_digit:       proc(ch: u8) -> bool,
} {
	is_scene_label = proc(label: string) -> bool {
		if len(label) == 0 {
			return false
		}

		first := label[0]
		if !(token.is_alpha(first) || first == '_') {
			return false
		}

		for i := 1; i < len(label); i += 1 {
			ch := label[i]
			if !(token.is_alpha(ch) || token.is_digit(ch) || ch == '_') {
				return false
			}
		}

		return true
	},
	is_space = proc(ch: u8) -> bool {
		return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
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
token_is_scene_label_test :: proc(t: ^testing.T) {
	testing.expect(t, token.is_scene_label("Main"))
	testing.expect(t, token.is_scene_label("WomanInRedDress"))
	testing.expect(t, token.is_scene_label("_Secret"))
	testing.expect(t, token.is_scene_label("Scene_1"))
	testing.expect(t, !token.is_scene_label(""))
	testing.expect(t, !token.is_scene_label("1Scene"))
	testing.expect(t, !token.is_scene_label("bad-name"))
	testing.expect(t, !token.is_scene_label("Bad.Name"))
}

@(test)
token_character_class_test :: proc(t: ^testing.T) {
	testing.expect(t, token.is_alpha('a'))
	testing.expect(t, token.is_alpha('Z'))
	testing.expect(t, token.is_digit('9'))
	testing.expect(t, token.is_space(' '))
	testing.expect(t, token.is_space('\t'))
	testing.expect(t, !token.is_alpha('9'))
	testing.expect(t, !token.is_digit('x'))
}
