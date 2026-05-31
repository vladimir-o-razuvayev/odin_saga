package main

import "core:fmt"
import "core:os"
import "core:testing"

Parser :: struct {
	lines:   []Source_Line,
	current: int,
	errors:  [dynamic]Diagnostic,
	file:    string,
}

Parsed_Expression :: struct {
	expr: string,
	rest: string,
	ok:   bool,
}


Parsed_Target_Link :: struct {
	label:  string,
	target: Target,
	rest:   string,
	ok:     bool,
}

parser :: struct {
	init:                   proc(lines: []Source_Line, file := "<input>") -> Parser,
	parse:                  proc(p: ^Parser) -> Parse_Result,
	parse_heading:          proc(
		p: ^Parser,
		line: Source_Line,
		stack: ^[32]string,
		current_depth: ^int,
	) -> bool,
	parse_statement:        proc(p: ^Parser, line: Source_Line, scene: ^Scene),
	parse_passage:          proc(p: ^Parser, line: Source_Line) -> Statement,
	parse_image:            proc(p: ^Parser, line: Source_Line) -> Statement,
	parse_dialogue:         proc(p: ^Parser, line: Source_Line, current_depth: int) -> Statement,
	parse_choice:           proc(p: ^Parser, line: Source_Line, current_depth: int) -> Statement,
	parse_effect:           proc(p: ^Parser, line: Source_Line) -> Statement,
	parse_link_target:      proc(
		p: ^Parser,
		text: string,
		pos: Source_Pos,
		current_depth: int,
	) -> Parsed_Target_Link,
	parse_destination:      proc(
		p: ^Parser,
		destination: string,
		pos: Source_Pos,
		current_depth: int,
	) -> (
		Target,
		bool,
	),
	parse_widget_decorator: proc(p: ^Parser, line: Source_Line) -> (string, bool),
	parse_leading_expr:     proc(text: string) -> Parsed_Expression,
	validate_scene_ref:     proc(p: ^Parser, ref: string, pos: Source_Pos, current_depth: int),
	parse_path_labels:      proc(p: ^Parser, path: string, pos: Source_Pos) -> bool,
	build_scene_path:       proc(stack: ^[32]string, depth: int) -> string,
	current_scene:          proc(p: ^Parser, module: ^Module) -> ^Scene,
	append_error:           proc(p: ^Parser, pos: Source_Pos, message: string),
	starts_with_arrow:      proc(text: string) -> (Transfer_Kind, string, bool),
} {
	init = proc(lines: []Source_Line, file := "<input>") -> Parser {
		return Parser{lines = lines, errors = make([dynamic]Diagnostic), file = file}
	},
	parse = proc(p: ^Parser) -> Parse_Result {
		module := Module {
			file   = p.file,
			scenes = make([dynamic]Scene),
		}
		stack: [32]string
		current_depth := 0
		pending_widget := ""
		pending_widget_pos := Source_Pos{}

		for line in p.lines {
			if len(line.text) == 0 {
				continue
			}

			if lexer.starts_with(line.text, "@") {
				widget, ok := parser.parse_widget_decorator(p, line)
				if ok {
					pending_widget = widget
					pending_widget_pos = line.pos
				}
				continue
			}

			if lexer.starts_with(line.text, "#") {
				if parser.parse_heading(p, line, &stack, &current_depth) {
					name := stack[current_depth - 1]
					append(
						&module.scenes,
						Scene {
							name = name,
							path = parser.build_scene_path(&stack, current_depth),
							depth = current_depth,
							widget = pending_widget,
							statements = make([dynamic]Statement),
							pos = line.pos,
						},
					)
					pending_widget = ""
					pending_widget_pos = Source_Pos{}
				}
				continue
			}

			if len(pending_widget) > 0 {
				parser.append_error(
					p,
					pending_widget_pos,
					"decorator must be followed by a scene heading",
				)
				pending_widget = ""
				pending_widget_pos = Source_Pos{}
			}

			if len(module.scenes) == 0 {
				parser.append_error(p, line.pos, "statement appears before first scene heading")
				continue
			}

			scene := parser.current_scene(p, &module)
			parser.parse_statement(p, line, scene)
		}

		if len(pending_widget) > 0 {
			parser.append_error(
				p,
				pending_widget_pos,
				"decorator must be followed by a scene heading",
			)
		}

		return Parse_Result{module = module, errors = p.errors}
	},
	parse_heading = proc(
		p: ^Parser,
		line: Source_Line,
		stack: ^[32]string,
		current_depth: ^int,
	) -> bool {
		depth := 0
		for depth < len(line.text) && line.text[depth] == '#' {
			depth += 1
		}

		if depth == 0 || depth > len(stack) {
			parser.append_error(p, line.pos, "invalid heading depth")
			return false
		}

		if depth >= len(line.text) || !token.is_space(line.text[depth]) {
			parser.append_error(p, line.pos, "expected space after heading marker")
			return false
		}

		label := lexer.trim(line.text[depth:])
		if !token.is_scene_label(label) {
			parser.append_error(p, line.pos, "invalid scene label")
			return false
		}

		stack[depth - 1] = label
		current_depth^ = depth
		return true
	},
	parse_statement = proc(p: ^Parser, line: Source_Line, scene: ^Scene) {
		text := line.text
		stmt: Statement

		if lexer.starts_with(text, ">>") {
			stmt = parser.parse_dialogue(p, line, scene.depth)
		} else if lexer.starts_with(text, ">") {
			stmt = parser.parse_passage(p, line)
		} else if lexer.starts_with(text, "![") {
			stmt = parser.parse_image(p, line)
		} else if lexer.starts_with(text, "+") || lexer.starts_with(text, "-") {
			stmt = parser.parse_choice(p, line, scene.depth)
		} else if lexer.starts_with(text, "`") {
			stmt = parser.parse_effect(p, line)
		} else {
			parser.append_error(p, line.pos, "unknown statement")
			return
		}

		append(&scene.statements, stmt)
	},
	parse_passage = proc(p: ^Parser, line: Source_Line) -> Statement {
		rest := lexer.trim(line.text[1:])
		show_if := ""
		parsed := parser.parse_leading_expr(rest)
		if parsed.ok {
			show_if = parsed.expr
			rest = lexer.trim(parsed.rest)
		}
		if len(rest) == 0 {
			parser.append_error(p, line.pos, "expected passage text")
		}
		return Statement{kind = .Passage, text = rest, show_if = show_if, pos = line.pos}
	},
	parse_image = proc(p: ^Parser, line: Source_Line) -> Statement {
		text := line.text
		close_alt := lexer.index_of(text, "](")
		if close_alt < 0 || len(text) < 5 || text[len(text) - 1] != ')' {
			parser.append_error(p, line.pos, "invalid image syntax")
			return Statement{kind = .Image, pos = line.pos}
		}

		alt := text[2:close_alt]
		src := lexer.trim(text[close_alt + 2:len(text) - 1])
		if len(src) >= 2 && src[0] == '"' && src[len(src) - 1] == '"' {
			src = src[1:len(src) - 1]
		}
		if len(src) == 0 {
			parser.append_error(p, line.pos, "expected image path")
		}
		return Statement{kind = .Image, text = alt, image_src = src, pos = line.pos}
	},
	parse_dialogue = proc(p: ^Parser, line: Source_Line, current_depth: int) -> Statement {
		rest := lexer.trim(line.text[2:])
		show_if := ""
		parsed := parser.parse_leading_expr(rest)
		if parsed.ok {
			show_if = parsed.expr
			rest = lexer.trim(parsed.rest)
		}

		speaker := Target{}
		if len(rest) > 0 && rest[0] == '[' {
			link := parser.parse_link_target(p, rest, line.pos, current_depth)
			if link.ok {
				speaker = link.target
				rest = lexer.trim(link.rest)
			}
		}

		return Statement {
			kind = .Dialogue,
			text = rest,
			show_if = show_if,
			speaker = speaker,
			pos = line.pos,
		}
	},
	parse_choice = proc(p: ^Parser, line: Source_Line, current_depth: int) -> Statement {
		mode := Choice_Mode.Additive
		if line.text[0] == '-' {
			mode = .Fallback
		}
		rest := lexer.trim(line.text[1:])
		show_if := ""
		parsed := parser.parse_leading_expr(rest)
		if parsed.ok {
			show_if = parsed.expr
			rest = lexer.trim(parsed.rest)
		}

		new_kind, new_after_arrow, new_arrow_ok := parser.starts_with_arrow(rest)
		if new_arrow_ok {
			enable_if := ""
			parsed = parser.parse_leading_expr(new_after_arrow)
			if parsed.ok {
				enable_if = parsed.expr
				new_after_arrow = lexer.trim(parsed.rest)
			}

			link := parser.parse_link_target(p, new_after_arrow, line.pos, current_depth)
			if !link.ok {
				parser.append_error(p, line.pos, "expected choice target")
				return Statement {
					kind = .Choice,
					show_if = show_if,
					enable_if = enable_if,
					choice_mode = mode,
					pos = line.pos,
				}
			}
			if len(link.label) == 0 {
				parser.append_error(p, line.pos, "expected choice text")
			}
			if len(lexer.trim(link.rest)) > 0 {
				parser.append_error(p, line.pos, "unexpected text after choice target")
			}
			return Statement {
				kind = .Choice,
				text = link.label,
				show_if = show_if,
				enable_if = enable_if,
				choice_mode = mode,
				transfer = Transfer{kind = new_kind, target = link.target},
				pos = line.pos,
			}
		}

		parser.append_error(p, line.pos, "expected choice arrow followed by [label](destination)")
		return Statement{kind = .Choice, show_if = show_if, choice_mode = mode, pos = line.pos}
	},
	parse_effect = proc(p: ^Parser, line: Source_Line) -> Statement {
		parsed := parser.parse_leading_expr(line.text)
		if !parsed.ok {
			parser.append_error(p, line.pos, "expected effect expression")
			return Statement{kind = .Effect, pos = line.pos}
		}
		if len(lexer.trim(parsed.rest)) > 0 {
			parser.append_error(p, line.pos, "unexpected text after effect expression")
		}
		return Statement{kind = .Effect, effect = parsed.expr, pos = line.pos}
	},
	parse_link_target = proc(
		p: ^Parser,
		text: string,
		pos: Source_Pos,
		current_depth: int,
	) -> Parsed_Target_Link {
		trimmed_text := lexer.trim(text)
		if len(trimmed_text) < 5 || trimmed_text[0] != '[' {
			return Parsed_Target_Link{}
		}

		close_label := lexer.index_of(trimmed_text, "](")
		if close_label < 0 {
			return Parsed_Target_Link{}
		}

		dest_start := close_label + 2
		dest_end := -1
		for i := dest_start; i < len(trimmed_text); i += 1 {
			if trimmed_text[i] == ')' {
				dest_end = i
				break
			}
		}
		if dest_end < 0 {
			return Parsed_Target_Link{}
		}

		label := trimmed_text[1:close_label]
		destination := lexer.trim(trimmed_text[dest_start:dest_end])
		if len(destination) == 0 || destination[0] == '"' {
			return Parsed_Target_Link{}
		}
		if destination[0] == '/' && lexer.index_of(destination, "#") < 0 {
			return Parsed_Target_Link{}
		}

		target, ok := parser.parse_destination(p, destination, pos, current_depth)
		if !ok {
			return Parsed_Target_Link{}
		}

		return Parsed_Target_Link {
			label = label,
			target = target,
			rest = trimmed_text[dest_end + 1:],
			ok = true,
		}
	},
	parse_destination = proc(
		p: ^Parser,
		destination: string,
		pos: Source_Pos,
		current_depth: int,
	) -> (
		Target,
		bool,
	) {
		trimmed_destination := lexer.trim(destination)
		if len(trimmed_destination) == 0 {
			return Target{}, false
		}

		module_path := ""
		scene_ref := ""
		if trimmed_destination == "end:" {
			scene_ref = "end:"
		} else if trimmed_destination[0] == '#' {
			scene_ref = trimmed_destination[1:]
		} else if trimmed_destination[0] == '/' {
			hash := lexer.index_of(trimmed_destination, "#")
			if hash < 0 {
				parser.append_error(p, pos, "internal destinations must include a #scene target")
				return Target{}, false
			}
			module_path = trimmed_destination[:hash]
			scene_ref = trimmed_destination[hash + 1:]
			if len(module_path) == 0 || module_path[0] != '/' {
				parser.append_error(p, pos, "module paths must be root-relative in v0")
			}
		} else {
			return Target{}, false
		}

		if len(scene_ref) == 0 {
			parser.append_error(p, pos, "expected scene target after #")
			return Target{}, false
		}
		if scene_ref != "end:" {
			parser.validate_scene_ref(p, scene_ref, pos, current_depth)
		}
		return Target{scene_ref = scene_ref, module_path = module_path, pos = pos}, true
	},
	parse_widget_decorator = proc(p: ^Parser, line: Source_Line) -> (string, bool) {
		rest := lexer.trim(line.text[1:])
		if !lexer.starts_with(rest, "widget") {
			parser.append_error(p, line.pos, "unknown decorator")
			return "", false
		}

		value := lexer.trim(rest[len("widget"):])
		if len(value) == 0 {
			parser.append_error(p, line.pos, "expected widget renderer")
			return "", false
		}
		return value, true
	},
	parse_leading_expr = proc(text: string) -> Parsed_Expression {
		trimmed_text := lexer.trim(text)
		if len(trimmed_text) == 0 || trimmed_text[0] != '`' {
			return Parsed_Expression{}
		}
		for i := 1; i < len(trimmed_text); i += 1 {
			if trimmed_text[i] == '`' {
				return Parsed_Expression {
					expr = trimmed_text[1:i],
					rest = trimmed_text[i + 1:],
					ok = true,
				}
			}
		}
		return Parsed_Expression{}
	},
	validate_scene_ref = proc(p: ^Parser, ref: string, pos: Source_Pos, current_depth: int) {
		if ref == "." {
			// self target
		} else if ref == ".." {
			if current_depth <= 1 {
				parser.append_error(p, pos, "[..] cannot be used from a top-level scene")
			}
		} else if lexer.starts_with(ref, "..") {
			if current_depth <= 1 {
				parser.append_error(
					p,
					pos,
					"sibling targets cannot be used from a top-level scene",
				)
			}
			parser.parse_path_labels(p, ref[2:], pos)
		} else if lexer.starts_with(ref, ".") {
			parser.parse_path_labels(p, ref[1:], pos)
		} else {
			parser.parse_path_labels(p, ref, pos)
		}
	},
	parse_path_labels = proc(p: ^Parser, path: string, pos: Source_Pos) -> bool {
		if len(path) == 0 {
			parser.append_error(p, pos, "expected scene path")
			return false
		}

		start := 0
		for i := 0; i <= len(path); i += 1 {
			if i != len(path) && path[i] != '.' {
				continue
			}
			label := path[start:i]
			if !token.is_scene_label(label) {
				parser.append_error(p, pos, "invalid scene path label")
				return false
			}
			start = i + 1
		}
		return true
	},
	build_scene_path = proc(stack: ^[32]string, depth: int) -> string {
		path := stack[0]
		for i := 1; i < depth; i += 1 {
			path = fmt.tprintf("%s.%s", path, stack[i])
		}
		return path
	},
	current_scene = proc(p: ^Parser, module: ^Module) -> ^Scene {
		return &module.scenes[len(module.scenes) - 1]
	},
	append_error = proc(p: ^Parser, pos: Source_Pos, message: string) {
		append(&p.errors, Diagnostic{message = message, pos = pos})
	},
	starts_with_arrow = proc(text: string) -> (Transfer_Kind, string, bool) {
		trimmed_text := lexer.trim(text)
		if lexer.starts_with(trimmed_text, "*->") {
			if len(trimmed_text) == 3 || !token.is_space(trimmed_text[3]) {
				return .Once, "", false
			}
			return .Once, lexer.trim(trimmed_text[3:]), true
		}

		if lexer.starts_with(trimmed_text, "->") {
			if len(trimmed_text) == 2 || !token.is_space(trimmed_text[2]) {
				return .Normal, "", false
			}
			return .Normal, lexer.trim(trimmed_text[2:]), true
		}
		return .Normal, "", false
	},
}

free_parse_result :: proc(result: Parse_Result) {
	for scene in result.module.scenes {
		delete(scene.statements)
	}
	delete(result.module.scenes)
	delete(result.errors)
}

//****************************************/
// Tests
//****************************************/

parse_source_for_test :: proc(source: string) -> (Parse_Result, Lexer_Result) {
	lx := lexer.init(source, "test.saga")
	lexed := lexer.scan_lines(&lx)
	p := parser.init(lexed.lines[:], "test.saga")
	result := parser.parse(&p)
	for err in lexed.errors {
		append(&result.errors, err)
	}
	return result, lexed
}

@(test)
parser_parse_v0_story_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test(
		"# Main\n  `seen ?= false`\n  > `!seen` Hello there.\n  + `seen` -> `ready` [Continue](#.Next)\n## Next\n  `end(\"Done\")`\n",
	)
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	testing.expect(t, len(result.errors) == 0)
	testing.expect(t, len(result.module.scenes) == 2)
	testing.expect(t, result.module.scenes[0].path == "Main")
	testing.expect(t, result.module.scenes[1].path == "Main.Next")
	testing.expect(t, len(result.module.scenes[0].statements) == 3)

	passage := result.module.scenes[0].statements[1]
	testing.expect(t, passage.kind == .Passage)
	testing.expect(t, passage.show_if == "!seen")
	testing.expect(t, passage.text == "Hello there.")

	choice := result.module.scenes[0].statements[2]
	testing.expect(t, choice.kind == .Choice)
	testing.expect(t, choice.show_if == "seen")
	testing.expect(t, choice.enable_if == "ready")
	testing.expect(t, choice.transfer.target.scene_ref == ".Next")

}

@(test)
parser_new_choice_target_syntax_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test(
		"# Main\n+ -> [Begin](#Start)\n- `has_key` *-> `ready` [Open the door](#.Door)\n## Start\n## Door\n",
	)
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	testing.expect(t, len(result.errors) == 0)
	first := result.module.scenes[0].statements[0]
	testing.expect(t, first.kind == .Choice)
	testing.expect(t, first.text == "Begin")
	testing.expect(t, first.transfer.kind == .Normal)
	testing.expect(t, first.transfer.target.scene_ref == "Start")
	testing.expect(t, first.transfer.target.module_path == "")

	second := result.module.scenes[0].statements[1]
	testing.expect(t, second.kind == .Choice)
	testing.expect(t, second.text == "Open the door")
	testing.expect(t, second.show_if == "has_key")
	testing.expect(t, second.enable_if == "ready")
	testing.expect(t, second.choice_mode == .Fallback)
	testing.expect(t, second.transfer.kind == .Once)
	testing.expect(t, second.transfer.target.scene_ref == ".Door")
}

@(test)
parser_end_destination_syntax_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test("# Main\n- -> [The end.](end:)\n")
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	testing.expect(t, len(result.errors) == 0)
	choice := result.module.scenes[0].statements[0]
	testing.expect(t, choice.kind == .Choice)
	testing.expect(t, choice.choice_mode == .Fallback)
	testing.expect(t, choice.text == "The end.")
	testing.expect(t, choice.transfer.target.scene_ref == "end:")
}

@(test)
parser_new_module_destination_syntax_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test(
		"# Main\n+ -> [Visit the market](/market.saga#Market)\n>> [Blue Scarf](/characters.saga#BlueScarf) Hello.\n",
	)
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	testing.expect(t, len(result.errors) == 0)
	choice := result.module.scenes[0].statements[0]
	testing.expect(t, choice.text == "Visit the market")
	testing.expect(t, choice.transfer.target.scene_ref == "Market")
	testing.expect(t, choice.transfer.target.module_path == "/market.saga")

	dialogue := result.module.scenes[0].statements[1]
	testing.expect(t, dialogue.kind == .Dialogue)
	testing.expect(t, dialogue.speaker.scene_ref == "BlueScarf")
	testing.expect(t, dialogue.speaker.module_path == "/characters.saga")
	testing.expect(t, dialogue.text == "Hello.")
}

@(test)
parser_dialogue_syntax_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test(
		"# Main\n>> [Blue Scarf](/characters.saga#BlueScarf) Hello.\n>>\n>> `met` Again.\n",
	)
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	testing.expect(t, len(result.errors) == 0)
	first := result.module.scenes[0].statements[0]
	testing.expect(t, first.kind == .Dialogue)
	testing.expect(t, first.speaker.scene_ref == "BlueScarf")
	testing.expect(t, first.speaker.module_path == "/characters.saga")
	testing.expect(t, first.text == "Hello.")
	third := result.module.scenes[0].statements[2]
	testing.expect(t, third.show_if == "met")
	testing.expect(t, third.text == "Again.")
}

@(test)
parser_image_syntax_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test(
		"# Main\n![Alt text](/assets/images/test.png)\n![Quoted](\"/assets/images/quoted.png\")\n",
	)
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	testing.expect(t, len(result.errors) == 0)
	stmt := result.module.scenes[0].statements[0]
	testing.expect(t, stmt.kind == .Image)
	testing.expect(t, stmt.text == "Alt text")
	testing.expect(t, stmt.image_src == "/assets/images/test.png")

	quoted := result.module.scenes[0].statements[1]
	testing.expect(t, quoted.kind == .Image)
	testing.expect(t, quoted.text == "Quoted")
	testing.expect(t, quoted.image_src == "/assets/images/quoted.png")
}

@(test)
parser_reports_image_and_decorator_errors_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test(
		"# Main\n![Missing close](/assets/images/test.png\n@unknown value\n@widget\n> text\n",
	)
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	testing.expect(t, len(result.errors) >= 3)
}

@(test)
parser_widget_syntax_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test(
		"@widget std:inventory\n# Inventory\n+ -> [Dry cloak](#.DryCloak)\n@widget std:item\n## DryCloak\n> A cloak.\n",
	)
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	testing.expect(t, len(result.errors) == 0)
	testing.expect(t, result.module.scenes[0].widget == "std:inventory")
	testing.expect(t, result.module.scenes[1].widget == "std:item")
	testing.expect(t, result.module.scenes[0].statements[0].transfer.kind == .Normal)
}

@(test)
parser_destination_test :: proc(t: ^testing.T) {
	p := parser.init(nil)
	defer delete(p.errors)

	target, ok := parser.parse_destination(&p, "/other.saga#Scene.Child", Source_Pos{}, 2)
	testing.expect(t, ok)
	testing.expect(t, target.scene_ref == "Scene.Child")
	testing.expect(t, target.module_path == "/other.saga")

	target, ok = parser.parse_destination(&p, "#..", Source_Pos{}, 3)
	testing.expect(t, ok)
	testing.expect(t, target.scene_ref == "..")

	target, ok = parser.parse_destination(&p, "#..Sibling", Source_Pos{}, 3)
	testing.expect(t, ok)
	testing.expect(t, target.scene_ref == "..Sibling")

	parser.parse_destination(&p, "#..", Source_Pos{}, 1)
	testing.expect(t, len(p.errors) == 1)
}

@(test)
parser_parses_test_drive_examples_test :: proc(t: ^testing.T) {
	paths := [?]string {
		"examples/test_drive/main.saga",
		"examples/test_drive/market.saga",
		"examples/test_drive/ruins.saga",
		"examples/test_drive/bell.saga",
		"examples/test_drive/ending.saga",
		"examples/test_drive/characters.saga",
		"examples/test_drive/widgets/inventory.saga",
		"examples/test_drive/widgets/contacts.saga",
	}

	for path in paths {
		data, ok := os.read_entire_file(path)
		testing.expect(t, ok)
		defer delete(data)

		lx := lexer.init(string(data), path)
		lexed := lexer.scan_lines(&lx)
		p := parser.init(lexed.lines[:], path)
		result := parser.parse(&p)
		for err in lexed.errors {
			append(&result.errors, err)
		}

		testing.expect(t, len(result.errors) == 0)
		testing.expect(t, len(result.module.scenes) > 0)

		free_parse_result(result)
		delete(lexed.lines)
		delete(lexed.errors)
	}
}

@(test)
parser_reports_errors_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test(
		"> orphan\n# 1Bad\n# Main\n+ Missing arrow\n-> [Bad-Path]\n",
	)
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	testing.expect(t, len(result.errors) >= 4)
}
