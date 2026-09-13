# 功能

- 尽可能从配色方案中取色。
- 按 `extension`、`directory` 或自定义比较函数对 buffer 排序。
- 通过 Lua 函数配置，获得更高的自定义程度。

另见：[多行 buffer 标签](zh-CN-Multiline-Buffer-Tabs)。

## 其他样式

### 斜切标签

![slanted tabs](https://user-images.githubusercontent.com/22454918/111992989-fec39b80-8b0d-11eb-851b-010641196a04.png)

**注意**：某些终端需要对特殊字符做额外填充，若在你的终端模拟器中显示不正确，请将样式设为
`padded_slant`。效果因终端模拟器而异，该样式可能并非在所有终端下都可用。

### 倾斜标签

![sloped tabs](https://user-images.githubusercontent.com/22454918/220115787-0ba2264f-1cf5-4f18-a322-7c7cfa3d8f42.png)

参见 `:help bufferline-styling`。

## 悬停事件

**注意**：仅在 Neovim 0.8+ 可用。[多行模式](zh-CN-Multiline-Buffer-Tabs)不支持该功能。

![hover-event-preview](https://user-images.githubusercontent.com/22454918/189106657-163b0550-897c-42c8-a571-d899bdd69998.gif)

参见 `:help bufferline-hover-events`。

## 下划线指示器

<img width="1355" alt="Screen Shot 2022-08-22 at 09 14 24" src="https://user-images.githubusercontent.com/22454918/185873089-2ae20db0-f292-4d96-afe4-ef0683a60709.png">

效果取决于你的终端模拟器。上图是在 kitty nightly（2022 年 8 月版本）中实现的，并调大了下划线
粗细与下划线位置，使其离文字更远。

## 标签页

<img width="800" alt="Screen Shot 2022-03-08 at 17 39 57" src="https://user-images.githubusercontent.com/22454918/157337891-1848da24-69d6-4970-96ee-cf65b2a25c46.png">

将 `mode` 选项设为 `tabs` 可以只显示标签页。这会把 bufferline 变成一个 tabline，保留了大部分
（但不是全部）功能与样式：

- 排序尚不可用，这部分仍需仔细设计。
- 分组同样尚不可用，原因相同。

多行模式不支持 `mode = "tabs"`。

## LSP 指示器

![LSP Indicator](https://user-images.githubusercontent.com/22454918/113215394-b1180300-9272-11eb-9632-8a9f9aae99fa.png)

设置 `diagnostics = "nvim_lsp" | "coc"` 后，任何存在错误的 buffer 都会显示指示器，让你一眼看出
哪些 buffer 受影响。

用函数自定义计数的呈现方式：

```lua
--- count is an integer representing total count of errors
--- level is a string "error" | "warning"
--- diagnostics_dict is a dictionary from error level ("error", "warning" or "info") to number of errors for each level.
--- this should return a string
--- Don't get too fancy as this function will be executed a lot
diagnostics_indicator = function(count, level, diagnostics_dict, context)
  local icon = level:match("error") and " " or " "
  return " " .. icon .. count
end
```

![diagnostics_indicator](https://user-images.githubusercontent.com/4028913/112573484-9ee92100-8da9-11eb-9ffd-da9cb9cae3a6.png)

```lua
diagnostics_indicator = function(count, level, diagnostics_dict, context)
  local s = " "
  for e, n in pairs(diagnostics_dict) do
    local sym = e == "error" and " "
      or (e == "warning" and " " or " ")
    s = s .. n .. sym
  end
  return s
end
```

也可以根据 buffer 上下文有条件地显示指示器。例如对当前 buffer 关闭指示，只为其他 buffer 显示：

```lua
diagnostics_indicator = function(count, level, diagnostics_dict, context)
  if context.buffer:current() then
    return ''
  end

  return ''
end
```

![current](https://user-images.githubusercontent.com/58056722/119390133-e5d19500-bccc-11eb-915d-f5d11f8e652c.jpeg)
![visible](https://user-images.githubusercontent.com/58056722/119390136-e66a2b80-bccc-11eb-9a87-e622e3e20563.jpeg)

第一条 bufferline 中 `diagnostic.lua` 是 `current` buffer。它有 LSP 报告的错误，但并未显示。
第二条中 `500-nvim-bufferline.lua` 成为 `current`；由于「有问题的」`diagnostic.lua` 从
`current` 变为 `visible`，其指示器随即出现。

错误状态下文件名的高亮可通过 `:help bufferline-highlights` 调整。

## 分组

![bufferline_group_toggle](https://user-images.githubusercontent.com/22454918/132410772-0a4c0b95-63bb-4281-8a4e-a652458c3f0f.gif)

分组把相关的 buffer 聚成一簇，并允许对它们整体操作——例如点击分组指示器可隐藏该组全部 buffer。
其灵感部分来自 Chrome 的标签页以及 centaur-tabs 的分组。

参见 `:help bufferline-groups`。

## 侧边栏偏移

![explorer header](https://user-images.githubusercontent.com/22454918/117363338-5fd3e280-aeb4-11eb-99f2-5ec33dff6f31.png)

参见 `:help bufferline-sidebar-offset`。偏移仅作用于原生 tabline；多行模式使用其编辑分割窗口的
实际宽度。

## 编号

![bufferline with numbers](https://user-images.githubusercontent.com/22454918/119562833-b5f2c200-bd9e-11eb-81d3-06876024bf30.png)

使用 `numbers` 选项可为 buffer 名称添加 `ordinal` 或 `buffer id` 前缀，取值为 `buffer_id`、
`ordinal` 或一个函数。

![numbers](https://user-images.githubusercontent.com/22454918/130784872-936d4c55-b9dd-413b-871d-7bc66caf8f17.png)

参见 `:help bufferline-numbers`。

## 唯一名称

![duplicate names](https://user-images.githubusercontent.com/22454918/111993343-6da0f480-8b0e-11eb-8d93-44019458d2c9.png)

## 关闭图标

![close button](https://user-images.githubusercontent.com/22454918/111993390-7a254d00-8b0e-11eb-9951-43b4350f6a29.gif)

## 重新排序

![re-order buffers](https://user-images.githubusercontent.com/22454918/111993463-91643a80-8b0e-11eb-87f0-26acfe92c021.gif)

该顺序可以跨会话保持（默认启用）。

## 拾取

![bufferline pick](https://user-images.githubusercontent.com/22454918/111993296-5bbf5180-8b0e-11eb-9ad9-fcf9619436fd.gif)

参见 `:help bufferline-pick`。

## 固定

<img width="899" alt="Screen Shot 2022-03-31 at 18 13 50" src="https://user-images.githubusercontent.com/22454918/161112867-ba48fdf6-42ee-4cd3-9e1a-7118c4a2738b.png">

## 自定义区域

![custom area](https://user-images.githubusercontent.com/22454918/118527523-4d219f00-b739-11eb-889f-60fb06fd71bc.png)

参见 `:help bufferline-custom-areas`。自定义区域仅限单行模式，多行模式不支持。
