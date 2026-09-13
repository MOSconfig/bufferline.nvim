# 文档流水线

本 wiki 是该分支**唯一的文档撰写来源**。`doc/` 下没有任何手写内容。

## 目录结构

| 路径 | 作用 |
| --- | --- |
| `wiki/*.md` | 英文指南（发布为 wiki 页面） |
| `wiki/zh-CN-*.md` | 中文指南（发布为 wiki 页面） |
| `wiki/help/*.txt` | Vim 帮助片段——参考手册的撰写源 |
| `doc/bufferline.txt` | **生成**的产物，已提交到 Git |
| `scripts/gen_help.py` | 生成器（仅依赖标准库） |
| `scripts/test_docs.py` | 文档测试（仅依赖标准库） |

`doc/bufferline.txt` 保持提交状态，因此未获取 wiki 的用户安装插件后仍可使用
`:help bufferline.nvim`。

## 生成

```sh
python3 scripts/gen_help.py          # 重写 doc/bufferline.txt
python3 scripts/gen_help.py --check  # 若不同步则失败
```

生成器按文件名顺序拼接 `wiki/help/*.txt`，之间以单个换行连接。它是确定性的：相同的源文件
始终产生逐字节相同的输出，不含时间戳或依赖具体机器的值。章节顺序由文件名的数字前缀决定，
因此调整顺序意味着重命名文件。

## 编辑参考手册

编辑 `wiki/help/` 中的片段，然后重新生成：

```sh
$EDITOR wiki/help/05-multiline-buffer-tabs.txt
python3 scripts/gen_help.py
python3 scripts/test_docs.py
```

切勿直接编辑 `doc/bufferline.txt`——下一次生成会覆盖它，在此之前 `--check` 也会失败。

编辑时请保持帮助标签（`*bufferline-...*`）完整；`wiki/help/01-contents.txt` 中的目录会列出
这些标签，测试会检查其中引用的每个标签都确实存在。

## 测试

`scripts/test_docs.py` 会检查：

- **生成漂移**——`doc/bufferline.txt` 与源文件逐字节一致。
- **确定性**——连续生成两次输出完全相同。
- **标签完整性**——目录中列出的每个帮助标签都有定义，且分支专有标签得到保留。
- **双语一致性**——每个英文 wiki 页面都有对应的 `zh-CN-` 页面，且两者包含相同的图片 URL 集合。
- **链接一致性**——README 与其中文版指向相同的 wiki 页面，且每个 wiki 内部链接都能解析到实际
  存在的页面。
- **契约准确性**——文档不会重新引入「header 定义了 `q` 映射」这一已废弃的说法。

使用 `python3 scripts/test_docs.py` 运行。它只需要 Python 标准库。

## 发布

`.github/workflows/wiki-release.yml` 会在发布 release 时，或在手动指定 ref 触发时，将
`wiki/` 发布到 GitHub wiki。

工作流成功运行的前提条件：

1. **wiki 必须已存在并完成初始化。** 在通过网页界面保存第一个页面之前，GitHub 不会创建
   `<repo>.wiki.git` 仓库。请打开仓库的 **Wiki** 标签页并创建任意一个页面。在此之前，克隆
   步骤会失败。
2. **需要 `WIKI_TOKEN` secret。** 工作流内置的 `GITHUB_TOKEN` 不覆盖 wiki 推送。请创建一个
   具备该仓库 wiki 写权限的专用令牌，并存为仓库 secret `WIKI_TOKEN`。该 secret 是可选的：
   若未配置，工作流会校验源文件并在任何推送之前停止，而不是失败。

发布使用通过校验的确切提交 SHA，而非可能移动的分支名。源页面或目标页面是符号链接时会拒绝发布。
工作流不强制推送，不将令牌放入 URL；令牌遮蔽指令由 Actions 处理。
英文 Vim 参考手册与双语指南分别维护；`--check` 检查生成帮助的字节一致性，不能验证翻译的语义一致性。
存在于 wiki 但不在 `wiki/` 中的页面
不会被改动，因此手工撰写的 wiki 页面得以保留。
