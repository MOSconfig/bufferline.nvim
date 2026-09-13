# Agent guide

## Project and boundaries

This is the `MOSconfig/bufferline.nvim` fork of `akinsho/bufferline.nvim`, a Lua plugin for Neovim. Keep upstream attribution and the license. Work in this checkout, not an installed plugin or another repository's Neovim configuration. Do not install, update, merge, release, or switch a user's active configuration unless requested.

Native single-row mode remains the default and supports Neovim 0.8+. The opt-in `options.multiline` renderer requires Neovim 0.12+. Do not call new APIs unconditionally from the native path or silently change native defaults.

## Start here

1. Read this guide before editing; `CLAUDE.md` imports it rather than maintaining another policy.
2. Run the read-only preflight below. Preserve unrelated changes and verify the requested branch/ref before working.
3. Read only the modules and regression suites relevant to the task, then consult `wiki/` for the public behavior contract. READMEs are feature introductions, not configuration references.
4. Follow the validation matrix below. Report the commands, results, runtime version and anything not tested; passing syntax checks is not evidence that the UI works.

```sh
pwd
git status --short --branch
git remote -v
git worktree list
nvim --version
python3 --version
```

### Task map

Paths below are relative to the repository root; module paths in the architecture list are relative to `lua/bufferline/` unless stated otherwise.

| Task | Start with | Regression tests |
| --- | --- | --- |
| Setup or renderer selection | `lua/bufferline.lua`, `lua/bufferline/multiline/options.lua` | `tests/config_spec.lua`, `tests/multiline_options_spec.lua`, `tests/multiline_state_spec.lua` |
| Wrapping, clipping or overflow | `lua/bufferline/multiline/layout.lua` | `tests/multiline_layout_spec.lua` |
| Highlights or segment conversion | `lua/bufferline/ui.lua` | `tests/ui_spec.lua`, `tests/multiline_segments_spec.lua` |
| Header lifecycle, focus or mouse | `lua/bufferline/multiline/runtime.lua` | `tests/multiline_runtime_spec.lua`, `tests/multiline_integration_spec.lua` |
| Picking or sidebar geometry | `lua/bufferline/pick.lua`, `lua/bufferline/offset.lua` | `tests/multiline_pick_spec.lua`, `tests/offset_spec.lua` |
| Settings or documentation | `wiki/Multiline-Buffer-Tabs.md`, `wiki/help/05-multiline-buffer-tabs.txt` | `scripts/test_docs.py`, `scripts/test_wiki_sync.py` |

## Architecture

- `lua/bufferline.lua`: public setup/commands, shared component computation, renderer selection and state publication.
- `lua/bufferline/config.lua`, `types.lua`: native defaults, validation and Lua annotations.
- `buffers.lua`, `models.lua`, `groups.lua`, `sorters.lua`, `diagnostics.lua`: buffer models, ordering and presentation data.
- `ui.lua`: semantic segments and native tabline serialization. Native markup is not valid buffer text; multiline uses plain text, highlight spans and action metadata.
- `commands.lua`, `pick.lua`: configured actions and navigation. Deferred mouse actions must retain their originating editing context.
- `offset.lua`: sidebar geometry; exclude positively owned header windows from the underlying layout.
- `multiline/options.lua`: side-effect-free opt-in validation before setup mutation.
- `multiline/layout.lua`: ordered row packing, Unicode clipping, overflow viewport and cell hit ranges.
- `multiline/runtime.lua`: header ownership, scheduled rendering, input observation, focus, and lifecycle. `options.multiline.enabled` is the sole renderer selector: `M.selected()` is the configured choice and only `enable`/`disable` change it, while `M.active()` is momentary readiness. Native visibility is restored only by `disable()`; every unavailable path keeps `showtabline` at 0 and recovers event-driven, per tabpage.

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

### Validation by change

| Change | Required checks |
| --- | --- |
| README, wiki or agent guidance only | Documentation commands below; `git diff --check`; verify new links and preview assets. No Neovim UI run is needed unless examples or behavior change. |
| Lua behavior or configuration | Failing regression first, focused Plenary suite, full suite, syntax and formatting checks, documentation checks when applicable. |
| Rendering or input | All Lua checks plus isolated interactive Neovim verification described below. |

```sh
python3 scripts/gen_help.py --check
python3 scripts/test_docs.py
python3 scripts/test_wiki_sync.py
git diff --check
```

For authored help changes, run `python3 scripts/gen_help.py` before those checks. Detailed development instructions are in `wiki/Testing-and-Development.md` and `wiki/zh-CN-Testing-and-Development.md`. The existing wiki publisher validates and copies `wiki/*.md` on a published release; editing local sources does not publish them. Do not dispatch it or create a release without a request.

## Change discipline

- Write a failing regression, make the smallest working change, then verify the focused and full suites.
- Preserve existing native rendering snapshots, callbacks, sorting and public command behavior.
- Highlight positions are zero-based byte ranges; mouse hit regions and widths are display cells. Test literal percent signs, multibyte/wide characters and combining marks.
- Header buffers are scratch, unlisted and noneditable. Only dispose resources proven to be owned; never force-delete user buffers or arbitrary unnamed windows.
- Native tabline evaluation cannot drive hidden-tabline state. Multiline refresh is event-driven; avoid feedback loops from painting and stale callbacks after teardown.
- Picking needs synchronous paint before blocking for input. Mouse tests must send actual input from an editing window, not merely invoke a Lua handler.
- Verify UI changes in isolated interactive Neovim with multiple buffers, splits, a sidebar, resize and mouse input. Report any unsupported runtime/version or untested behavior.
- Author documentation under `wiki/`; edit `wiki/help/*.txt` and run `python3 scripts/gen_help.py`, never edit generated `doc/bufferline.txt`. Keep English/Chinese guides and README summaries aligned with the reference and code. Run `python3 scripts/gen_help.py --check`, `python3 scripts/test_docs.py`, and `python3 scripts/test_wiki_sync.py`.
- Keep option types, issue acceptance criteria and tests aligned. Do not weaken assertions or hide errors merely to obtain a passing run.

## Known multiline constraints

Custom areas, hover reveal and native tabpage controls are single-row-only. The header consumes real split height and a divider. User mouse mappings retain precedence. Disable multiline before saving a built-in session: the default `blank` session option can serialize scratch windows. There is no native single-row fallback while multiline is enabled; window-close, quit and recovery rules are documented in `:help bufferline-multiline`.

## Delivery

Use a feature branch and link the requested fork issue in the PR. Include exact test evidence, compatibility/behavior changes and limitations. Treat CI definitions as shared infrastructure: do not edit or bypass workflows without authorization. Check remote branch changes before pushing; never overwrite another session's work. Keep `.tests/`, local dependencies and temporary output untracked. Merge/release only when explicitly requested, then perform safe post-merge cleanup.
