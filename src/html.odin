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

		strings.write_string(&sb, SCRIPT)
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
const dock = document.getElementById('dock');
const modal = document.getElementById('modal');
const state = Object.create(null);
const consumed = new Set();
const scenes = Object.create(null);
const activeDockWidgets = new Set();
let current = null;
let ended = false;

const storyRoot = story.modules[0]?.file.slice(0, Math.max(story.modules[0]?.file.lastIndexOf('/') ?? 0, story.modules[0]?.file.lastIndexOf('\\\\') ?? 0)) ?? '';

function moduleId(file) {
  if (storyRoot && file.startsWith(storyRoot)) return file.slice(storyRoot.length);
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
  if (transfer.kind === 'widget') {
    runWidget(target);
    return;
  }
  if (transfer.kind === 'once') consumed.add(fromScene.key + '->' + target.key + ':' + transfer.target.sceneRef);
  current = target;
  render();
}

function runWidget(scene) {
  if (scene.widget === 'std:inventory' || scene.widget === 'std:status') {
    activeDockWidgets.add(scene.key);
    renderDock();
  } else if (scene.widget === 'std:item' || scene.widget === 'std:character') {
    openItemModal(scene);
  }
}

function closeModal() {
  modal.hidden = true;
  modal.innerHTML = '';
}

modal.addEventListener('click', event => {
  if (event.target === modal) closeModal();
});

function addModalCloseButton(card) {
  const close = document.createElement('button');
  close.className = 'modal-close';
  close.textContent = '×';
  close.style.float = 'right';
  close.style.border = '0';
  close.style.background = 'transparent';
  close.style.padding = '0 .25rem';
  close.style.fontSize = '1.8rem';
  close.style.lineHeight = '1';
  close.style.color = 'var(--muted)';
  close.setAttribute('aria-label', 'Close');
  close.addEventListener('click', closeModal);
  card.appendChild(close);
}

function openItemModal(scene) {
  modal.hidden = false;
  modal.innerHTML = '';
  const card = document.createElement('section');
  card.className = 'modal-card';
  addModalCloseButton(card);
  renderWidgetScene(scene, card, 'modal');
  modal.appendChild(card);
}

function escapeHtml(text) {
  return String(text).replace(/[&<>"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[ch]));
}

function formatStateValue(value) {
  if (typeof value === 'string') return JSON.stringify(value);
  return String(value);
}

function renderStateList(container) {
  const keys = Object.keys(state).sort();
  container.innerHTML = '';
  if (keys.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'state-empty';
    empty.textContent = 'No variables assigned yet.';
    container.appendChild(empty);
    return;
  }
  for (const key of keys) {
    const row = document.createElement('div');
    row.className = 'state-row';
    const name = document.createElement('div');
    name.className = 'state-key';
    name.title = key;
    name.textContent = key;
    const value = document.createElement('div');
    value.className = 'state-value';
    value.title = formatStateValue(state[key]);
    value.textContent = formatStateValue(state[key]);
    row.appendChild(name);
    row.appendChild(value);
    container.appendChild(row);
  }
}

function renderSettingsCard() {
  const card = document.createElement('section');
  card.className = 'dock-card';
  card.innerHTML = '<h2>Settings</h2>';
  const button = document.createElement('button');
  button.textContent = 'Debug';
  button.style.border = '0';
  button.style.background = 'transparent';
  button.style.padding = '0';
  button.style.color = 'var(--muted)';
  button.style.textDecoration = 'underline';
  button.style.textUnderlineOffset = '.2em';
  armButton(button, true, openDebugModal);
  card.appendChild(button);
  dock.appendChild(card);
}

function openDebugModal() {
  modal.hidden = false;
  modal.innerHTML = '';
  const card = document.createElement('section');
  card.className = 'modal-card';
  addModalCloseButton(card);
  const title = document.createElement('h1');
  title.textContent = 'Debug';
  card.appendChild(title);
  const stateList = document.createElement('div');
  stateList.className = 'state-list';
  renderStateList(stateList);
  card.appendChild(stateList);
  modal.appendChild(card);
}

function renderDock() {
  dock.innerHTML = '';
  renderSettingsCard();
  for (const key of activeDockWidgets) {
    const scene = scenes[key];
    if (!scene) continue;
    const card = document.createElement('section');
    card.className = 'dock-card';
    if (scene.widget === 'std:inventory' || scene.widget === 'std:status') {
      renderWidgetScene(scene, card, 'dock');
    }
    dock.appendChild(card);
  }
}

function resolveAssetPath(path) {
  if (!path.startsWith('/')) return path;
  const currentPath = window.location.pathname;
  const base = currentPath.slice(0, currentPath.lastIndexOf('/'));
  return base + path;
}

function renderImage(container, stmt) {
  const figure = document.createElement('figure');
  figure.className = 'image-block';
  const img = document.createElement('img');
  img.src = resolveAssetPath(stmt.imageSrc);
  img.alt = stmt.text;
  img.style.display = 'block';
  img.style.maxWidth = '100%';
  img.style.maxHeight = '360px';
  img.style.width = 'auto';
  img.style.height = 'auto';
  img.style.margin = '0 auto';
  img.style.objectFit = 'contain';
  figure.style.margin = '1rem 0';
  figure.style.overflow = 'hidden';
  figure.appendChild(img);
  container.appendChild(figure);
}

function armButton(button, enabled, onClick) {
  button.disabled = true;
  if (!enabled) return;
  let armed = false;
  const rearm = () => {
    if (!button.isConnected) return;
    armed = true;
    button.disabled = false;
  };
  setTimeout(rearm, 100);
  button.addEventListener('click', () => {
    if (!armed) return;
    armed = false;
    button.disabled = true;
    onClick();
    setTimeout(rearm, 100);
  });
}

function characterImage(scene) {
  for (const stmt of scene.statements) {
    if (stmt.kind === 'Image') return stmt;
  }
  return null;
}

function renderDialogueBlock(statements, start, container, fromScene) {
  const first = statements[start];
  const speaker = resolveTarget(first.speaker, fromScene);
  const bubble = document.createElement('div');
  bubble.className = 'speech-bubble';
  bubble.style.display = 'grid';
  bubble.style.gridTemplateColumns = '48px 1fr';
  bubble.style.gap = '.75rem';
  bubble.style.alignItems = 'start';
  bubble.style.background = '#202634';
  bubble.style.border = '1px solid #343c4f';
  bubble.style.borderRadius = '14px';
  bubble.style.padding = '.85rem';
  bubble.style.margin = '1rem 0';

  const avatarSlot = document.createElement('div');
  const image = speaker ? characterImage(speaker) : null;
  if (image) {
    const img = document.createElement('img');
    img.src = resolveAssetPath(image.imageSrc);
    img.alt = image.text;
    img.style.width = '48px';
    img.style.height = '48px';
    img.style.borderRadius = '50%';
    img.style.objectFit = 'cover';
    avatarSlot.appendChild(img);
  } else {
    avatarSlot.textContent = speaker ? speaker.name.slice(0, 1) : '?';
    avatarSlot.style.width = '48px';
    avatarSlot.style.height = '48px';
    avatarSlot.style.borderRadius = '50%';
    avatarSlot.style.display = 'grid';
    avatarSlot.style.placeItems = 'center';
    avatarSlot.style.background = '#2a3142';
    avatarSlot.style.color = 'var(--accent)';
    avatarSlot.style.fontWeight = '700';
  }
  bubble.appendChild(avatarSlot);

  const body = document.createElement('div');
  const name = document.createElement('div');
  name.textContent = speaker ? speaker.name : 'Unknown';
  name.style.color = 'var(--accent)';
  name.style.fontWeight = '700';
  name.style.marginBottom = '.35rem';
  body.appendChild(name);

  let i = start;
  let paragraph = null;
  while (i < statements.length) {
    const stmt = statements[i];
    if (stmt.kind !== 'Dialogue') break;
    if (i !== start && stmt.speaker.target.sceneRef) break;
    if (evalExpr(stmt.showIf)) {
      if (stmt.text === '') {
        paragraph = null;
      } else {
        if (paragraph == null) {
          paragraph = document.createElement('p');
          paragraph.className = 'passage';
          body.appendChild(paragraph);
        } else {
          paragraph.appendChild(document.createTextNode(' '));
        }
        paragraph.appendChild(document.createTextNode(stmt.text));
      }
    }
    i += 1;
  }

  bubble.appendChild(body);
  container.appendChild(bubble);
  return i;
}

function renderWidgetScene(scene, container, surface) {
  const title = document.createElement(surface === 'dock' ? 'h2' : 'h1');
  title.textContent = scene.name;
  container.appendChild(title);
  const choices = [];
  for (let index = 0; index < scene.statements.length;) {
    const stmt = scene.statements[index];
    if (stmt.kind === 'Dialogue') {
      index = renderDialogueBlock(scene.statements, index, container, scene);
      continue;
    }
    if (stmt.kind === 'Effect') runEffect(stmt.effect);
    else if (stmt.kind === 'Passage' && evalExpr(stmt.showIf)) {
      const p = document.createElement('p');
      p.className = 'passage';
      p.textContent = stmt.text;
      container.appendChild(p);
    } else if (stmt.kind === 'Image') {
      renderImage(container, stmt);
    } else if (stmt.kind === 'Transition' && evalExpr(stmt.takeIf)) {
      go(stmt.transfer, scene);
    } else if (stmt.kind === 'Choice' && evalExpr(stmt.showIf)) {
      choices.push(stmt);
    }
    index += 1;
  }
  if (choices.length > 0) {
    const div = document.createElement('div');
    div.className = surface === 'dock' ? 'state-list' : 'choices';
    container.appendChild(div);
    for (const choice of choices) {
      const button = document.createElement('button');
      button.textContent = choice.text;
      if (surface === 'dock') {
        button.className = 'state-row';
        button.style.width = '100%';
        button.style.background = 'transparent';
        button.style.border = '0';
        button.style.borderBottom = '1px solid #252b38';
        button.style.borderRadius = '0';
        button.style.padding = '.45rem 0';
        button.style.color = 'var(--muted)';
      }
      armButton(button, evalExpr(choice.enableIf), () => go(choice.transfer, scene));
      div.appendChild(button);
    }
  }
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
  for (let index = 0; index < current.statements.length;) {
    const stmt = current.statements[index];
    if (ended) break;
    if (stmt.kind === 'Dialogue') {
      index = renderDialogueBlock(current.statements, index, section, current);
      continue;
    }
    if (stmt.kind === 'Effect') runEffect(stmt.effect);
    else if (stmt.kind === 'Passage' && evalExpr(stmt.showIf)) {
      const p = document.createElement('p');
      p.className = 'passage';
      p.textContent = stmt.text;
      section.appendChild(p);
    } else if (stmt.kind === 'Image') {
      renderImage(section, stmt);
    } else if (stmt.kind === 'Transition' && evalExpr(stmt.takeIf)) {
      const target = resolveTarget(stmt.transfer, current);
      const key = current.key + '->' + (target ? target.key : '?') + ':' + stmt.transfer.target.sceneRef;
      if (stmt.transfer.kind === 'widget') {
        if (target) runWidget(target);
      } else if (stmt.transfer.kind !== 'once' || !consumed.has(key)) {
        pendingTransition = stmt;
        break;
      }
    } else if (stmt.kind === 'Choice' && evalExpr(stmt.showIf)) {
      const target = resolveTarget(stmt.transfer, current);
      const key = current.key + '->' + (target ? target.key : '?') + ':' + stmt.transfer.target.sceneRef;
      if (stmt.transfer.kind !== 'once' || !consumed.has(key)) choices.push(stmt);
    }
    index += 1;
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
  renderDock();
}

current = story.modules[0]?.scenes[0];
if (current) render();
else {
  app.textContent = 'No scenes found.';
  renderDock();
}
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
