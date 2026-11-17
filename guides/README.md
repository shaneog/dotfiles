# Guides

Illustrated, plain-language explanations of what these dotfiles do and how.
Plain HTML, CSS and JavaScript: no build step and no dependencies, so they open
straight from disk.

```sh
open guides/index.html
```

| Page | Explains |
| ------------- | ------------- |
| `index.html` | What dotfiles are, the five ideas behind this repo, a map of it, a glossary |
| `install.html` | `script/bootstrap` step by step, re-running it, `make update` and `make doctor`, `script/remove` |
| `layout.html` | The symlinks `script/setup` creates, what `.gitignore` covers, per-machine files |
| `shell.html` | zsh startup order, layering on a managed shell, `lib/`, tmux autostart, startup time |
| `keys.html` | SSH auth and commit signing through 1Password, Touch ID for `sudo` |
| `tools.html` | Cheat sheet: git aliases, tmux and Neovim keys, fzf, the Brewfile |
| `tests.html` | The test tiers, `mutate` and `sweep`, `audit` and `doctor`, the CI workflows |

## Keeping them true

The pages describe the repo as it is on `main`. A change to behavior a page
describes should change the page in the same commit.

The guides are where the repo is explained, so the top-level `README.md` and
`AGENTS.md` link here instead of explaining it again. Two sets of measurements
are kept here and nowhere else: startup time in `shell.html#speed`, and the
install timings in `install.html#timing`.

`test/static/guides.bats` compares what it can with the code:

- the git aliases in the first table under `tools.html#git`, against
  `config/zsh/lib/git.zsh`;
- each page's "Guide N of 7" line, against the `PAGES` list in
  `assets/guide.js`;
- every tool wrapped in `<span data-brew="formula-name">`, against the
  `Brewfile`. Wrap a tool that way when a page names it because the `Brewfile`
  installs it.

Nothing checks the rest.

Diagrams are ordinary HTML driven by `assets/guide.css`, not drawings with
coordinates, so updating one is editing a list:

- **Symlink map** (`layout.html`): a heading per real folder, then one `<li>`
  per entry inside it, home path on the left, target on the right. A row with
  class `stays` is a real file that is not linked.
- **Bootstrap timeline** (`install.html`): one `<li>` per step. Numbering and
  animation order follow document order.
- **Startup walkthrough** (`shell.html`): one `<li data-step>` per step inside
  the `<section class="stage">` for its file. The name goes in `<strong>`, the
  explanation in `.explain`.
- **Chains** (`keys.html`): alternating `.relay-node` and `.wire` elements.
- **Bar charts**: each bar's length is its `--v` against the list's `--max`.

Adding a page is a new HTML file copied from an existing one, plus one line in
the `PAGES` list at the top of `assets/guide.js`, which builds the navigation
and the previous/next links. The "Guide N of 7" line at the top of each page is
written by hand, and a test fails until every page's line agrees with the list.
Add the page to the table above and to the top-level `README.md` too; the same
test asks for both.

Colors are tokens defined once at the top of `assets/guide.css` with
`light-dark()`, so a diagram never names a color of its own and both themes
stay in step. Animations are skipped when the system asks for reduced motion,
and with JavaScript off every diagram is drawn in its finished state.

`script/setup` links only what it names, so this directory is never linked
into `$HOME`.

## Publishing

The guides are served at <https://ogrady.ie/dotfiles/>.
`.github/workflows/pages.yml` deploys this directory, and only this directory,
to GitHub Pages on every push to `main` that touches it. Pages has to be
switched on once in the repository settings, with "GitHub Actions" as the
source. Links between the pages are relative, so the same files work from disk
and from the site.
