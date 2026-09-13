# Testing and Development

Run all commands from the repository root.

## Full suite

Missing dependencies are downloaded into gitignored `.tests/`:

```sh
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

## Offline suite

Set `NVIM_TEST_DEPS` to a directory containing existing `plenary.nvim` and
`nvim-web-devicons` checkouts. This mode does **not** download missing dependencies —
they fail instead:

```sh
export NVIM_TEST_DEPS="$HOME/.local/share/nvim/lazy"
nvim --headless -i NONE -n -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua', sequential=true}"
```

## Focused suite

```sh
nvim --headless -i NONE -n -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/multiline_layout_spec.lua {minimal_init='tests/minimal_init.lua', sequential=true}"
```

Use Neovim 0.12+ when testing multiline.

## Documentation tests

The documentation pipeline has its own stdlib-only tests:

```sh
python3 scripts/gen_help.py --check   # generated help is in sync
python3 scripts/test_docs.py          # drift, link and image parity
python3 scripts/test_wiki_sync.py     # wiki publishing safety
```

See [Documentation Pipeline](Documentation-Pipeline).

## Gotchas

- A plain `nvim +lua ... +qa` can exit zero despite a Lua error. Use an explicit
  `cquit 1` failure path.
- Run the complete suite after focused tests, and inspect errors as well as exit status.
- Never load the live user config for automated tests; test state is redirected into
  `.tests/`.
- Check formatting with `stylua --check --config-path=stylua.toml lua/` when StyLua is
  available, and run `git diff --check`.

## Agent guide

Contributors and AI coding agents should read
[AGENTS.md](https://github.com/MOSconfig/bufferline.nvim/blob/HEAD/AGENTS.md) for
architecture, compatibility boundaries, ownership safety and PR workflow.

Start with the guide's read-only preflight and task map. It points from setup, layout,
rendering and input tasks to the matching modules and regression suites. `CLAUDE.md`
loads that shared guide; keep agent rules there rather than copying them into several
provider-specific instruction files.

For prose-only changes, run the three documentation checks above and `git diff --check`.
For Lua changes, add a failing regression, run the focused suite, then the full suite.
UI and input changes also need isolated interactive testing, not just headless tests.
Keep machine-specific paths, downloaded dependencies and test output out of commits.

README files are bilingual feature introductions. Put detailed settings and runnable
examples in the paired wiki pages, and reference behavior in `wiki/help/`. The existing
release workflow publishes the Markdown pages from `wiki/` after validation; local
edits alone do not update GitHub's wiki. See [Documentation Pipeline](Documentation-Pipeline).
