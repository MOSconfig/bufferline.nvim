# 配置

## `setup()` 接收一份完整配置

`require("bufferline").setup(config)` **不是**增量式的选项更新。每次调用都会接收一份完整
配置。请保留你原始的配置表，以便之后恢复设置而不丢失自定义选项或高亮：

```lua
local bufferline = require("bufferline")
local original_config = {
  options = {
    -- Keep all your existing options here.
  },
  -- Keep other setup fields, such as highlights, here too.
}
bufferline.setup(original_config)
```

这一点在切换[多行渲染器](zh-CN-Multiline-Buffer-Tabs)时尤为重要：有些仅限原生模式的选项
必须从多行配置副本中移除，之后再恢复。

## 参考手册所在位置

完整的选项表、默认值、类型与校验规则位于生成的帮助文件中，其撰写源文件在
[`wiki/help/`](zh-CN-Documentation-Pipeline)：

```vim
:help bufferline-configuration
```

按主题查阅：

| 主题 | 帮助标签 |
| --- | --- |
| 悬停事件 | `:help bufferline-hover-events` |
| 样式与预设 | `:help bufferline-styling`、`:help bufferline-style-presets` |
| 标签页 | `:help bufferline-tabpages` |
| 编号 | `:help bufferline-numbers` |
| LSP 诊断 | `:help bufferline-diagnostics` |
| 分组 | `:help bufferline-groups` |
| 排序与过滤 | `:help bufferline-sorting`、`:help bufferline-filtering` |
| 命令 | `:help bufferline-commands` |
| 自定义函数 | `:help bufferline-functions` |
| 拾取 | `:help bufferline-pick` |
| 映射 | `:help bufferline-mappings` |
| 高亮 | `:help bufferline-highlights` |
| 鼠标操作 | `:help bufferline-mouse-actions` |
| 自定义区域 | `:help bufferline-custom-areas` |
| 侧边栏偏移 | `:help bufferline-sidebar-offset` |

## 贡献者与 AI 编码 agent

请阅读
[AGENTS.md](https://github.com/MOSconfig/bufferline.nvim/blob/HEAD/AGENTS.md)，
其中说明了架构、离线测试、兼容性边界与安全的开发流程。`CLAUDE.md` 为 Claude Code 引入了
这份共享指南。
