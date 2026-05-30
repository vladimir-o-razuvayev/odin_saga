# Test Drive Saga

A polished multi-module sample story for exercising the current Saga grammar and generated HTML runtime.

## Entry point

Start at:

```text
main.saga#Start
```

The story root is this directory. Root-relative module targets such as `("/market.saga")` resolve within `examples/test_drive`.

## Modules

- `main.saga` — opening inn, village hub, gate watch, road to the ruins.
- `market.saga` — market square, cloak seller, blue scarf contact, alley, locksmith.
- `ruins.saga` — watchtower gate, courtyard, well, archive, lower door.
- `bell.saga` — bell chamber, pool, restored bell outcomes.
- `ending.saga` — two ending paths.
- `characters.saga` — character profile widgets and portrait sources.
- `widgets/inventory.saga` — inventory dock widget and item modals.
- `widgets/contacts.saga` — contacts dock widget and character profile links.
- `assets/images/` — story images, item art, and character portraits.

## Grammar features exercised

- Markdown scene headings with nested scene paths.
- Passage lines with `>`.
- Choice lines with `+`.
- Choice visibility conditions after `+`.
- Choice enable conditions after `->`.
- Automatic transitions with `->`.
- One-shot transfers with `*->` for both choices and transitions.
- Child targets with `[.Child]`.
- Parent targets with `[..]`.
- Sibling targets with `[..Sibling]`.
- Absolute in-module targets like `[Village.GateWatch]`.
- Cross-module targets like `[Visit the market](/market.saga#Square)`.
- Persistent initialize-if-nil with `?=`.
- Persistent assignment with `:=`.
- Scene-local bindings with `=`.
- Increment with `++`.
- Comments outside backtick expressions.
- Markdown-style image statements.
- `@widget` scenes for inventory, contacts, items, and characters.
- `w->` widget transfers.
- Dialogue bubbles with `>>`.

## Build

From the repository root:

```sh
odin run src -- examples/test_drive/main.saga examples/test_drive/out.html
```

Open `examples/test_drive/out.html` in a browser.
