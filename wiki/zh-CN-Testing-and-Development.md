# 测试与开发

所有命令均在仓库根目录执行。

## 完整测试套件

缺失的依赖会被下载到已被 gitignore 的 `.tests/` 目录：

```sh
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"
```

## 离线测试

将 `NVIM_TEST_DEPS` 指向一个同时包含 `plenary.nvim` 与 `nvim-web-devicons` 检出目录的路径。
该模式**不会**下载缺失依赖，而是直接失败：

```sh
export NVIM_TEST_DEPS="$HOME/.local/share/nvim/lazy"
nvim --headless -i NONE -n -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua', sequential=true}"
```

## 单文件测试

```sh
nvim --headless -i NONE -n -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/multiline_layout_spec.lua {minimal_init='tests/minimal_init.lua', sequential=true}"
```

测试多行功能时请使用 Neovim 0.12+。

## 文档测试

文档流水线有自己的测试，仅依赖 Python 标准库：

```sh
python3 scripts/gen_help.py --check   # 生成的帮助文件与源文件一致
python3 scripts/test_docs.py          # 漂移、链接与图片一致性
python3 scripts/test_wiki_sync.py     # wiki 发布安全性
```

参见[文档流水线](zh-CN-Documentation-Pipeline)。

## 易踩的坑

- 即使发生 Lua 错误，`nvim +lua ... +qa` 也可能以 0 退出。请使用显式的 `cquit 1` 失败路径。
- 单文件测试之后请运行完整套件，并同时检查错误输出与退出码。
- 自动化测试绝不要加载用户的实际配置；测试状态会被重定向到 `.tests/`。
- 在有 StyLua 时用 `stylua --check --config-path=stylua.toml lua/` 检查格式，并运行
  `git diff --check`。

## Agent 指南

贡献者与 AI 编码 agent 请阅读
[AGENTS.md](https://github.com/MOSconfig/bufferline.nvim/blob/HEAD/AGENTS.md)，
其中包含架构、兼容性边界、所有权安全与 PR 流程。

先执行指南中的只读检查，再按任务导航表查找设置、布局、渲染或输入对应的模块及回归测试。
`CLAUDE.md` 会加载这份共享指南；请集中维护 agent 规则，不要在多个工具专用的指令文件中
复制同一份内容，以免后续更新产生冲突。

仅修改文字时，运行上方三项文档检查与 `git diff --check`。修改 Lua 时，先补充失败的回归
测试，再运行单文件及完整套件。UI 或输入变更还需要隔离的交互式测试，不能只依赖无界面测试。
机器专用路径、下载的依赖和测试输出不要提交到版本库。

README 用于中英文功能介绍。详细设置与可运行示例写入配对的 wiki 页面，行为参考写入
`wiki/help/`。现有发布工作流在验证后，将 `wiki/` 下的 Markdown 页面发布到 GitHub wiki；
本地编辑本身不会更新在线 wiki。详见[文档流水线](zh-CN-Documentation-Pipeline)。
