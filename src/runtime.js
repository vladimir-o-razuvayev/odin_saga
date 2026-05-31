// Saga generated story runtime
// SPDX-License-Identifier: GPL-3.0-or-later
// See the Saga TERMS.md for the story/output licensing policy.

const app = document.getElementById("app");
const dock = document.getElementById("dock");
const modal = document.getElementById("modal");
const state = Object.create(null);
const consumed = new Set();
const scenes = Object.create(null);
const activeDockWidgets = new Set();
let current = null;
let ended = false;

const saveSlotCount = 3;
const saveStoragePrefix = "saga:v0.1:" + location.pathname + ":";

const storyRoot =
  story.modules[0]?.file.slice(
    0,
    Math.max(
      story.modules[0]?.file.lastIndexOf("/") ?? 0,
      story.modules[0]?.file.lastIndexOf("\\") ?? 0,
    ),
  ) ?? "";

function moduleId(file) {
  if (storyRoot && file.startsWith(storyRoot))
    return file.slice(storyRoot.length);
  const slash = Math.max(file.lastIndexOf("/"), file.lastIndexOf("\\"));
  return "/" + file.slice(slash + 1);
}

for (const module of story.modules) {
  module.id = moduleId(module.file);
  for (const scene of module.scenes) {
    scene.module = module;
    scene.key = module.id + "#" + scene.path;
    scenes[scene.key] = scene;
  }
}

function initializeDockWidgets() {
  for (const module of story.modules) {
    for (const scene of module.scenes) {
      if (scene.widget === "std:contacts") activeDockWidgets.add(scene.key);
    }
  }
}

function isRuntimeGlobal(prop) {
  return [
    "Array",
    "Boolean",
    "Date",
    "JSON",
    "Math",
    "Number",
    "Object",
    "String",
    "console",
    "prompt",
    "rand",
    "state",
  ].includes(prop);
}

function proxyState() {
  return new Proxy(state, {
    has: (_target, prop) => !isRuntimeGlobal(prop),
    get: (target, prop) => (prop in target ? target[prop] : 0),
    set: (target, prop, value) => {
      target[prop] = value;
      return true;
    },
  });
}

function rand(max) {
  return Math.floor(Math.random() * max);
}
function normalize(code) {
  return code.replace(/:=/g, "=");
}

function evalExpr(code) {
  if (!code) return true;
  try {
    return !!Function(
      "state",
      "rand",
      "with (state) { return (" + normalize(code) + "); }",
    )(proxyState(), rand);
  } catch (err) {
    console.warn("condition failed:", code, err);
    return false;
  }
}

function evalValue(code) {
  return Function(
    "state",
    "rand",
    "with (state) { return (" + normalize(code) + "); }",
  )(proxyState(), rand);
}

function interpolateText(text) {
  return String(text).replace(/#\{([^}]*)\}/g, (_match, code) => {
    try {
      const value = evalValue(code);
      return value == null ? "" : String(value);
    } catch (err) {
      console.warn("interpolation failed:", code, err);
      return "";
    }
  });
}

function runEffect(code) {
  if (!code) return;
  const activateMatch = code.match(/^\s*activate\((.*)\)\s*$/);
  if (activateMatch) {
    try {
      activate(evalValue(activateMatch[1]));
    } catch (err) {
      console.warn("activate failed:", code, err);
    }
    return;
  }
  const defaultMatch = code.match(/^\s*([A-Za-z_]\w*)\s*\?=\s*(.+)$/);
  if (defaultMatch) {
    if (!(defaultMatch[1] in state)) {
      state[defaultMatch[1]] = Function(
        "state",
        "rand",
        "with (state) { return (" + normalize(defaultMatch[2]) + "); }",
      )(proxyState(), rand);
    }
    return;
  }
  const endMatch = code.match(/^\s*end\((.*)\)\s*$/);
  if (endMatch) {
    const message = Function(
      "state",
      "rand",
      "with (state) { return (" + endMatch[1] + "); }",
    )(proxyState(), rand);
    endStory(message, false);
    return;
  }
  Function(
    "state",
    "rand",
    "with (state) { " + normalize(code) + "; }",
  )(proxyState(), rand);
}

function endStory(message, replace = true) {
  ended = true;
  if (replace) app.innerHTML = "";
  const div = document.createElement("div");
  div.className = "end";
  div.textContent = message;
  app.appendChild(div);
  renderDock();
}

function targetFromDestination(destination) {
  if (typeof destination !== "string") return null;
  destination = destination.trim();
  if (destination.startsWith("#")) {
    return { sceneRef: destination.slice(1), modulePath: "" };
  }
  if (destination.startsWith("/")) {
    const hash = destination.indexOf("#");
    if (hash < 0) return null;
    return {
      modulePath: destination.slice(0, hash),
      sceneRef: destination.slice(hash + 1),
    };
  }
  return null;
}

function resolveTargetRef(target, fromScene) {
  const ref = target.sceneRef;
  const module = target.modulePath || fromScene.module.id;
  const parts = fromScene.path.split(".");
  let path = ref;
  if (ref === ".") path = fromScene.path;
  else if (ref === "..") path = parts.slice(0, -1).join(".");
  else if (ref.startsWith(".."))
    path = parts.slice(0, -1).concat(ref.slice(2).split(".")).join(".");
  else if (ref.startsWith("."))
    path = parts.concat(ref.slice(1).split(".")).join(".");
  return scenes[module + "#" + path];
}

function isEndTransfer(transfer) {
  return transfer?.target?.sceneRef === "end:";
}

function resolveTarget(transfer, fromScene) {
  if (isEndTransfer(transfer)) return null;
  return resolveTargetRef(transfer.target, fromScene);
}

function activate(destination) {
  const targetRef = targetFromDestination(destination);
  const target =
    targetRef && current ? resolveTargetRef(targetRef, current) : null;
  if (!target) {
    console.warn("activate target not found:", destination);
    return;
  }
  if (!isWidgetScene(target)) {
    console.warn("activate target is not a widget:", destination);
    return;
  }
  runWidget(target);
}

function transferKey(transfer, fromScene, target) {
  const targetKey = isEndTransfer(transfer)
    ? "end:"
    : target
      ? target.key
      : "?";
  return fromScene.key + "->" + targetKey + ":" + transfer.target.sceneRef;
}

function isWidgetScene(scene) {
  return !!scene?.widget;
}

function go(transfer, fromScene, label = "") {
  if (isEndTransfer(transfer)) {
    if (transfer.kind === "once")
      consumed.add(transferKey(transfer, fromScene, null));
    endStory(interpolateText(label));
    return;
  }
  const target = resolveTarget(transfer, fromScene);
  if (!target) {
    app.innerHTML =
      '<p class="missing">Missing target: ' +
      escapeHtml(transfer.target.sceneRef) +
      "</p>";
    return;
  }
  if (transfer.kind === "once")
    consumed.add(transferKey(transfer, fromScene, target));
  if (isWidgetScene(target)) {
    runWidget(target);
    return;
  }
  current = target;
  render();
}

function runWidget(scene) {
  if (
    scene.widget === "std:inventory" ||
    scene.widget === "std:contacts" ||
    scene.widget === "std:status"
  ) {
    activeDockWidgets.add(scene.key);
    renderDock();
  } else if (scene.widget === "std:item" || scene.widget === "std:character") {
    openItemModal(scene);
  }
}

function closeModal() {
  modal.hidden = true;
  modal.innerHTML = "";
}

modal.addEventListener("click", (event) => {
  if (event.target === modal) closeModal();
});

function addModalCloseButton(card) {
  const close = document.createElement("button");
  close.className = "modal-close";
  close.textContent = "×";
  close.style.float = "right";
  close.style.border = "0";
  close.style.background = "transparent";
  close.style.padding = "0 .25rem";
  close.style.fontSize = "1.8rem";
  close.style.lineHeight = "1";
  close.style.color = "var(--muted)";
  close.setAttribute("aria-label", "Close");
  close.addEventListener("click", closeModal);
  card.appendChild(close);
}

function openItemModal(scene) {
  modal.hidden = false;
  modal.innerHTML = "";
  const card = document.createElement("section");
  card.className = "modal-card";
  addModalCloseButton(card);
  renderWidgetScene(scene, card, "modal");
  modal.appendChild(card);
}

function escapeHtml(text) {
  return String(text).replace(
    /[&<>"]/g,
    (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[ch],
  );
}

function formatStateValue(value) {
  if (typeof value === "string") return JSON.stringify(value);
  return String(value);
}

function renderStateList(container) {
  const keys = Object.keys(state).sort();
  container.innerHTML = "";
  if (keys.length === 0) {
    const empty = document.createElement("div");
    empty.className = "state-empty";
    empty.textContent = "No variables assigned yet.";
    container.appendChild(empty);
    return;
  }
  for (const key of keys) {
    const row = document.createElement("div");
    row.className = "state-row";
    const name = document.createElement("div");
    name.className = "state-key";
    name.title = key;
    name.textContent = key;
    const value = document.createElement("div");
    value.className = "state-value";
    value.title = formatStateValue(state[key]);
    value.textContent = formatStateValue(state[key]);
    row.appendChild(name);
    row.appendChild(value);
    container.appendChild(row);
  }
}

function saveStorageKey(slot) {
  return saveStoragePrefix + "slot:" + slot;
}

function createSaveData() {
  return {
    version: 1,
    savedAt: new Date().toISOString(),
    current: current?.key ?? null,
    state: { ...state },
    consumed: Array.from(consumed),
    activeDockWidgets: Array.from(activeDockWidgets),
  };
}

function readSaveSlot(slot) {
  try {
    const text = localStorage.getItem(saveStorageKey(slot));
    return text ? JSON.parse(text) : null;
  } catch (err) {
    console.warn("save slot read failed:", slot, err);
    return null;
  }
}

function saveSlot(slot) {
  try {
    localStorage.setItem(
      saveStorageKey(slot),
      JSON.stringify(createSaveData()),
    );
    openSaveModal();
  } catch (err) {
    console.warn("save failed:", err);
    alert("Save failed. Your browser may be blocking localStorage.");
  }
}

function restoreState(savedState) {
  for (const key of Object.keys(state)) delete state[key];
  if (!savedState || typeof savedState !== "object") return;
  for (const [key, value] of Object.entries(savedState)) state[key] = value;
}

function restoreStringSet(set, values, knownScenesOnly) {
  set.clear();
  if (!Array.isArray(values)) return;
  for (const value of values) {
    if (typeof value !== "string") continue;
    if (knownScenesOnly && !scenes[value]) continue;
    set.add(value);
  }
}

function loadSlot(slot) {
  const data = readSaveSlot(slot);
  if (!data) return;
  const scene = scenes[data.current];
  if (!scene) {
    alert("This save points to a scene that no longer exists.");
    return;
  }
  current = scene;
  ended = false;
  restoreState(data.state);
  restoreStringSet(consumed, data.consumed, false);
  restoreStringSet(activeDockWidgets, data.activeDockWidgets, true);
  closeModal();
  render();
}

function formatSaveTime(value) {
  if (!value) return "Empty slot";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Saved";
  return "Saved " + date.toLocaleString();
}

function renderSettingsCard() {
  const card = document.createElement("section");
  card.className = "dock-card";
  card.innerHTML = "<h2>Settings</h2>";

  const actions = document.createElement("div");
  actions.className = "settings-actions";

  const saves = document.createElement("button");
  saves.className = "link-button";
  saves.textContent = "Saves";
  armButton(saves, true, openSaveModal);
  actions.appendChild(saves);

  const debug = document.createElement("button");
  debug.className = "link-button";
  debug.textContent = "Debug";
  armButton(debug, true, openDebugModal);
  actions.appendChild(debug);

  card.appendChild(actions);
  dock.appendChild(card);
}

function openSaveModal() {
  modal.hidden = false;
  modal.innerHTML = "";
  const card = document.createElement("section");
  card.className = "modal-card";
  addModalCloseButton(card);

  const title = document.createElement("h1");
  title.textContent = "Settings";
  card.appendChild(title);

  const list = document.createElement("div");
  list.className = "save-slots";
  card.appendChild(list);

  for (let slot = 1; slot <= saveSlotCount; slot += 1) {
    const data = readSaveSlot(slot);
    const row = document.createElement("div");
    row.className = "save-slot";

    const info = document.createElement("div");
    const name = document.createElement("div");
    name.className = "save-slot-title";
    name.textContent = "Slot " + slot;
    info.appendChild(name);

    const meta = document.createElement("div");
    meta.className = "save-slot-meta";
    meta.textContent = data
      ? formatSaveTime(data.savedAt) +
        (data.current ? " · " + data.current : "")
      : "Empty slot";
    info.appendChild(meta);
    row.appendChild(info);

    const actions = document.createElement("div");
    actions.className = "save-slot-actions";

    const save = document.createElement("button");
    save.textContent = "Save";
    armButton(save, true, () => saveSlot(slot));
    actions.appendChild(save);

    const load = document.createElement("button");
    load.textContent = "Load";
    armButton(load, !!data, () => loadSlot(slot));
    actions.appendChild(load);

    row.appendChild(actions);
    list.appendChild(row);
  }

  modal.appendChild(card);
}

function openDebugModal() {
  modal.hidden = false;
  modal.innerHTML = "";
  const card = document.createElement("section");
  card.className = "modal-card";
  addModalCloseButton(card);
  const title = document.createElement("h1");
  title.textContent = "Debug";
  card.appendChild(title);
  const stateList = document.createElement("div");
  stateList.className = "state-list";
  renderStateList(stateList);
  card.appendChild(stateList);
  modal.appendChild(card);
}

function renderDock() {
  dock.innerHTML = "";
  renderSettingsCard();
  for (const key of activeDockWidgets) {
    const scene = scenes[key];
    if (!scene) continue;
    const card = document.createElement("section");
    card.className = "dock-card";
    if (
      scene.widget === "std:inventory" ||
      scene.widget === "std:contacts" ||
      scene.widget === "std:status"
    ) {
      renderWidgetScene(scene, card, "dock");
    }
    dock.appendChild(card);
  }
}

function resolveAssetPath(path) {
  if (!path.startsWith("/")) return path;
  const currentPath = window.location.pathname;
  const base = currentPath.slice(0, currentPath.lastIndexOf("/"));
  return base + path;
}

function renderImage(container, stmt) {
  const figure = document.createElement("figure");
  figure.className = "image-block";
  const img = document.createElement("img");
  img.src = resolveAssetPath(stmt.imageSrc);
  img.alt = interpolateText(stmt.text);
  img.className = "story-image";
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
  button.addEventListener("click", () => {
    if (!armed) return;
    armed = false;
    button.disabled = true;
    onClick();
    setTimeout(rearm, 100);
  });
}

function characterImage(scene) {
  for (const stmt of scene.statements) {
    if (stmt.kind === "Image") return stmt;
  }
  return null;
}

function renderDialogueBlock(statements, start, container, fromScene) {
  const first = statements[start];
  const speaker = resolveTarget(first.speaker, fromScene);
  const bubble = document.createElement("div");
  bubble.className = "speech-bubble";
  bubble.style.display = "grid";
  bubble.style.gridTemplateColumns = "48px 1fr";
  bubble.style.gap = ".75rem";
  bubble.style.alignItems = "start";
  bubble.style.background = "#202634";
  bubble.style.border = "1px solid #343c4f";
  bubble.style.borderRadius = "14px";
  bubble.style.padding = ".85rem";
  bubble.style.margin = "1rem 0";

  const avatarSlot = document.createElement("div");
  const image = speaker ? characterImage(speaker) : null;
  if (image) {
    const img = document.createElement("img");
    img.src = resolveAssetPath(image.imageSrc);
    img.alt = image.text;
    img.className = "avatar-image";
    avatarSlot.appendChild(img);
  } else {
    avatarSlot.textContent = speaker ? speaker.name.slice(0, 1) : "?";
    avatarSlot.style.width = "48px";
    avatarSlot.style.height = "48px";
    avatarSlot.style.borderRadius = "50%";
    avatarSlot.style.display = "grid";
    avatarSlot.style.placeItems = "center";
    avatarSlot.style.background = "#2a3142";
    avatarSlot.style.color = "var(--accent)";
    avatarSlot.style.fontWeight = "700";
  }
  bubble.appendChild(avatarSlot);

  const body = document.createElement("div");
  const name = document.createElement("div");
  name.textContent = speaker ? speaker.name : "Unknown";
  name.style.color = "var(--accent)";
  name.style.fontWeight = "700";
  name.style.marginBottom = ".35rem";
  body.appendChild(name);

  let i = start;
  let paragraph = null;
  let hasVisibleText = false;
  while (i < statements.length) {
    const stmt = statements[i];
    if (stmt.kind !== "Dialogue") break;
    if (i !== start && stmt.speaker.target.sceneRef) break;
    if (evalExpr(stmt.showIf)) {
      if (stmt.text === "") {
        paragraph = null;
      } else {
        hasVisibleText = true;
        if (paragraph == null) {
          paragraph = document.createElement("p");
          paragraph.className = "passage";
          body.appendChild(paragraph);
        } else {
          paragraph.appendChild(document.createTextNode(" "));
        }
        paragraph.appendChild(
          document.createTextNode(interpolateText(stmt.text)),
        );
      }
    }
    i += 1;
  }

  if (hasVisibleText) {
    bubble.appendChild(body);
    container.appendChild(bubble);
  }
  return i;
}

function isChoiceVisible(choice, fromScene) {
  if (!evalExpr(choice.showIf)) return false;
  const target = resolveTarget(choice.transfer, fromScene);
  const key = transferKey(choice.transfer, fromScene, target);
  return choice.transfer.kind !== "once" || !consumed.has(key);
}

function collectVisibleChoices(statements, fromScene) {
  const choices = [];
  let fallbackChosen = false;
  for (const stmt of statements) {
    if (stmt.kind !== "Choice" || !isChoiceVisible(stmt, fromScene)) continue;
    if (stmt.choiceMode === "fallback") {
      if (fallbackChosen) continue;
      fallbackChosen = true;
    }
    choices.push(stmt);
  }
  return choices;
}

function renderWidgetScene(scene, container, surface) {
  const title = document.createElement(surface === "dock" ? "h2" : "h1");
  title.textContent = scene.name;
  container.appendChild(title);
  for (let index = 0; index < scene.statements.length; ) {
    const stmt = scene.statements[index];
    if (stmt.kind === "Dialogue") {
      index = renderDialogueBlock(scene.statements, index, container, scene);
      continue;
    }
    if (stmt.kind === "Effect") runEffect(stmt.effect);
    else if (stmt.kind === "Passage" && evalExpr(stmt.showIf)) {
      const p = document.createElement("p");
      p.className = "passage";
      p.textContent = interpolateText(stmt.text);
      container.appendChild(p);
    } else if (stmt.kind === "Image") {
      renderImage(container, stmt);
    }
    index += 1;
  }
  const choices = collectVisibleChoices(scene.statements, scene);
  if (choices.length > 0) {
    const div = document.createElement("div");
    div.className = surface === "dock" ? "state-list" : "choices";
    container.appendChild(div);
    for (const choice of choices) {
      const button = document.createElement("button");
      button.textContent = interpolateText(choice.text);
      if (surface === "dock") {
        button.className = "state-row";
        button.style.width = "100%";
        button.style.background = "transparent";
        button.style.border = "0";
        button.style.borderBottom = "1px solid #252b38";
        button.style.borderRadius = "0";
        button.style.padding = ".45rem 0";
        button.style.color = "var(--muted)";
      }
      armButton(button, evalExpr(choice.enableIf), () =>
        go(choice.transfer, scene, choice.text),
      );
      div.appendChild(button);
    }
  }
}

function render() {
  ended = false;
  app.innerHTML = "";
  const section = document.createElement("section");
  section.className = "scene active";
  section.innerHTML = "<h1>" + escapeHtml(current.name) + "</h1>";
  app.appendChild(section);

  for (let index = 0; index < current.statements.length; ) {
    const stmt = current.statements[index];
    if (ended) break;
    if (stmt.kind === "Dialogue") {
      index = renderDialogueBlock(current.statements, index, section, current);
      continue;
    }
    if (stmt.kind === "Effect") runEffect(stmt.effect);
    else if (stmt.kind === "Passage" && evalExpr(stmt.showIf)) {
      const p = document.createElement("p");
      p.className = "passage";
      p.textContent = interpolateText(stmt.text);
      section.appendChild(p);
    } else if (stmt.kind === "Image") {
      renderImage(section, stmt);
    }
    index += 1;
  }

  const choices = collectVisibleChoices(current.statements, current);
  if (choices.length > 0 && !ended) {
    const div = document.createElement("div");
    div.className = "choices";
    section.appendChild(div);
    for (const choice of choices) {
      const button = document.createElement("button");
      button.textContent = interpolateText(choice.text);
      armButton(button, evalExpr(choice.enableIf), () =>
        go(choice.transfer, current, choice.text),
      );
      div.appendChild(button);
    }
  }

  const meta = document.createElement("div");
  meta.className = "meta";
  meta.textContent = current.module.id + " · " + current.path;
  section.appendChild(meta);
  renderDock();
}

initializeDockWidgets();
current = story.modules[0]?.scenes[0];
if (current) render();
else {
  app.textContent = "No scenes found.";
  renderDock();
}
