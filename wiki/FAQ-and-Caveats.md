# FAQ and Caveats

## How do I see only buffers per tab?

This behaviour is _not native in Neovim_ — there is no internal concept of buffers
localised to tabs, because that is not how tabs were designed to work. They show an
arbitrary layout of windows per tab.

You can get this behaviour using [scope.nvim](https://github.com/tiagovla/scope.nvim)
alongside this plugin, although a better long-term solution for users who want this is to
ask for real native support upstream.

## Why isn't the bufferline appearing?

The most common cause is a clash with another plugin. Make sure you do not have another
bufferline plugin installed.

- With `airline`, set `let g:airline#extensions#tabline#enabled = 0`.
- `lightline` also takes over the tabline by default and needs to be deactivated.
- On Windows with the GUI version of nvim (`nvim-qt.exe`), ensure `GuiTabline` is
  disabled: create `ginit.vim` in your nvim config directory containing `GuiTabline 0`.
  Otherwise the QT tabline overlays any terminal tabline.

With [multiline](Multiline-Buffer-Tabs) enabled, an empty tabline is expected while the
header is temporarily unavailable — there is no native single-row fallback. Recovery is
event-driven.

## Doesn't this plugin go against the "vim way"?

This is much better explained by
[buftabline's author](https://github.com/ap/vim-buftabline#why-this-and-not-vim-tabs).
The short answer: buffers represent files in nvim, and tabs a collection of windows. Vim
natively allows visualising tabs, but not just the files that are open. There are
_endless_ debates on this topic, but allowing a user to see what files they have open
doesn't go against any clearly stated vim philosophy. It's a text editor and not a
religion 🙏.

## Caveats

- This won't appeal to everyone's tastes. This plugin is opinionated about how the
  tabline looks, and it's unlikely to please everyone.
- To prevent this becoming a pain to maintain, the maintainers are conservative about
  what gets added.
- This plugin relies on some basic highlights being set by your colour scheme, i.e.
  `Normal`, `String`, `TabLineSel` (`WildMenu` as fallback) and `Comment`. It's unlikely
  to work with all colour schemes. You can manually override the colours or create these
  highlight groups before loading this plugin.
- If the contrast in your colour scheme isn't very high — think an all-black colour
  scheme — some highlights won't work as intended, since they depend on darkening things.

## Multiline-specific limits

Custom areas, hover reveal and native tabpage controls are single-row only. The header
consumes real split height and a divider. User mouse mappings retain precedence. Disable
multiline before saving a built-in session. There is no native single-row fallback while
multiline is enabled. Full contract: [Multiline Buffer Tabs](Multiline-Buffer-Tabs).

## Issues

Please raise any issues you encounter at
<https://github.com/akinsho/bufferline.nvim/issues> for upstream behaviour, or in this
fork's tracker for fork-specific multiline behaviour.
