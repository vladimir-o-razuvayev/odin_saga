package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

html :: struct {
	generate:        proc(modules: []Module, title := "Odin Saga") -> string,
	write_statement: proc(sb: ^strings.Builder, stmt: Statement),
	write_transfer:  proc(sb: ^strings.Builder, transfer: Transfer),
	runtime_script:  proc() -> string,
	js_string:       proc(s: string) -> string,
	html_text:       proc(s: string) -> string,
} {
	generate = proc(modules: []Module, title := "Odin Saga") -> string {
		sb := strings.builder_make()

		strings.write_string(&sb, "<!doctype html>\n<html lang=\"en\">\n<head>\n")
		strings.write_string(
			&sb,
			"<meta charset=\"utf-8\">\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n",
		)
		strings.write_string(&sb, "<title>")
		strings.write_string(&sb, html.html_text(title))
		strings.write_string(&sb, "</title>\n<style>\n")
		strings.write_string(
			&sb,
			":root{color-scheme:dark;--bg:#111318;--panel:#1b1f2a;--dock:#151923;--text:#eceff4;--muted:#aab1c2;--accent:#8fbcbb;--disabled:#596070}body{margin:0;background:var(--bg);color:var(--text);font:18px/1.55 system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}.dock{position:fixed;inset:0 auto 0 0;width:280px;box-sizing:border-box;padding:24px 18px;background:var(--dock);border-right:1px solid #2b3140;overflow:auto}.dock-card{background:#1b1f2a;border:1px solid #2b3140;border-radius:14px;padding:14px;margin-bottom:14px}.dock h2{margin:0 0 1rem;font-size:1rem;color:var(--accent);letter-spacing:.08em;text-transform:uppercase}.dock h3{margin:1.25rem 0 .75rem;font-size:.85rem;color:var(--muted);letter-spacing:.08em;text-transform:uppercase}.dock-menu{display:grid;gap:.65rem}.dock-button{width:100%;display:block}.state-list{display:grid;gap:.55rem}.state-empty{color:var(--muted);font-size:.9rem}.state-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:.75rem;align-items:baseline;border-bottom:1px solid #252b38;padding-bottom:.45rem}.state-key{min-width:0;overflow:hidden;text-overflow:ellipsis;color:var(--muted);font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.85rem}.state-value{max-width:130px;overflow:hidden;text-overflow:ellipsis;color:var(--text);font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.85rem;text-align:right}main{max-width:760px;margin:0 auto;padding:48px 20px 48px 320px}.scene{display:none;background:var(--panel);border:1px solid #2b3140;border-radius:18px;padding:28px;box-shadow:0 20px 60px #0006}.scene.active{display:block}h1{margin:0 0 20px;font-size:2rem}.passage{margin:0 0 1rem}.choices{display:grid;gap:.75rem;margin-top:1.5rem}button{appearance:none;text-align:left;border:1px solid #3a4254;border-radius:12px;background:#242a36;color:var(--text);padding:.8rem 1rem;font:inherit;cursor:pointer}button:hover:not(:disabled){border-color:var(--accent);color:var(--accent)}button:disabled{color:var(--disabled);cursor:not-allowed}.end{margin-top:1.5rem;color:var(--accent);font-weight:700}.missing{color:#ffb4ab}.meta{color:var(--muted);font-size:.9rem;margin-top:1.5rem}.modal{position:fixed;inset:0;display:grid;place-items:center;background:#0008;padding:24px}.modal[hidden]{display:none}.modal-card{width:min(620px,100%);background:var(--panel);border:1px solid #3a4254;border-radius:18px;padding:24px;box-shadow:0 20px 80px #000}.modal-close{float:right}@media(max-width:900px){.dock{position:static;width:auto;border-right:0;border-bottom:1px solid #2b3140}main{padding:24px 16px;margin:0 auto}}\n",
		)
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
		strings.write_string(sb, ",takeIf:")
		strings.write_string(sb, html.js_string(stmt.take_if))
		strings.write_string(sb, ",effect:")
		strings.write_string(sb, html.js_string(stmt.effect))
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
		} else if transfer.kind == .Widget {
			kind = "widget"
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
		paths := [?]string{"src/runtime.js", "odin_saga/src/runtime.js"}
		for path in paths {
			data, ok := os.read_entire_file(path, context.temp_allocator)
			if ok {
				return string(data)
			}
		}
		return "throw new Error('Unable to load Saga runtime from src/runtime.js');\n"
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
	result, lexed := parse_source_for_test("# Start\n> Hello <world>\n+ Go -> [.]\n")
	defer free_parse_result(result)
	defer delete(lexed.lines)
	defer delete(lexed.errors)

	modules := [?]Module{result.module}
	doc := html.generate(modules[:])
	defer delete(doc)
	testing.expect(t, lexer.index_of(doc, "<!doctype html>") == 0)
	testing.expect(t, lexer.index_of(doc, "Hello <world>") >= 0)
	testing.expect(t, lexer.index_of(doc, "function render()") >= 0)
	testing.expect(t, lexer.index_of(doc, "%!(MISSING") < 0)
}
