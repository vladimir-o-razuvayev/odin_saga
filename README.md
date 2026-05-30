# Saga

Saga is a small interactive fiction/story-game compiler written in [Odin](https://odin-lang.org/). It takes a directory of Markdown-like `.saga` files and emits a standalone HTML story with choices, state, widgets, images, character profiles, and dialogue bubbles.

The project is approaching a v0.1 release. The current focus is a compact, author-friendly story language and a generated HTML runtime that is easy to preview locally.

## What it supports today

- Markdown-style scene headings: `# Start`, `## ChildScene`, `### NestedScene`.
- Passage text with optional conditions.
- Choices and automatic transitions.
- One-shot transfers for choices/transitions.
- Cross-module story files.
- Simple state/effect expressions.
- Root-relative image assets.
- Dock widgets such as Inventory and Contacts.
- Modal widgets for items and character profiles.
- Inline character dialogue bubbles with portraits.
- Local browser save/load slots via `localStorage`.
- Compile-time validation for targets, widgets, dialogue speakers, and image assets.

## Quick start

From the repository root:

```sh
odin run src -- examples/test_drive/main.saga examples/test_drive/out.html
```

Then open:

```text
examples/test_drive/out.html
```

The generated HTML is standalone: it embeds the compiled story data, CSS, and JavaScript runtime.

## Example story

The main sample story lives in:

```text
examples/test_drive/
```

It demonstrates:

- multi-file stories,
- inventory and contacts widgets,
- item and character modals,
- character portraits,
- dialogue bubbles,
- image assets,
- conditional choices,
- one-shot choices,
- and multiple endings.

See `examples/test_drive/README.md` for details.

## Language sketch

A tiny story can look like this:

```saga
# Start
  `visited ?= false`
  > Rain taps against the shutters.
  + Open the letter *-> [.Letter]
  + Step outside -> [Village]

## Letter
  `visited := true`
  ![Letter](/assets/images/letter.png)
  > The letter says: Find the bell before moonrise.
  -> [Village]

# Village
  > The road north disappears into rain.
  + Walk north -> [Gate]("/ruins.saga")
```

A character profile and dialogue bubble:

```saga
@widget std:character
# BlueScarf
  ![Blue scarf portrait]("/assets/images/blue_scarf.png")
  > The woman with the blue scarf.

# Market
  >> [BlueScarf]("/characters.saga") Then you are already late.
  >> Find the archivist's mark beneath the tower.
```

For the full language reference, see `docs/grammar.txt`.

## Command line

```sh
saga <entry.saga> <output.html>
```

Arguments:

- `entry.saga` — the entry story file. Its directory is treated as the story root.
- `output.html` — generated standalone HTML file.

When building from source during development, use:

```sh
odin run src -- <entry.saga> <output.html>
```

## Project layout

```text
src/                    Compiler and HTML generator
src/runtime.js           Generated story runtime, injected into HTML
src/style.css            Generated story stylesheet, injected into HTML
docs/grammar.txt         Saga language reference
docs/authoring.md        Practical guide for writing stories
docs/backlog.md          Near-term project backlog
examples/test_drive/     Full sample story
```

## Development

Run tests:

```sh
odin test src
```

Build the sample story:

```sh
odin run src -- examples/test_drive/main.saga examples/test_drive/out.html
```

If you use Nix:

```sh
nix develop
odin test src
```

## Current limitations

Saga is not yet v0.1. Notable missing pieces include:

- save import/export,
- title/authorship metadata,
- richer release packaging,
- and broader documentation/examples.

See `docs/backlog.md` for the short-term backlog.

## License and terms

Saga itself is licensed under the GNU GPLv3-or-later. See `LICENSE`.

Stories created with Saga remain owned by their authors and do not need to use the GPL. Generated HTML output may be distributed by the story author under the terms they choose, while the embedded Saga runtime/style code remains GPL-licensed.

See `TERMS.md` for the full project/story/output licensing policy.
