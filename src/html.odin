package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

read_support_file :: proc(name, fallback: string) -> string {
	paths := [?]string{fmt.tprintf("src/%s", name), fmt.tprintf("odin_saga/src/%s", name)}
	for path in paths {
		data, ok := os.read_entire_file(path, context.temp_allocator)
		if ok {
			return string(data)
		}
	}
	return fallback
}

html :: struct {
	generate:        proc(modules: []Module, title := "Saga") -> string,
	write_statement: proc(sb: ^strings.Builder, stmt: Statement),
	write_transfer:  proc(sb: ^strings.Builder, transfer: Transfer),
	runtime_script:  proc() -> string,
	stylesheet:      proc() -> string,
	js_string:       proc(s: string) -> string,
	html_text:       proc(s: string) -> string,
} {
	generate = proc(modules: []Module, title := "Saga") -> string {
		sb := strings.builder_make()

		strings.write_string(&sb, "<!doctype html>\n<html lang=\"en\">\n<head>\n")
		strings.write_string(
			&sb,
			"<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
		)
		strings.write_string(&sb, "<title>")
		strings.write_string(&sb, html.html_text(title))
		strings.write_string(&sb, "</title>\n<style>\n")
		strings.write_string(&sb, html.stylesheet())
		strings.write_string(
			&sb,
			"</style>\n</head>\n<body>\n<aside id=\"dock\" class=\"dock\"></aside>\n<main id=\"app\"></main>\n<div id=\"modal\" class=\"modal\" hidden></div>\n<script>\n",
		)
		strings.write_string(&sb, "const story = {\n  modules: [\n")

		for module, module_index in modules {
			if module_index > 0 {
				strings.write_string(&sb, ",\n")
			}
			strings.write_string(&sb, "    {file:")
			strings.write_string(&sb, html.js_string(module.file))
			strings.write_string(&sb, ", scenes:[\n")
			for scene, scene_index in module.scenes {
				if scene_index > 0 {
					strings.write_string(&sb, ",\n")
				}
				strings.write_string(&sb, "      {name:")
				strings.write_string(&sb, html.js_string(scene.name))
				strings.write_string(&sb, ",path:")
				strings.write_string(&sb, html.js_string(scene.path))
				strings.write_string(&sb, ",widget:")
				strings.write_string(&sb, html.js_string(scene.widget))
				strings.write_string(&sb, ",statements:[\n")
				for stmt, stmt_index in scene.statements {
					if stmt_index > 0 {
						strings.write_string(&sb, ",\n")
					}
					html.write_statement(&sb, stmt)
				}
				strings.write_string(&sb, "\n      ]}")
			}
			strings.write_string(&sb, "\n    ]}")
		}
		strings.write_string(&sb, "\n  ]\n};\n")

		strings.write_string(&sb, html.runtime_script())
		strings.write_string(&sb, "</script>\n</body>\n</html>\n")
		return strings.to_string(sb)
	},
	write_statement = proc(sb: ^strings.Builder, stmt: Statement) {
		strings.write_string(sb, "        {kind:")
		strings.write_string(sb, html.js_string(fmt.tprintf("%v", stmt.kind)))
		strings.write_string(sb, ",text:")
		strings.write_string(sb, html.js_string(stmt.text))
		strings.write_string(sb, ",imageSrc:")
		strings.write_string(sb, html.js_string(stmt.image_src))
		strings.write_string(sb, ",showIf:")
		strings.write_string(sb, html.js_string(stmt.show_if))
		strings.write_string(sb, ",enableIf:")
		strings.write_string(sb, html.js_string(stmt.enable_if))
		strings.write_string(sb, ",effect:")
		strings.write_string(sb, html.js_string(stmt.effect))
		choice_mode := "additive"
		if stmt.choice_mode == .Fallback {
			choice_mode = "fallback"
		}
		strings.write_string(sb, ",choiceMode:")
		strings.write_string(sb, html.js_string(choice_mode))
		strings.write_string(sb, ",transfer:")
		html.write_transfer(sb, stmt.transfer)
		strings.write_string(sb, ",speaker:")
		html.write_transfer(sb, Transfer{target = stmt.speaker})
		strings.write_string(sb, "}")
	},
	write_transfer = proc(sb: ^strings.Builder, transfer: Transfer) {
		kind := "normal"
		if transfer.kind == .Once {
			kind = "once"
		}
		strings.write_string(sb, "{kind:")
		strings.write_string(sb, html.js_string(kind))
		strings.write_string(sb, ",target:{sceneRef:")
		strings.write_string(sb, html.js_string(transfer.target.scene_ref))
		strings.write_string(sb, ",modulePath:")
		strings.write_string(sb, html.js_string(transfer.target.module_path))
		strings.write_string(sb, "}}")
	},
	runtime_script = proc() -> string {
		return read_support_file(
			"runtime.js",
			"throw new Error('Unable to load Saga runtime from src/runtime.js');\n",
		)
	},
	stylesheet = proc() -> string {
		return read_support_file(
			"style.css",
			"body{font-family:sans-serif}\n.missing{color:red}\n",
		)
	},
	js_string = proc(s: string) -> string {
		sb := strings.builder_make(context.temp_allocator)
		strings.write_byte(&sb, '"')
		for i := 0; i < len(s); i += 1 {
			ch := s[i]
			switch ch {
			case '\\':
				strings.write_string(&sb, "\\\\")
			case '"':
				strings.write_string(&sb, "\\\"")
			case '\n':
				strings.write_string(&sb, "\\n")
			case '\r':
				strings.write_string(&sb, "\\r")
			case '\t':
				strings.write_string(&sb, "\\t")
			case:
				strings.write_byte(&sb, ch)
			}
		}
		strings.write_byte(&sb, '"')
		return strings.to_string(sb)
	},
	html_text = proc(s: string) -> string {
		sb := strings.builder_make(context.temp_allocator)
		for i := 0; i < len(s); i += 1 {
			switch s[i] {
			case '&':
				strings.write_string(&sb, "&amp;")
			case '<':
				strings.write_string(&sb, "&lt;")
			case '>':
				strings.write_string(&sb, "&gt;")
			case '"':
				strings.write_string(&sb, "&quot;")
			case:
				strings.write_byte(&sb, s[i])
			}
		}
		return strings.to_string(sb)
	},
}

@(test)
html_generates_document_test :: proc(t: ^testing.T) {
	result, lexed := parse_source_for_test("# Start\n> Hello <world>\n+ -> [Go](#.)\n")
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	modules := [?]Module{result.module}
	doc := html.generate(modules[:])
	defer delete(doc)
	testing.expect(t, lexer.index_of(doc, "<!doctype html>") == 0)
	testing.expect(t, lexer.index_of(doc, "Hello <world>") >= 0)
	testing.expect(t, lexer.index_of(doc, "function render()") >= 0)
	testing.expect(t, lexer.index_of(doc, "function interpolateText") >= 0)
	testing.expect(t, lexer.index_of(doc, ".dock-card") >= 0)
	testing.expect(t, lexer.index_of(doc, "%!(MISSING") < 0)
}
