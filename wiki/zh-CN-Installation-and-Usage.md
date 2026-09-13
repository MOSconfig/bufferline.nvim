# 安装与使用

## 环境要求

- 默认的原生单行渲染器需要 Neovim 0.8+。
- 可选启用的[多行渲染器](zh-CN-Multiline-Buffer-Tabs)需要 Neovim 0.12+。
- 一款补丁字体（参见 [nerd fonts](https://github.com/ryanoasis/nerd-fonts)）。
- 一款配色方案。本插件会从 `Normal`、`String`、`TabLineSel`（回退为 `WildMenu`）和
  `Comment` 中取色。

## 安装

建议固定某个 tag，并在检查变更后手动升级。若需要兼容 nvim-0.6.1 及更低版本，请使用
`tag = "v1.*"`。

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

若要试用多行渲染器，请指向本分支而非上游 tag，详见
[多行 buffer 标签](zh-CN-Multiline-Buffer-Tabs)。

## 使用

本插件需要 `termguicolors` 才能按预期工作，因为它会读取各高亮组的 `gui` 十六进制色值。

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

可以点击关闭图标来关闭 buffer，也可以在标签的任意位置_右键点击_。

完整使用参考：`:help bufferline-usage`。
