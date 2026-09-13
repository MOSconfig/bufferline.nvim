[![CI](https://github.com/akinsho/bufferline.nvim/actions/workflows/ci.yaml/badge.svg)](https://github.com/akinsho/bufferline.nvim/actions/workflows/ci.yaml)

<h1 align="center">
  bufferline.nvim
</h1>

<p align="center">A <i>snazzy</i> 💅 buffer line (with tabpage integration) for Neovim built using <b>lua</b>.</p>

![Demo GIF](https://user-images.githubusercontent.com/22454918/111992693-9c6a9b00-8b0d-11eb-8c39-19db58583061.gif)

<p align="center">
  <a href="https://github.com/MOSconfig/bufferline.nvim/wiki/Home">Documentation wiki</a> ·
  <a href="README.zh-CN.md">中文说明</a>
</p>

<!--toc:start-->

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Features](#features)
  - [Multiline buffer tabs](#multiline-buffer-tabs)
  - [Alternate styling](#alternate-styling)
  - [Hover events](#hover-events)
  - [Underline indicator](#underline-indicator)
  - [Tabpages](#tabpages)
  - [LSP indicators](#lsp-indicators)
  - [Groups](#groups)
  - [Sidebar offsets](#sidebar-offsets)
  - [Numbers](#numbers)
  - [Picking](#picking)
  - [Pinning](#pinning)
  - [Unique names](#unique-names)
  - [Close icons](#close-icons)
  - [Re-ordering](#re-ordering)
  - [Custom areas](#custom-areas)
- [How do I see only buffers per tab?](#how-do-i-see-only-buffers-per-tab)
- [Caveats](#caveats)
- [FAQ](#faq)
- [Tests](#tests)
<!--toc:end-->

This plugin shamelessly attempts to emulate the aesthetics of GUI text editors/Doom Emacs.
It was inspired by a screenshot of DOOM Emacs using [centaur tabs](https://github.com/ema2159/centaur-tabs).

Full documentation lives in the [wiki](https://github.com/MOSconfig/bufferline.nvim/wiki),
which is the only authored documentation source. The Vim help file is generated from it
and shipped in this repository — read it with `:help bufferline.nvim`.

## Requirements

- Neovim 0.8+ (0.12+ for [multiline buffer tabs](#multiline-buffer-tabs))
- A patched font (see [nerd fonts](https://github.com/ryanoasis/nerd-fonts))
- A colorscheme (either your custom highlight or a maintained one somewhere)

## Installation

```lua
-- using packer.nvim
use {'akinsho/bufferline.nvim', tag = "*", requires = 'nvim-tree/nvim-web-devicons'}

-- using lazy.nvim
{'akinsho/bufferline.nvim', version = "*", dependencies = 'nvim-tree/nvim-web-devicons'}
```

Vimscript plugin managers, version pinning and the nvim-0.6.1-compatible `v1.*` tag are
covered in [Installation and Usage](https://github.com/MOSconfig/bufferline.nvim/wiki/Installation-and-Usage).

## Usage

```lua
vim.opt.termguicolors = true
require("bufferline").setup{}
```

`termguicolors` is required, as the plugin reads the hex `gui` colour values of various
highlight groups. You can close buffers by clicking the close icon or by _right clicking_
the tab anywhere. See `:h bufferline.nvim` or
[Installation and Usage](https://github.com/MOSconfig/bufferline.nvim/wiki/Installation-and-Usage).

## Configuration

`setup()` takes a **complete** configuration, not an incremental options update. See
`:h bufferline-configuration` and
[Configuration](https://github.com/MOSconfig/bufferline.nvim/wiki/Configuration).

Contributors and AI coding agents: read [AGENTS.md](AGENTS.md) for architecture, offline
tests, compatibility boundaries, and safe development workflows. [CLAUDE.md](CLAUDE.md)
imports that shared guide for Claude Code.

## Features

- Colours derived from colorscheme where possible.
- Sort buffers by `extension`, `directory` or pass in a custom compare function.
- Configuration via lua functions for greater customization.

Details and screenshots for every feature below:
[Features](https://github.com/MOSconfig/bufferline.nvim/wiki/Features).

#### Multiline buffer tabs

Opt-in multi-row rendering. Requires **Neovim 0.12+** with `mode = "buffers"`; the native
single-row renderer remains the default and unchanged.

```lua
{ "MOSconfig/bufferline.nvim", branch = "feat/multiline-buffer-tabs", dependencies = "nvim-tree/nvim-web-devicons" }
```

```lua
multiline_config.options.mode = "buffers"
multiline_config.options.multiline = { enabled = true, max_rows = 3 }
bufferline.setup(multiline_config)
```

`options.multiline.enabled` is the **only** renderer selector — while it is enabled the
native single row never returns, and there is no fallback to it. The header is a reserved
split above the editor; when it cannot be drawn it is removed for that tabpage only and
recovery is event-driven.

The complete contract — keyboard maps (`h`/`j`/`k`/`l`/`x`/`<CR>`/`<Esc>`, and **no** `q`
map), quitting, session and API limitations — is in
[Multiline Buffer Tabs](https://github.com/MOSconfig/bufferline.nvim/wiki/Multiline-Buffer-Tabs)
and `:help bufferline-multiline`.

---

#### Alternate styling

##### Slanted tabs

![slanted tabs](https://user-images.githubusercontent.com/22454918/111992989-fec39b80-8b0d-11eb-851b-010641196a04.png)

##### Sloped tabs

![sloped tabs](https://user-images.githubusercontent.com/22454918/220115787-0ba2264f-1cf5-4f18-a322-7c7cfa3d8f42.png)

see: `:h bufferline-styling`

---

#### Hover events

**NOTE**: this is _only_ available for >= neovim 0.8+

![hover-event-preview](https://user-images.githubusercontent.com/22454918/189106657-163b0550-897c-42c8-a571-d899bdd69998.gif)

see `:help bufferline-hover-events` for more information on configuration

---

#### Underline indicator

<img width="1355" alt="Screen Shot 2022-08-22 at 09 14 24" src="https://user-images.githubusercontent.com/22454918/185873089-2ae20db0-f292-4d96-afe4-ef0683a60709.png">

---

#### Tabpages

<img width="800" alt="Screen Shot 2022-03-08 at 17 39 57" src="https://user-images.githubusercontent.com/22454918/157337891-1848da24-69d6-4970-96ee-cf65b2a25c46.png">

Set `mode = "tabs"` to show only tabpages. Sorting and grouping do not work in this mode.

---

#### LSP indicators

![LSP Indicator](https://user-images.githubusercontent.com/22454918/113215394-b1180300-9272-11eb-9632-8a9f9aae99fa.png)

Set `diagnostics = "nvim_lsp" | "coc"` to get an indicator for buffers with errors.

![diagnostics_indicator](https://user-images.githubusercontent.com/4028913/112573484-9ee92100-8da9-11eb-9ffd-da9cb9cae3a6.png)

Indicators can also be reported conditionally, based on buffer context.

![current](https://user-images.githubusercontent.com/58056722/119390133-e5d19500-bccc-11eb-915d-f5d11f8e652c.jpeg)
![visible](https://user-images.githubusercontent.com/58056722/119390136-e66a2b80-bccc-11eb-9a87-e622e3e20563.jpeg)

Snippets and the `diagnostics_indicator` signature:
[Features](https://github.com/MOSconfig/bufferline.nvim/wiki/Features#lsp-indicators).

---

#### Groups

![bufferline_group_toggle](https://user-images.githubusercontent.com/22454918/132410772-0a4c0b95-63bb-4281-8a4e-a652458c3f0f.gif)

see `:help bufferline-groups` for more information on how to set these up

---

#### Sidebar offsets

![explorer header](https://user-images.githubusercontent.com/22454918/117363338-5fd3e280-aeb4-11eb-99f2-5ec33dff6f31.png)

---

#### Numbers

![bufferline with numbers](https://user-images.githubusercontent.com/22454918/119562833-b5f2c200-bd9e-11eb-81d3-06876024bf30.png)

![numbers](https://user-images.githubusercontent.com/22454918/130784872-936d4c55-b9dd-413b-871d-7bc66caf8f17.png)

see `:help bufferline-numbers` for more details

---

#### Unique names

![duplicate names](https://user-images.githubusercontent.com/22454918/111993343-6da0f480-8b0e-11eb-8d93-44019458d2c9.png)

---

#### Close icons

![close button](https://user-images.githubusercontent.com/22454918/111993390-7a254d00-8b0e-11eb-9951-43b4350f6a29.gif)

---

#### Re-ordering

![re-order buffers](https://user-images.githubusercontent.com/22454918/111993463-91643a80-8b0e-11eb-87f0-26acfe92c021.gif)

This order can be persisted between sessions (enabled by default).

---

#### Picking

![bufferline pick](https://user-images.githubusercontent.com/22454918/111993296-5bbf5180-8b0e-11eb-9ad9-fcf9619436fd.gif)

---

#### Pinning

<img width="899" alt="Screen Shot 2022-03-31 at 18 13 50" src="https://user-images.githubusercontent.com/22454918/161112867-ba48fdf6-42ee-4cd3-9e1a-7118c4a2738b.png">

---

#### Custom areas

![custom area](https://user-images.githubusercontent.com/22454918/118527523-4d219f00-b739-11eb-889f-60fb06fd71bc.png)

see `:help bufferline-custom-areas`

## How do I see only buffers per tab?

This behaviour is _not native in neovim_. You can get it using
[scope.nvim](https://github.com/tiagovla/scope.nvim) with this plugin — see
[FAQ and Caveats](https://github.com/MOSconfig/bufferline.nvim/wiki/FAQ-and-Caveats).

## Caveats

This plugin is opinionated about how the tabline looks, relies on basic highlights being
set by your colour scheme (`Normal`, `String`, `TabLineSel`, `Comment`), and depends on
darkening, so low-contrast schemes suffer. Full list:
[FAQ and Caveats](https://github.com/MOSconfig/bufferline.nvim/wiki/FAQ-and-Caveats#caveats).

## FAQ

- **Why isn't the bufferline appearing?** Usually a clash with another tabline plugin
  (`airline`, `lightline`, `GuiTabline`).
- **Doesn't this plugin go against the "vim way"?** Short answer: no.

Both answered in full in
[FAQ and Caveats](https://github.com/MOSconfig/bufferline.nvim/wiki/FAQ-and-Caveats).

## Tests

From the repository root:

```sh
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

Set `NVIM_TEST_DEPS` to a directory containing existing `plenary.nvim` and
`nvim-web-devicons` checkouts for offline runs. Use Neovim 0.12+ when testing multiline.
Documentation has its own stdlib-only checks:

```sh
python3 scripts/gen_help.py --check
python3 scripts/test_docs.py
```

See [Testing and Development](https://github.com/MOSconfig/bufferline.nvim/wiki/Testing-and-Development)
and [Documentation Pipeline](https://github.com/MOSconfig/bufferline.nvim/wiki/Documentation-Pipeline).
