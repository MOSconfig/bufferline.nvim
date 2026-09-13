# Installation and Usage

## Requirements

- Neovim 0.8+ for the default native single-row renderer.
- Neovim 0.12+ for the opt-in [multiline renderer](Multiline-Buffer-Tabs).
- A patched font (see [nerd fonts](https://github.com/ryanoasis/nerd-fonts)).
- A colorscheme. The plugin derives colours from `Normal`, `String`, `TabLineSel`
  (`WildMenu` as fallback) and `Comment`.

## Install

Pin a tag and bump it manually if you prefer to inspect changes before updating. For a
version compatible with nvim-0.6.1 and below, use `tag = "v1.*"`.

**Lua**

```lua
-- using packer.nvim
use {'akinsho/bufferline.nvim', tag = "*", requires = 'nvim-tree/nvim-web-devicons'}

-- using lazy.nvim
{'akinsho/bufferline.nvim', version = "*", dependencies = 'nvim-tree/nvim-web-devicons'}
```

**Vimscript**

```vim
Plug 'nvim-tree/nvim-web-devicons' " Recommended (for coloured icons)
" Plug 'ryanoasis/vim-devicons' Icons without colours
Plug 'akinsho/bufferline.nvim', { 'tag': '*' }
```

To try the multiline renderer, target this fork's branch instead of an upstream tag —
see [Multiline Buffer Tabs](Multiline-Buffer-Tabs).

## Usage

You need `termguicolors` for this plugin to work as intended, as it reads the hex `gui`
colour values of various highlight groups.

**Lua**

```lua
vim.opt.termguicolors = true
require("bufferline").setup{}
```

**Vimscript**

```vim
" In your init.lua or init.vim
set termguicolors
lua << EOF
require("bufferline").setup{}
EOF
```

You can close buffers by clicking the close icon or by _right clicking_ the tab anywhere.

Full usage reference: `:help bufferline-usage`.
