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
