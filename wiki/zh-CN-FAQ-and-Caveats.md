# 常见问题与注意事项

## 如何按标签页只显示对应的 buffer？

这一行为**并非 Neovim 原生支持**——Neovim 内部没有「buffer 归属于某个标签页」的概念，因为标签页
并非如此设计。它们展示的是每个标签页中任意布局的窗口。

你可以配合 [scope.nvim](https://github.com/tiagovla/scope.nvim) 与本插件实现该效果；不过对需要
此功能的用户来说，更好的长期方案是向上游争取真正的原生支持。

## 为什么 bufferline 没有出现？

最常见的原因是与其他插件冲突。请确认你没有安装另一个 bufferline 类插件。

- 使用 `airline` 时，设置 `let g:airline#extensions#tabline#enabled = 0`。
- `lightline` 默认也会接管 tabline，需要将其停用。
- 在 Windows 上使用 GUI 版 nvim（`nvim-qt.exe`）时，请确保 `GuiTabline` 已禁用：在 nvim 配置
  目录中创建 `ginit.vim`，写入 `GuiTabline 0`。否则 QT 的 tabline 会覆盖任何终端 tabline。

启用[多行模式](zh-CN-Multiline-Buffer-Tabs)时，header 暂时不可用期间 tabline 为空属于预期行为
——不存在回退到原生单行的机制，恢复由事件驱动。

## 这个插件是否违背了「vim 之道」？

[buftabline 作者的说明](https://github.com/ap/vim-buftabline#why-this-and-not-vim-tabs)
解释得更清楚。简而言之：在 nvim 中 buffer 代表文件，而标签页代表一组窗口。Vim 原生支持可视化
标签页，却不支持仅展示已打开的文件。围绕该话题有_无休止_的争论，但让用户看到自己打开了哪些文件
并不违背任何明确表述的 vim 哲学。它是一个文本编辑器，不是一种宗教 🙏。

## 注意事项

- 它不会符合所有人的审美。本插件对 tabline 的外观有明确主张，很难让每个人都满意。
- 为避免维护负担过重，维护者对新增功能持保守态度。
- 本插件依赖配色方案设置的一些基础高亮，即 `Normal`、`String`、`TabLineSel`（回退为
  `WildMenu`）和 `Comment`，因此未必适配所有配色方案。你可以手动覆盖颜色，或在加载本插件前
  手动创建这些高亮组。
- 如果配色方案对比度不高（例如纯黑配色），部分高亮将无法达到预期效果，因为它们依赖于「变暗」
  处理。

## 多行模式的专有限制

自定义区域、悬停展开与原生标签页控件仅限单行模式。header 会占用真实的分割高度与一条分隔线。
用户的鼠标映射保持优先权。保存内置会话前请先禁用多行。只要多行处于启用状态，就不存在回退到
原生单行的机制。完整契约见[多行 buffer 标签](zh-CN-Multiline-Buffer-Tabs)。

## 问题反馈

上游行为相关的问题请提交到
<https://github.com/akinsho/bufferline.nvim/issues>；本分支多行功能相关的问题请提交到本分支的
issue 跟踪器。
