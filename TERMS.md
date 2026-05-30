# Terms of Use and Licensing

This project uses a split licensing policy:

1. **Saga itself is copyleft software.**
2. **Stories created with Saga belong to their authors.**
3. **Generated HTML output belongs to the story author, except for the embedded Saga runtime/style code, which remains GPL-licensed.**

This document is intended to make that split clear. It is not legal advice.

## Saga software license

The Saga compiler, source code, generated runtime, generated stylesheet, examples of compiler/runtime code, build files, and project documentation are licensed under the GNU General Public License, version 3 or later.

See `LICENSE` for the full GNU GPLv3 text.

This includes, but is not limited to:

- `src/*.odin`
- `src/runtime.js`
- `src/style.css`
- `nix/`
- project documentation in `docs/`
- project-level repository files, unless otherwise stated

You may use, study, copy, modify, and redistribute Saga under the terms of the GPL.

## Story ownership

Stories written by authors using the Saga language are **not required to be GPL-licensed** just because they were written for or compiled with Saga.

Story authors own and control their own story content, including:

- `.saga` story files,
- prose,
- dialogue,
- characters,
- settings,
- story structure,
- story-specific images and other assets,
- story-specific metadata, once supported.

Authors may license and distribute their stories however they choose, including proprietary, commercial, open source, Creative Commons, public domain dedication, or any other terms they prefer.

## Generated HTML output

Saga generates standalone HTML files. Those generated HTML files contain two kinds of material:

1. the author's story content and assets/data, and
2. embedded Saga runtime/style code needed to play the story.

The author owns the story content in the generated HTML and may distribute the generated story as they see fit.

The embedded Saga runtime/style code remains licensed under the GNU GPLv3-or-later. Distribution of generated HTML is permitted, and authors are not required to license their story content under the GPL merely because the generated HTML includes the Saga runtime.

If you distribute generated HTML, you should preserve any included license notices for the Saga runtime and provide access to Saga's GPL license text when practical.

## Example stories and assets

Unless a specific example states otherwise, example story content and example assets in this repository are part of the Saga project and are distributed under the same GPLv3-or-later terms as the project.

If you copy example story content or assets into your own story, that copied material remains subject to the repository license unless it is separately relicensed.

## Author assets

Authors are responsible for ensuring they have rights to any assets they include in their own stories, including:

- images,
- portraits,
- fonts,
- music,
- sound effects,
- prose,
- names and trademarks,
- third-party content.

Saga does not grant rights to third-party material.

## Contributor note

By contributing code or documentation to Saga, you should expect your contribution to be distributed under the project's GPLv3-or-later license unless a different arrangement is explicitly agreed in writing.

By contributing story examples or assets to this repository, you should clearly state if they are intended to use different terms from the project default.

## Short version

- The tool is GPL copyleft.
- Your stories are yours.
- Your generated story HTML is yours to distribute.
- The embedded Saga runtime remains GPL.
- Do not assume you can reuse third-party or example assets outside their license.
