package main

import "core:fmt"
import "core:strings"
import "core:testing"

html :: struct {
	generate:        proc(modules: []Module, title := "Odin Saga") -> string,
	write_statement: proc(sb: ^strings.Builder, stmt: Statement),
	write_transfer:  proc(sb: ^strings.Builder, transfer: Transfer),
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
			":root{color-scheme:dark;--bg:#111318;--panel:#1b1f2a;--text:#eceff4;--muted:#aab1c2;--accent:#8fbcbb;--disabled:#596070}body{margin:0;background:var(--bg);color:var(--text);font:18px/1.55 system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif}main{max-width:760px;margin:0 auto;padding:48px 20px}.scene{display:none;background:var(--panel);border:1px solid #2b3140;border-radius:18px;padding:28px;box-shadow:0 20px 60px #0006}.scene.active{display:block}h1{margin:0 0 20px;font-size:2rem}.passage{margin:0 0 1rem}.choices{display:grid;gap:.75rem;margin-top:1.5rem}button{appearance:none;text-align:left;border:1px solid #3a4254;border-radius:12px;background:#242a36;color:var(--text);padding:.8rem 1rem;font:inherit;cursor:pointer}button:hover:not(:disabled){border-color:var(--accent);color:var(--accent)}button:disabled{color:var(--disabled);cursor:not-allowed}.end{margin-top:1.5rem;color:var(--accent);font-weight:700}.missing{color:#ffb4ab}.meta{color:var(--muted);font-size:.9rem;margin-top:1.5rem}\n",
		)
		strings.write_string(
			&sb,
			"</style>\n</head>\n<body>\n<main id=\"app\"></main>\n<script>\n",
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

		strings.write_string(&sb, SCRIPT)
		strings.write_string(&sb, "</script>\n</body>\n</html>\n")
		return strings.to_string(sb)
	},
	write_statement = proc(sb: ^strings.Builder, stmt: Statement) {
		strings.write_string(sb, "        {kind:")
		strings.write_string(sb, html.js_string(fmt.tprintf("%v", stmt.kind)))
		strings.write_string(sb, ",text:")
		strings.write_string(sb, html.js_string(stmt.text))
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

SCRIPT :: `
const app = document.getElementById('app');
const state = Object.create(null);
const consumed = new Set();
const scenes = Object.create(null);
let current = null;
let ended = false;

function moduleId(file) {
  const slash = Math.max(file.lastIndexOf('/'), file.lastIndexOf('\\\\'));
  return '/' + file.slice(slash + 1);
}

for (const module of story.modules) {
  module.id = moduleId(module.file);
  for (const scene of module.scenes) {
    scene.module = module;
    scene.key = module.id + '#' + scene.path;
    scenes[scene.key] = scene;
  }
}

function proxyState() {
  return new Proxy(state, {
    has: (target, prop) => prop !== 'rand' && prop !== 'state',
    get: (target, prop) => prop in target ? target[prop] : 0,
    set: (target, prop, value) => { target[prop] = value; return true; }
  });
}

function rand(max) { return Math.floor(Math.random() * max); }
function normalize(code) { return code.replace(/:=/g, '='); }

function evalExpr(code) {
  if (!code) return true;
  try { return !!Function('state', 'rand', 'with (state) { return (' + normalize(code) + '); }')(proxyState(), rand); }
  catch (err) { console.warn('condition failed:', code, err); return false; }
}

function runEffect(code) {
  if (!code) return;
  const defaultMatch = code.match(/^\s*([A-Za-z_]\w*)\s*\?=\s*(.+)$/);
  if (defaultMatch) {
    if (!(defaultMatch[1] in state)) {
      state[defaultMatch[1]] = Function('state', 'rand', 'with (state) { return (' + normalize(defaultMatch[2]) + '); }')(proxyState(), rand);
    }
    return;
  }
  const endMatch = code.match(/^\s*end\((.*)\)\s*$/);
  if (endMatch) {
    ended = true;
    const message = Function('state', 'rand', 'with (state) { return (' + endMatch[1] + '); }')(proxyState(), rand);
    const div = document.createElement('div');
    div.className = 'end';
    div.textContent = message;
    app.appendChild(div);
    return;
  }
  Function('state', 'rand', 'with (state) { ' + normalize(code) + '; }')(proxyState(), rand);
}

function resolveTarget(transfer, fromScene) {
  const ref = transfer.target.sceneRef;
  const module = transfer.target.modulePath || fromScene.module.id;
  const parts = fromScene.path.split('.');
  let path = ref;
  if (ref === '.') path = fromScene.path;
  else if (ref === '..') path = parts.slice(0, -1).join('.');
  else if (ref.startsWith('..')) path = parts.slice(0, -1).concat(ref.slice(2).split('.')).join('.');
  else if (ref.startsWith('.')) path = parts.concat(ref.slice(1).split('.')).join('.');
  return scenes[module + '#' + path];
}

function go(transfer, fromScene) {
  const target = resolveTarget(transfer, fromScene);
  if (!target) {
    app.innerHTML = '<p class="missing">Missing target: ' + escapeHtml(transfer.target.sceneRef) + '</p>';
    return;
  }
  if (transfer.kind === 'once') consumed.add(fromScene.key + '->' + target.key + ':' + transfer.target.sceneRef);
  current = target;
  render();
}

function escapeHtml(text) {
  return String(text).replace(/[&<>"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[ch]));
}

function armButton(button, enabled, onClick) {
  button.disabled = true;
  if (!enabled) return;
  let armed = false;
  setTimeout(() => {
    armed = true;
    button.disabled = false;
  }, 100);
  button.addEventListener('click', () => {
    if (!armed) return;
    button.disabled = true;
    onClick();
  });
}

function render() {
  ended = false;
  app.innerHTML = '';
  const section = document.createElement('section');
  section.className = 'scene active';
  section.innerHTML = '<h1>' + escapeHtml(current.name) + '</h1>';
  app.appendChild(section);

  let choices = [];
  let pendingTransition = null;
  for (const stmt of current.statements) {
    if (ended) break;
    if (stmt.kind === 'Effect') runEffect(stmt.effect);
    else if (stmt.kind === 'Passage' && evalExpr(stmt.showIf)) {
      const p = document.createElement('p');
      p.className = 'passage';
      p.textContent = stmt.text;
      section.appendChild(p);
    } else if (stmt.kind === 'Transition' && evalExpr(stmt.takeIf)) {
      const target = resolveTarget(stmt.transfer, current);
      const key = current.key + '->' + (target ? target.key : '?') + ':' + stmt.transfer.target.sceneRef;
      if (stmt.transfer.kind !== 'once' || !consumed.has(key)) {
        pendingTransition = stmt;
        break;
      }
    } else if (stmt.kind === 'Choice' && evalExpr(stmt.showIf)) {
      const target = resolveTarget(stmt.transfer, current);
      const key = current.key + '->' + (target ? target.key : '?') + ':' + stmt.transfer.target.sceneRef;
      if (stmt.transfer.kind !== 'once' || !consumed.has(key)) choices.push(stmt);
    }
  }

  if (pendingTransition && !ended) {
    const div = document.createElement('div');
    div.className = 'choices';
    section.appendChild(div);
    const button = document.createElement('button');
    button.textContent = 'Continue';
    armButton(button, true, () => go(pendingTransition.transfer, current));
    div.appendChild(button);
  } else if (choices.length > 0 && !ended) {
    const div = document.createElement('div');
    div.className = 'choices';
    section.appendChild(div);
    for (const choice of choices) {
      const button = document.createElement('button');
      button.textContent = choice.text;
      armButton(button, evalExpr(choice.enableIf), () => go(choice.transfer, current));
      div.appendChild(button);
    }
  }

  const meta = document.createElement('div');
  meta.className = 'meta';
  meta.textContent = current.module.id + ' · ' + current.path;
  section.appendChild(meta);
}

current = story.modules[0]?.scenes[0];
if (current) render();
else app.textContent = 'No scenes found.';
`


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
	testing.expect(t, lexer.index_of(doc, "%!(MISSING") < 0)
}
