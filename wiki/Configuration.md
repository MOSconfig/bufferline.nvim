# Configuration

## `setup()` takes a complete configuration

`require("bufferline").setup(config)` is **not** an incremental options update. Each
call receives a complete configuration. Keep your original table around so you can
restore settings later without losing custom options or highlights:

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

This matters most when toggling the [multiline renderer](Multiline-Buffer-Tabs), which
has native-only options you must remove from the multiline copy and restore afterwards.

## Where the reference lives

The full option table, defaults, types and validation rules are in the generated help
file, which is authored in [`wiki/help/`](Documentation-Pipeline):

```vim
:help bufferline-configuration
```

Topic-specific reference pages:

| Topic | Help tag |
| --- | --- |
| Hover events | `:help bufferline-hover-events` |
| Styling and presets | `:help bufferline-styling`, `:help bufferline-style-presets` |
| Tabpages | `:help bufferline-tabpages` |
| Numbers | `:help bufferline-numbers` |
| LSP diagnostics | `:help bufferline-diagnostics` |
| Groups | `:help bufferline-groups` |
| Sorting and filtering | `:help bufferline-sorting`, `:help bufferline-filtering` |
| Commands | `:help bufferline-commands` |
| Custom functions | `:help bufferline-functions` |
| Pick | `:help bufferline-pick` |
| Mappings | `:help bufferline-mappings` |
| Highlights | `:help bufferline-highlights` |
| Mouse actions | `:help bufferline-mouse-actions` |
| Custom areas | `:help bufferline-custom-areas` |
| Sidebar offsets | `:help bufferline-sidebar-offset` |

## Contributors and AI coding agents

Read [AGENTS.md](https://github.com/MOSconfig/bufferline.nvim/blob/HEAD/AGENTS.md) for
architecture, offline tests, compatibility boundaries and safe development workflows.
`CLAUDE.md` imports that shared guide for Claude Code.
