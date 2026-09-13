# Multiline Buffer Tabs

Multiline is **opt-in**. The native single-row renderer remains the default, with its
existing defaults and Neovim 0.8+ minimum unchanged. Multiline requires **Neovim 0.12+**
and `options.mode = "buffers"`.

Reference: `:help bufferline-multiline`.

## Trying it

Multiline is available on this fork's `main` branch, not in upstream tags. Use this
standalone lazy.nvim spec for a fresh configuration:

```lua
{
  "MOSconfig/bufferline.nvim",
  branch = "main",
  dependencies = "nvim-tree/nvim-web-devicons",
  init = function()
    vim.opt.termguicolors = true
  end,
  opts = {
    options = {
      mode = "buffers",
      multiline = { enabled = true, max_rows = 3 },
    },
  },
}
```

If you already configure bufferline, replace its plugin source and merge these options
into your existing complete configuration; do not register two copies of the plugin.
The README preview uses a custom colorscheme and slanted separators. Add
`separator_style = "slant"` inside `options` for that separator shape; the snippet above
does not replace your colorscheme.

## Enabling

`setup()` takes a **complete** configuration, not an incremental update. Keep the
original table so you can restore native settings later:

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

`options.multiline.enabled` defaults to `false`. `max_rows` defaults to `3` and must be a
positive integer.

## Restoring single-row mode

Use a copy of the original complete configuration, not just a table containing the
multiline flag. This also restores any native-only settings you removed:

```lua
local single_row = vim.deepcopy(original_config)
single_row.options = single_row.options or {}
single_row.options.multiline = single_row.options.multiline or {}
single_row.options.multiline.enabled = false
bufferline.setup(single_row)
```

## Compatibility

When omitted, `show_tab_indicators` and the global `show_close_icon` become `false` in
multiline mode only. Explicit `true` values are **rejected** — remove those native-only
overrides or set them to `false` in the multiline copy. Per-buffer close icons
(`show_buffer_close_icons`) remain supported.

Unsupported with multiline: `mode = "tabs"`, `custom_areas`, and hover reveal. Remove
custom areas and disable `hover.enabled` before enabling multiline.

## Layout

- The header is a reserved split above the editor, not a taller native tabline. It
  consumes its buffer rows **plus** Neovim's normal split separator/statusline space.
  `max_rows` caps the buffer rows only, not that extra space.
- Full-height sidebars remain outside the header area. Wrapping uses the header window's
  actual width; native sidebar offsets are not repeated there. Opening or resizing a
  sidebar keeps existing window IDs intact.
- The scratch buffer has `filetype=bufferline`. File explorers should exclude this
  filetype from replacement targets (Neo-tree: `open_files_do_not_replace_types`).
- Set `tab_size` with `enforce_regular_tabs = true` and `truncate_names = true` to keep
  entries bounded and trim long titles. Available editor width determines wrapping.
- Nerd Font chevrons `` / `` with hidden-buffer counts and the mouse wheel scroll
  rows beyond the cap. Changing the current buffer reveals its row.
- Unicode labels, icons, diagnostics, groups, pins, and buffer/close/group click actions
  work across rows. Existing user mouse mappings run first and may consume a click or
  wheel event before bufferline handles it.

## Keyboard navigation

Enter the header with normal window navigation (`<C-w>k` from the editor below it). Only
the header scratch buffer carries these Normal-mode maps — no global mappings are
installed:

| Key | Action |
| --- | --- |
| `h` / `l` | Previous / next buffer candidate (no wrap at the ends) |
| `j` / `k` | Nearest candidate on the next / previous packed buffer row, skipping group-only rows and scrolling hidden rows into view |
| `<CR>` | Run the candidate's configured left-click action in the captured editor window, falling back to another valid editor |
| `<Esc>` | Return to that editor without selecting a buffer |
| `x` | Run `close_command` on the candidate without activating it |

**There is no `q` mapping.** The five rows above are the complete set: `h`, `j`, `k`,
`l`, `x`, `<CR>` and `<Esc>`. In the header, `q` keeps its usual Normal-mode meaning and
starts a macro recording. Use `<Esc>` to leave the header.

`x` works even with close icons hidden. It retains header focus and selects the next
surviving neighbor (previous at the end); a refused close retains the candidate.
Configure a non-forced `close_command` to protect unsaved buffers.

The whole active entry uses `BufferLineBufferSelected`; the whole keyboard candidate uses
`IncSearch`, including icons, padding, separators and suffixes. Navigation does not change
the editor buffer until `<CR>`. Groups, close icons and overflow controls are not keyboard
candidates. Candidate buffer IDs survive resize/repacking; removed or hidden candidates
reconcile to the active buffer. Wheel scrolling works with either editor or header focus
and does not select a buffer.

## Lifecycle and limitations

`options.multiline.enabled` is the **only** renderer selector. While it is enabled the
native single row **never** reappears — not even while no header is on screen. There is
no native single-row fallback. Only `setup()` with `enabled = false` switches back.
Configured selection and momentary readiness are separate concerns:

- **Temporarily unavailable.** The header for a tabpage is removed and the tabline left
  empty when it cannot be drawn (too little height, an unusable frame, a failed
  allocation), when the header window is closed manually or by `:only`, or when a foreign
  buffer takes over the header window. Only that tabpage is affected; other tabpages keep
  their headers.
- **Recovery is event-driven.** The next buffer, window, resize or refresh event redraws
  the header. There is no polling and no retry loop, and `setup()` does not need to be
  called again. A genuine rendering error is reported once per failing episode; capacity
  limits are not reported at all.
- **Commands while unavailable.** `:BufferLinePick` and the other pick commands do not
  block for a keypress when no header is on screen. They warn with
  `cannot pick while the multiline header is unavailable`
  and return, instead of waiting for input against
  letters you cannot see. Cycling commands such as `:BufferLineCycleNext` keep working:
  they recompute the current state before navigating, so ordering stays correct even when
  nothing is rendered.
- **Quitting.** Closing one editor split with `:q` **keeps** the header. When the last
  editor of a tabpage quits, its header is removed first so the header cannot block quitting.
  Sidebars and utility windows do not count as editors; their own plugins decide whether
  to close them (for example Neo-tree's `close_if_last_window`). A
  refused quit (for example `E37` for an unsaved buffer) restores the header once the
  layout settles.
- **`:q` in the header.** Typing `:q` while the header is focused does close the header
  window and return you to the editor; the header is recreated once the layout settles.
- **Teardown focus.** Disabling, session loading, or auto-hide while the header is focused
  returns to the remembered eligible editor (or another available editor). Unsaved editor
  buffers are never deleted by teardown.
- **API close limits.** `:close`, `:hide`, or an API close of the last editing window can
  report `E855`. In the last tabpage the editing window remains; with other tabs open,
  Neovim may finish closing that tab despite the error. Use `:q` for ordinary quitting.
  Native unsaved-change checks remain in effect; with `hidden` enabled, modified buffers
  can remain hidden as usual.
- **Sessions.** Loading a session pauses multiline: no header and no native row until
  `SessionLoadPost`, after which the header returns on its own. Disable multiline before
  `:mksession` using the complete single-row configuration above — the default
  `'sessionoptions'` includes `blank`, which can serialize the anonymous `nofile` header
  window. Transparent session save/restore is **not supported**.
