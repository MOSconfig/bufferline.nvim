# bufferline.nvim (MOSconfig fork)

A _snazzy_ 💅 buffer line (with tabpage integration) for Neovim built using **lua**.

This wiki is the **only authored documentation source** for this fork. The Vim help
file `doc/bufferline.txt` is generated from [`wiki/help/`](Documentation-Pipeline) and
committed to Git so `:help bufferline.nvim` works for every install.

中文文档: [中文首页](zh-CN-Home)

## Guides

| Page | What it covers |
| --- | --- |
| [Installation and Usage](Installation-and-Usage) | Requirements, plugin managers, first setup |
| [Configuration](Configuration) | `setup()` semantics, where options live |
| [Multiline Buffer Tabs](Multiline-Buffer-Tabs) | The opt-in multi-row renderer and its full contract |
| [Features](Features) | Styling, diagnostics, groups, picking, pinning, offsets |
| [FAQ and Caveats](FAQ-and-Caveats) | Common breakage and known limits |
| [Testing and Development](Testing-and-Development) | Offline test runs, agent guide |
| [Documentation Pipeline](Documentation-Pipeline) | How the wiki generates and publishes the help file |

## Reference

The complete option, highlight, command and mapping reference lives in the generated
Vim help file. Read it in Neovim:

```vim
:help bufferline.nvim
:help bufferline-configuration
:help bufferline-multiline
```

The authored source for that reference is [`wiki/help/`](Documentation-Pipeline) in the
repository. Edit the fragments there, never `doc/bufferline.txt`.

## Upstream

This is the `MOSconfig/bufferline.nvim` fork of
[`akinsho/bufferline.nvim`](https://github.com/akinsho/bufferline.nvim). Upstream
attribution and the license are retained.
