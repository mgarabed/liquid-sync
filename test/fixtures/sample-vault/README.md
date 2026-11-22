# Sample vault (test fixture)

A small, made-up Obsidian vault for sync and round-trip tests. Everything in
it is original filler.

**Never open this folder in Obsidian, and never point LiveSync at it.** Both
write into the vault (`.obsidian/workspace.json`, plugin data), and those
writes would land in the repo. Make a throwaway copy outside the repo instead:

    scripts/fixture-vault              # fresh temp dir, printed on stdout
    scripts/fixture-vault --to DIR     # stable path, replaced on each run

A round trip must reproduce every file byte for byte.

| File | Exercises |
| ---- | --------- |
| `Start here.md` | Space in the name; frontmatter (list, nested tag, date); `[[wikilinks]]` with alias and heading; `![[embed]]` of the PNG; link to the PDF; inline and nested tags; callouts (plain and folded); a fenced code block holding link and tag lookalikes; tasks; trailing-space hard break; footnote |
| `Notes/Garden/Seed Library/Tomato varieties.md` | Folder nested 3 deep, with a space; inline-list frontmatter; table |
| `Recettes/Crème brûlée.md` | Non-ASCII folder and file names (NFC); non-ASCII text |
| `Ideas 💡.md` | Emoji in the name and text; heading link target |
| `attachments/sample-diagram.png` | Small binary image, embedded |
| `attachments/sample-handout.pdf` | Small binary PDF, linked |
| `.obsidian/app.json` | Hidden config file |
| `.obsidian/snippets/fixture.css` | Hidden CSS snippet in a nested hidden folder |

Rules for changes: keep it small (well under 200 KB), keep every name in NFC,
never add names that differ only by case, and add no plugins or
`workspace*.json` to `.obsidian/`. The PNG and PDF were generated with the
Python standard library for this fixture and carry no metadata.
