# Authoring Saga Stories

This guide explains the practical workflow for writing stories with Saga. For exact grammar rules, see `docs/grammar.txt`.

## Compile a story

A story starts from one `.saga` entry file:

```sh
odin run src -- examples/test_drive/main.saga examples/test_drive/out.html
```

The entry file's directory becomes the story root. Other `.saga` files under that directory are loaded automatically.

Root-relative module paths are resolved from the story root:

```saga
+ Visit the market -> [Square]("/market.saga")
```

Root-relative image paths are also resolved from the story root:

```saga
![Blue scarf portrait]("/assets/images/blue_scarf.png")
```

## File organization

A useful pattern is:

```text
my_story/
  main.saga
  characters.saga
  ending.saga
  widgets/
    inventory.saga
    contacts.saga
  assets/
    images/
      portrait.png
      item.png
```

The compiler currently loads all `.saga` files under the story root, so widgets and character profiles can live wherever they are easiest to maintain.

## Scenes

Scenes are Markdown-style headings:

```saga
# Village
## GateWatch
### WatchtowerRumor
```

Nested headings create full scene paths:

```text
Village
Village.GateWatch
Village.GateWatch.WatchtowerRumor
```

A heading always declares a scene. Indentation is optional, but recommended for readability.

## Passages

Passages are shown with `>`:

```saga
> Rain taps against the shutters.
> `has_cloak` Your cloak keeps the rain from your collar.
```

The optional backtick expression after `>` controls visibility.

## Choices

Choices use `+`, a transfer arrow, and a labeled destination:

```saga
+ -> [Open the letter](#.Letter)
+ `coin >= 2` -> [Buy a cloak](/market.saga#Square.CloakSeller)
+ -> `has_key` [Enter](#LockedRoom)
```

The first condition controls visibility. The condition after the arrow controls whether the choice is enabled.

The older `+ Choice text -> [Target]` form is still accepted during the v0.1 transition.

## Transfers

Saga has three transfer arrows:

```saga
->  normal transfer
*-> one-shot transfer
w-> widget transfer
```

Examples:

```saga
-> [Village]
+ Take the key *-> [.TakeKey]
w-> [Inventory]("/widgets/inventory.saga")
```

Use `*->` when a choice or automatic transition should only be available once per playthrough.

Use `w->` to open or activate a widget without replacing the current main scene.

## Targets

Modern choice and dialogue speaker targets use Markdown-style labels with Saga destinations:

```saga
[Button text](#Scene)              // scene from module root
[Button text](#Scene.Child)        // nested scene from module root
[Button text](#.)                  // current scene
[Button text](#.Child)             // child of current scene
[Button text](#..)                 // parent scene
[Button text](#..Sibling)          // sibling under current parent
[Button text](/other.saga#Scene)   // scene in another module
```

The text inside `[]` is what the reader sees. The destination inside `()` tells Saga where it points.

Automatic transitions and older choices still accept legacy square-bracket targets:

```saga
[Scene]
[.Child]
[Scene]("/other.saga")
```

When in doubt, prefer explicit module-root paths for cross-file links.

## Text interpolation and prompts

Displayed story text can interpolate runtime values with `#{...}`:

```saga
> Welcome, #{player_name}.
>> [Guide](/characters.saga#Guide) As I was telling #{player_name}, the princess is in another castle.
+ -> [Ask #{player_name}'s question](#.Question)
```

Interpolation works in passages, dialogue text, choice text, and image alt text. Values are inserted as text, not HTML.

For player prompts, use a normal effect with browser JavaScript:

```saga
# Start
  `player_name ?= prompt("What is your name?") || "traveler"`
  > Welcome, #{player_name}.
```

The `?=` operator makes the prompt run only if `player_name` has not already been assigned.

Backticks are still used for Saga conditions/effects. `#{...}` is only interpreted inside displayed text. In v0, interpolation expressions should be simple JavaScript expressions and should not contain `}`.

## State and effects

Effects are backtick expressions on their own line:

```saga
`visited_start ?= false`
`visited_start := true`
`coin := coin + 1`
`road_steps++`
```

Common operators:

- `?=` initializes a value only if it is not already assigned.
- `:=` assigns persistent story state.
- `=` creates or assigns a scene-local value for the current visit.
- `++` increments a value.

The generated runtime currently evaluates expressions in JavaScript.

## Images

Images use Markdown-style syntax:

```saga
![Alt text]("/assets/images/letter.png")
```

Root-relative paths beginning with `/` are resolved against the story root and validated at compile time.

Images are rendered inline in normal scenes and inside modals for item/character widgets.

## Widgets

Widgets are normal scenes decorated with `@widget`.

```saga
@widget std:inventory
# Inventory
  > Your personal belongings
  + `has_key` Blackened key w-> [.OldKey]

@widget std:item
## OldKey
  ![Blackened key]("/assets/images/key.png")
  > A cold iron key with oil-dark teeth.
```

Built-in widget renderers:

- `std:inventory` — dock widget for item lists.
- `std:contacts` — dock widget for known characters/contacts.
- `std:status` — dock widget for status displays.
- `std:item` — modal profile for an item.
- `std:character` — modal profile for a character and valid dialogue speaker.

The runtime automatically shows `std:contacts` widgets in the dock. Other dock widgets can be activated with `w->`.

## Local saves

Generated stories include local browser save slots in the Settings dock widget. Saves are stored with `localStorage` in the reader's browser and include the current scene, state variables, consumed one-shot transitions, and active dock widgets. Import/export saves are not implemented yet.

## Character profiles and dialogue

Character profiles are `std:character` widgets:

```saga
@widget std:character
# BlueScarf
  ![Blue scarf portrait]("/assets/images/blue_scarf.png")
  > The woman with the blue scarf.
```

Dialogue uses `>>`:

```saga
>> [BlueScarf]("/characters.saga") Then you are already late.
>> Find the archivist's mark beneath the tower.
```

The first line of a bubble names the speaker. Consecutive `>>` lines without a speaker continue the same bubble.

Dialogue can be conditional:

```saga
>> `trust_blue_scarf` [BlueScarf]("/characters.saga") You came back. Good.
```

If all lines in a dialogue group are hidden by conditions, the runtime skips the bubble.

## Validation

The compiler reports errors for common authoring mistakes:

- unresolved target modules,
- unresolved target scenes,
- `w->` transfers to non-widget scenes,
- unknown widget renderers,
- dialogue speakers that are missing or not `std:character`,
- dialogue continuation lines without a speaker,
- missing root-relative image assets.

Run tests and build the sample story after language/runtime changes:

```sh
odin test src
odin run src -- examples/test_drive/main.saga examples/test_drive/out.html
```

## Current limitations

Current v0 limitations to keep in mind:

- Statements are single-line.
- Save/load is local browser `localStorage` only; there is no import/export yet.
- Story metadata such as title and author is not implemented yet.
- The generated runtime evaluates expressions as JavaScript.
- Packaging/install-path behavior for `src/runtime.js` and `src/style.css` still needs a release pass.
