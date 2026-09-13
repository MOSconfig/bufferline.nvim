[![CI](https://github.com/akinsho/bufferline.nvim/actions/workflows/ci.yaml/badge.svg)](https://github.com/akinsho/bufferline.nvim/actions/workflows/ci.yaml)

<h1 align="center">
  bufferline.nvim
</h1>

<p align="center">一个为 Neovim 打造的 <i>时髦</i> 💅 buffer 行（含标签页集成），使用 <b>lua</b> 编写。</p>

![Demo GIF](https://user-images.githubusercontent.com/22454918/111992693-9c6a9b00-8b0d-11eb-8c39-19db58583061.gif)

<p align="center">
  <a href="https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Home">中文文档 wiki</a> ·
  <a href="README.md">English</a>
</p>

<!--toc:start-->

- [环境要求](#环境要求)
- [安装](#安装)
- [使用](#使用)
- [配置](#配置)
- [功能](#功能)
  - [多行 buffer 标签](#多行-buffer-标签)
  - [其他样式](#其他样式)
  - [悬停事件](#悬停事件)
  - [下划线指示器](#下划线指示器)
  - [标签页](#标签页)
  - [LSP 指示器](#lsp-指示器)
  - [分组](#分组)
  - [侧边栏偏移](#侧边栏偏移)
  - [编号](#编号)
  - [拾取](#拾取)
  - [固定](#固定)
  - [唯一名称](#唯一名称)
  - [关闭图标](#关闭图标)
  - [重新排序](#重新排序)
  - [自定义区域](#自定义区域)
- [如何按标签页只显示对应的 buffer？](#如何按标签页只显示对应的-buffer)
- [注意事项](#注意事项)
- [常见问题](#常见问题)
- [测试](#测试)
<!--toc:end-->

本插件毫不掩饰地尝试模仿 GUI 文本编辑器／Doom Emacs 的美学，灵感来自一张使用
[centaur tabs](https://github.com/ema2159/centaur-tabs) 的 DOOM Emacs 截图。

完整文档位于 [wiki](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Home)，它是
唯一的文档撰写来源。Vim 帮助文件由其生成并随仓库分发——使用 `:help bufferline.nvim` 阅读。

## 环境要求

- Neovim 0.8+（[多行 buffer 标签](#多行-buffer-标签)需要 0.12+）
- 一款补丁字体（参见 [nerd fonts](https://github.com/ryanoasis/nerd-fonts)）
- 一款配色方案（自定义高亮，或任意维护良好的方案）

## 安装

```lua
-- using packer.nvim
use {'akinsho/bufferline.nvim', tag = "*", requires = 'nvim-tree/nvim-web-devicons'}

-- using lazy.nvim
{'akinsho/bufferline.nvim', version = "*", dependencies = 'nvim-tree/nvim-web-devicons'}
```

Vimscript 插件管理器、版本固定，以及兼容 nvim-0.6.1 的 `v1.*` tag，详见
[安装与使用](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Installation-and-Usage)。

## 使用

```lua
vim.opt.termguicolors = true
require("bufferline").setup{}
```

必须启用 `termguicolors`，因为插件会读取各高亮组的 `gui` 十六进制色值。可以点击关闭图标关闭
buffer，也可以在标签任意位置_右键点击_。参见 `:h bufferline.nvim` 或
[安装与使用](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Installation-and-Usage)。

## 配置

`setup()` 接收一份**完整**配置，而非增量式的选项更新。参见 `:h bufferline-configuration` 与
[配置](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Configuration)。

贡献者与 AI 编码 agent：请阅读 [AGENTS.md](AGENTS.md) 了解架构、离线测试、兼容性边界与安全的
开发流程。[CLAUDE.md](CLAUDE.md) 为 Claude Code 引入了这份共享指南。

## 功能

- 尽可能从配色方案中取色。
- 按 `extension`、`directory` 或自定义比较函数对 buffer 排序。
- 通过 lua 函数配置，获得更高的自定义程度。

以下每项功能的细节与截图：
[功能](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Features)。

#### 多行 buffer 标签

可选启用的多行渲染。要求 **Neovim 0.12+** 且 `mode = "buffers"`；原生单行渲染器仍是默认值且
保持不变。

```lua
{ "MOSconfig/bufferline.nvim", branch = "feat/multiline-buffer-tabs", dependencies = "nvim-tree/nvim-web-devicons" }
```

```lua
multiline_config.options.mode = "buffers"
multiline_config.options.multiline = { enabled = true, max_rows = 3 }
bufferline.setup(multiline_config)
```

`options.multiline.enabled` 是**唯一**的渲染器选择开关——只要它启用，原生单行就不会再出现，
也不存在回退到它的机制。header 是编辑区上方的预留分割窗口；当它无法绘制时，仅该标签页的
header 会被移除，且恢复由事件驱动。

完整契约——键盘映射（`h`/`j`/`k`/`l`/`x`/`<CR>`/`<Esc>`，且**不存在** `q` 映射）、退出行为、
会话与 API 限制——详见
[多行 buffer 标签](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Multiline-Buffer-Tabs)
与 `:help bufferline-multiline`。

---

#### 其他样式

##### 斜切标签

![slanted tabs](https://user-images.githubusercontent.com/22454918/111992989-fec39b80-8b0d-11eb-851b-010641196a04.png)

##### 倾斜标签

![sloped tabs](https://user-images.githubusercontent.com/22454918/220115787-0ba2264f-1cf5-4f18-a322-7c7cfa3d8f42.png)

参见：`:h bufferline-styling`

---

#### 悬停事件

**注意**：_仅_在 neovim 0.8+ 可用

![hover-event-preview](https://user-images.githubusercontent.com/22454918/189106657-163b0550-897c-42c8-a571-d899bdd69998.gif)

配置信息参见 `:help bufferline-hover-events`

---

#### 下划线指示器

<img width="1355" alt="Screen Shot 2022-08-22 at 09 14 24" src="https://user-images.githubusercontent.com/22454918/185873089-2ae20db0-f292-4d96-afe4-ef0683a60709.png">

---

#### 标签页

<img width="800" alt="Screen Shot 2022-03-08 at 17 39 57" src="https://user-images.githubusercontent.com/22454918/157337891-1848da24-69d6-4970-96ee-cf65b2a25c46.png">

设置 `mode = "tabs"` 可只显示标签页。该模式下排序与分组不可用。

---

#### LSP 指示器

![LSP Indicator](https://user-images.githubusercontent.com/22454918/113215394-b1180300-9272-11eb-9632-8a9f9aae99fa.png)

设置 `diagnostics = "nvim_lsp" | "coc"`，即可为存在错误的 buffer 显示指示器。

![diagnostics_indicator](https://user-images.githubusercontent.com/4028913/112573484-9ee92100-8da9-11eb-9ffd-da9cb9cae3a6.png)

指示器也可以根据 buffer 上下文有条件地显示。

![current](https://user-images.githubusercontent.com/58056722/119390133-e5d19500-bccc-11eb-915d-f5d11f8e652c.jpeg)
![visible](https://user-images.githubusercontent.com/58056722/119390136-e66a2b80-bccc-11eb-9a87-e622e3e20563.jpeg)

代码片段与 `diagnostics_indicator` 的签名：
[功能](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Features#lsp-指示器)。

---

#### 分组

![bufferline_group_toggle](https://user-images.githubusercontent.com/22454918/132410772-0a4c0b95-63bb-4281-8a4e-a652458c3f0f.gif)

设置方法参见 `:help bufferline-groups`

---

#### 侧边栏偏移

![explorer header](https://user-images.githubusercontent.com/22454918/117363338-5fd3e280-aeb4-11eb-99f2-5ec33dff6f31.png)

---

#### 编号

![bufferline with numbers](https://user-images.githubusercontent.com/22454918/119562833-b5f2c200-bd9e-11eb-81d3-06876024bf30.png)

![numbers](https://user-images.githubusercontent.com/22454918/130784872-936d4c55-b9dd-413b-871d-7bc66caf8f17.png)

更多细节参见 `:help bufferline-numbers`

---

#### 唯一名称

![duplicate names](https://user-images.githubusercontent.com/22454918/111993343-6da0f480-8b0e-11eb-8d93-44019458d2c9.png)

---

#### 关闭图标

![close button](https://user-images.githubusercontent.com/22454918/111993390-7a254d00-8b0e-11eb-9951-43b4350f6a29.gif)

---

#### 重新排序

![re-order buffers](https://user-images.githubusercontent.com/22454918/111993463-91643a80-8b0e-11eb-87f0-26acfe92c021.gif)

该顺序可以跨会话保持（默认启用）。

---

#### 拾取

![bufferline pick](https://user-images.githubusercontent.com/22454918/111993296-5bbf5180-8b0e-11eb-9ad9-fcf9619436fd.gif)

---

#### 固定

<img width="899" alt="Screen Shot 2022-03-31 at 18 13 50" src="https://user-images.githubusercontent.com/22454918/161112867-ba48fdf6-42ee-4cd3-9e1a-7118c4a2738b.png">

---

#### 自定义区域

![custom area](https://user-images.githubusercontent.com/22454918/118527523-4d219f00-b739-11eb-889f-60fb06fd71bc.png)

参见 `:help bufferline-custom-areas`

## 如何按标签页只显示对应的 buffer？

这一行为**并非 Neovim 原生支持**。你可以配合
[scope.nvim](https://github.com/tiagovla/scope.nvim) 与本插件实现——参见
[常见问题与注意事项](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-FAQ-and-Caveats)。

## 注意事项

本插件对 tabline 外观有明确主张，依赖配色方案设置的基础高亮（`Normal`、`String`、
`TabLineSel`、`Comment`），并依赖「变暗」处理，因此低对比度配色效果不佳。完整列表：
[常见问题与注意事项](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-FAQ-and-Caveats#注意事项)。

## 常见问题

- **为什么 bufferline 没有出现？** 通常是与其他 tabline 插件冲突（`airline`、`lightline`、
  `GuiTabline`）。
- **这个插件是否违背了「vim 之道」？** 简短回答：并没有。

完整解答见
[常见问题与注意事项](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-FAQ-and-Caveats)。

## 测试

在仓库根目录执行：

```sh
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

离线运行时，将 `NVIM_TEST_DEPS` 指向包含现有 `plenary.nvim` 与 `nvim-web-devicons` 检出目录的
路径。测试多行功能时请使用 Neovim 0.12+。文档也有自己的、仅依赖标准库的检查：

```sh
python3 scripts/gen_help.py --check
python3 scripts/test_docs.py
```

参见
[测试与开发](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Testing-and-Development)
与[文档流水线](https://github.com/MOSconfig/bufferline.nvim/wiki/zh-CN-Documentation-Pipeline)。
