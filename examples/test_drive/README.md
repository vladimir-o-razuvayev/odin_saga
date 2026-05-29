# Test Drive Saga

A multi-module sample story for exercising the current Saga grammar.

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
- `ending.saga` — two ending paths and restart links.

## Grammar features exercised

- Markdown scene headings with nested scene paths.
- Passage lines with `>`.
- Choice lines with `+`.
- Choice visibility conditions after `+`.
- Choice enable conditions after `->`.
- Automatic transitions with `->`.
- One-shot transfers with `*->` for both choices and transitions.
- Child targets with `[.Child]`.
- Sibling targets with `[..Sibling]`.
- Absolute in-module targets like `[Village.GateWatch]`.
- Cross-module targets like `[Square]("/market.saga")`.
- Persistent initialize-if-nil with `?=`.
- Persistent assignment with `:=`.
- Scene-local bindings with `=`.
- Increment with `++`.
- Comments outside backtick expressions.
