# 多行 buffer 标签

多行渲染器为**可选启用**。原生单行渲染器仍是默认值，其默认设置与 Neovim 0.8+ 的最低要求
保持不变。多行渲染器要求 **Neovim 0.12+** 且 `options.mode = "buffers"`。

参考手册：`:help bufferline-multiline`。

## 试用

该功能没有指定发布版本。请指向本分支，而不是上游 tag：

```lua
{ "MOSconfig/bufferline.nvim", branch = "feat/multiline-buffer-tabs", dependencies = "nvim-tree/nvim-web-devicons" }
```

## 启用

`setup()` 接收一份**完整**配置，而非增量更新。请保留原始配置表，以便之后恢复原生设置：

```lua
local bufferline = require("bufferline")
local original_config = {
  options = {
    -- Keep all your existing options here.
  },
  -- Keep other existing setup fields, such as highlights, here too.
}
local multiline_config = vim.deepcopy(original_config)
multiline_config.options = multiline_config.options or {}
multiline_config.options.mode = "buffers"
multiline_config.options.multiline = { enabled = true, max_rows = 3 }
bufferline.setup(multiline_config)
```

`options.multiline.enabled` 默认为 `false`。`max_rows` 默认为 `3`，且必须是正整数。

## 恢复单行模式

请使用原始完整配置的副本，而不是只包含多行开关的表。这样也会恢复此前被移除的仅限原生模式
的设置：

```lua
local single_row = vim.deepcopy(original_config)
single_row.options = single_row.options or {}
single_row.options.multiline = single_row.options.multiline or {}
single_row.options.multiline.enabled = false
bufferline.setup(single_row)
```

## 兼容性

若未显式设置，`show_tab_indicators` 与全局的 `show_close_icon` 在多行模式下（且仅在该模式
下）会变为 `false`。显式设为 `true` 会被**拒绝**——请在多行配置副本中移除这些仅限原生模式
的覆盖项，或将其设为 `false`。每个 buffer 的关闭图标（`show_buffer_close_icons`）仍受支持。

多行模式不支持：`mode = "tabs"`、`custom_areas` 以及悬停展开。启用多行前请移除自定义区域并
关闭 `hover.enabled`。

## 布局

- header 是编辑区上方的一个预留分割窗口，而不是更高的原生 tabline。它会占用自身的 buffer
  行数，**外加** Neovim 常规的分割分隔线／状态栏空间。`max_rows` 仅限制 buffer 行数，不包含
  这部分额外空间。
- 全高侧边栏位于 header 区域之外。换行按 header 窗口的实际宽度计算；原生的侧边栏偏移不会在
  此重复。打开或调整侧边栏不会改变已有的窗口 ID。
- 该 scratch buffer 的 `filetype=bufferline`。文件浏览器应将此 filetype 排除在替换目标之外
  （Neo-tree：`open_files_do_not_replace_types`）。
- 将 `tab_size` 与 `enforce_regular_tabs = true`、`truncate_names = true` 搭配使用，可限制
  条目宽度并截断过长标题。换行取决于可用的编辑区宽度。
- Nerd Font 的 `` / `` 箭头会显示被隐藏的 buffer 数量，配合鼠标滚轮可滚动超出上限的行。
  切换当前 buffer 会使其所在行显现。
- Unicode 标签、图标、诊断、分组、固定，以及 buffer／关闭／分组的点击操作都可跨行工作。用户
  已有的鼠标映射会先执行，可能在 bufferline 处理之前消费掉点击或滚轮事件。

## 键盘导航

使用常规窗口导航进入 header（在下方编辑区按 `<C-w>k`）。以下 Normal 模式映射**只**存在于
header 的 scratch buffer 中，不会安装任何全局映射：

| 按键 | 操作 |
| --- | --- |
| `h` / `l` | 上一个／下一个候选 buffer（到两端不循环） |
| `j` / `k` | 下一／上一个已排布 buffer 行上最近的候选项，跳过仅含分组的行，并将隐藏行滚动到可见范围 |
| `<CR>` | 在记住的编辑窗口中执行该候选项配置的左键操作；若该窗口不可用则回退到另一个有效编辑窗口 |
| `<Esc>` | 返回该编辑窗口，不选择 buffer |
| `x` | 对候选项执行 `close_command`，但不激活它 |

**不存在 `q` 映射。** 上表即完整集合：`h`、`j`、`k`、`l`、`x`、`<CR>` 与 `<Esc>`。在 header
中，`q` 保持其通常的 Normal 模式含义，会开始录制宏。请使用 `<Esc>` 离开 header。

即使隐藏了关闭图标，`x` 依然有效。它会保持 header 焦点，并选中下一个仍存在的相邻项（位于末尾
时选择前一项）；若关闭被拒绝，则保留原候选项。请配置非强制的 `close_command` 以保护未保存的
buffer。

当前激活的条目整体使用 `BufferLineBufferSelected`；键盘候选项整体使用 `IncSearch`，包括图标、
内边距、分隔符与后缀。在按下 `<CR>` 之前，导航不会改变编辑区的 buffer。分组、关闭图标与溢出
控件不作为键盘候选项。候选 buffer 的 ID 在调整大小／重新排布后仍然保持；已被移除或隐藏的候选
项会回落到当前激活的 buffer。无论焦点在编辑区还是 header，滚轮滚动均有效，且不会选择 buffer。

## 生命周期与限制

`options.multiline.enabled` 是**唯一**的渲染器选择开关。只要它处于启用状态，原生单行就**永远
不会**重新出现——即使当前屏幕上没有 header 也是如此。不存在回退到原生单行的机制。只有以
`enabled = false` 调用 `setup()` 才能切换回去。「配置选择」与「当前是否就绪」是两件独立的事：

- **暂时不可用。** 当 header 无法绘制时（高度不足、框架不可用、分配失败），当 header 窗口被
  手动关闭或被 `:only` 关闭时，或当其他 buffer 占据了 header 窗口时，该标签页的 header 会被
  移除，tabline 留空。这只影响该标签页，其他标签页的 header 不受影响。
- **恢复由事件驱动。** 下一次 buffer、窗口、尺寸调整或刷新事件会重绘 header。没有轮询，也没有
  重试循环，无需再次调用 `setup()`。真正的渲染错误在每个故障阶段只报告一次；容量限制则完全
  不报告。
- **不可用期间的命令。** 当屏幕上没有 header 时，`:BufferLinePick` 及其他拾取类命令不会阻塞
  等待按键。它们会发出警告——`cannot pick while the multiline header is unavailable`——然后
  返回，而不是让你对着看不见的字母盲输。循环切换类命令（如 `:BufferLineCycleNext`）仍然可用：
  它们会在导航前重新计算当前状态，因此即使什么都没渲染，顺序依然正确。
- **退出。** 用 `:q` 关闭其中一个编辑分割窗口会**保留** header。当标签页的最后一个编辑窗口
  退出时，会先移除其 header，避免它阻挡退出。侧边栏和工具窗口不计为编辑窗口；
  是否自动关闭由各插件决定（例如 Neo-tree 的 `close_if_last_window`）。若退出被拒绝（例如未保存 buffer 的
  `E37`），布局稳定后 header 会被恢复。
- **在 header 中执行 `:q`。** 当焦点位于 header 时输入 `:q`，确实会关闭 header 窗口并让你回到
  编辑区；待布局稳定后 header 会被重新创建。
- **拆除时的焦点。** 当 header 处于焦点状态时禁用多行、加载会话或自动隐藏，都会返回到记住的
  合适编辑窗口（或另一个可用的编辑窗口）。拆除过程绝不会删除未保存的编辑 buffer。
- **API 关闭的限制。** 对最后一个编辑窗口执行 `:close`、`:hide` 或 API 关闭可能报告 `E855`。
  在最后一个标签页中，编辑窗口会保留；若还有其他标签页，Neovim 可能在报错的同时仍完成该标签页
  的关闭。日常退出请使用 `:q`。原生的未保存检查依然有效；启用 `hidden` 时，已修改的 buffer
  可以照常保持隐藏。
- **会话。** 加载会话会暂停多行渲染：在 `SessionLoadPost` 之前既没有 header 也没有原生单行，
  之后 header 会自行恢复。执行 `:mksession` 前请使用上文的完整单行配置禁用多行——默认的
  `'sessionoptions'` 包含 `blank`，可能会把匿名的 `nofile` header 窗口序列化进去。**不支持**
  透明的会话保存／恢复。
