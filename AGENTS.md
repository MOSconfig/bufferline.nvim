# Agent guide

## Project and boundaries

This is the `MOSconfig/bufferline.nvim` fork of `akinsho/bufferline.nvim`, a Lua plugin for Neovim. Keep upstream attribution and the license. Work in this checkout, not an installed plugin or another repository's Neovim configuration. Do not install, update, merge, release, or switch a user's active configuration unless requested.

Native single-row mode remains the default and supports Neovim 0.8+. The opt-in `options.multiline` renderer requires Neovim 0.12+. Do not call new APIs unconditionally from the native path or silently change native defaults.

## Architecture

- `lua/bufferline.lua`: public setup/commands, shared component computation, renderer selection and state publication.
- `lua/bufferline/config.lua`, `types.lua`: native defaults, validation and Lua annotations.
- `buffers.lua`, `models.lua`, `groups.lua`, `sorters.lua`, `diagnostics.lua`: buffer models, ordering and presentation data.
- `ui.lua`: semantic segments and native tabline serialization. Native markup is not valid buffer text; multiline uses plain text, highlight spans and action metadata.
- `commands.lua`, `pick.lua`: configured actions and navigation. Deferred mouse actions must retain their originating editing context.
- `offset.lua`: sidebar geometry; exclude positively owned header windows from the underlying layout.
- `multiline/options.lua`: side-effect-free opt-in validation before setup mutation.
- `multiline/layout.lua`: ordered row packing, Unicode clipping, overflow viewport and cell hit ranges.
- `multiline/runtime.lua`: header ownership, scheduled rendering, input observation, focus, lifecycle and native fallback.

## Tests

Run commands from the repository root. Tests use Plenary and nvim-web-devicons. To reuse existing dependencies without downloads, point `NVIM_TEST_DEPS` at a directory containing both plugin directories:

```sh
export NVIM_TEST_DEPS="$HOME/.local/share/nvim/lazy"
nvim --headless -i NONE -n -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua', sequential=true}"
```

Focused suite:

```sh
nvim --headless -i NONE -n -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/multiline_layout_spec.lua {minimal_init='tests/minimal_init.lua', sequential=true}"
```

With an explicit dependency root, missing dependencies must fail instead of downloading. Without it, the existing initializer may clone into gitignored `.tests/`. Test state is redirected into `.tests/`; never load the live config for automated tests. Run the complete suite after focused tests and inspect errors as well as exit status. A plain `nvim +lua ... +qa` can exit zero despite a Lua error.

For Lua syntax, use `loadfile` with an explicit `cquit 1` failure path. Check formatting with `stylua --check --config-path=stylua.toml lua/` when StyLua is available and run `git diff --check`.

## Change discipline

- Write a failing regression, make the smallest working change, then verify the focused and full suites.
- Preserve existing native rendering snapshots, callbacks, sorting and public command behavior.
- Highlight positions are zero-based byte ranges; mouse hit regions and widths are display cells. Test literal percent signs, multibyte/wide characters and combining marks.
- Header buffers are scratch, unlisted and noneditable. Only dispose resources proven to be owned; never force-delete user buffers or arbitrary unnamed windows.
- Native tabline evaluation cannot drive hidden-tabline state. Multiline refresh is event-driven; avoid feedback loops from painting and stale callbacks after teardown.
- Picking needs synchronous paint before blocking for input. Mouse tests must send actual input from an editing window, not merely invoke a Lua handler.
- Verify UI changes in isolated interactive Neovim with multiple buffers, splits, a sidebar, resize and mouse input. Report any unsupported runtime/version or untested behavior.
- Keep README/help, option types, issue acceptance criteria and tests aligned. Do not weaken assertions or hide errors merely to obtain a passing run.

## Known multiline constraints

Custom areas, hover reveal and native tabpage controls are single-row-only. The header consumes real split height and a divider. User mouse mappings retain precedence. Disable multiline before saving a built-in session: the default `blank` session option can serialize scratch windows. Window-close edge behavior and fallback rules are documented in `:help bufferline-multiline`.

## Delivery

Use a feature branch and link the requested fork issue in the PR. Include exact test evidence, compatibility/behavior changes and limitations. Treat CI definitions as shared infrastructure: do not edit or bypass workflows without authorization. Check remote branch changes before pushing; never overwrite another session's work. Keep `.tests/`, local dependencies and temporary output untracked. Merge/release only when explicitly requested, then perform safe post-merge cleanup.
