describe("Multiline segment adaptation", function()
  local ui, config
  before_each(function()
    config = require("bufferline.config")
    config.setup({ options = { show_buffer_icons = false } })
    config.apply()
    ui = require("bufferline.ui")
  end)

  it("preserves literal text and structured click actions", function()
    local component = { id = 4, focusable = true, current = function() return true end }
    local segments = {
      ui.make_clickable("handle_click", 4, { attr = { global = true } }),
      { text = "100%%.lua", plain_text = "100%.lua", highlight = "Name" },
      ui.make_clickable("handle_close", 4, { text = "x", highlight = "Close" }),
    }
    local entry = ui.multiline_entry(component, segments)
    assert.same(4, entry.id)
    assert.is_true(entry.current)
    assert.same("100%.lua", entry.runs[1].text)
    assert.same({ kind = "click", id = 4 }, entry.runs[1].action)
    assert.same({ kind = "close", id = 4 }, entry.runs[2].action)
    assert.is_nil(entry.runs[1].prefix)
  end)

  it("resolves highlight extensions without changing native text", function()
    local segments = {
      { text = "icon", highlight = "Pinned", attr = { extends = { { id = "name" } } } },
      { text = "file", highlight = "Normal", attr = { __id = "name" } },
    }
    local entry = ui.multiline_entry({ id = 1, current = function() return false end }, segments)
    assert.same("Pinned", entry.runs[2].highlight)
    assert.same("Normal", segments[2].highlight)
  end)

  it("inherits the preceding highlight for implicit spacing segments", function()
    local entry = ui.multiline_entry({ id = 1, current = function() return true end }, {
      { text = "name", highlight = "Selected" },
      { text = " " },
      { text = "x", highlight = "Close" },
      { text = " " },
    })
    assert.same("Selected", entry.runs[2].highlight)
    assert.same("Close", entry.runs[4].highlight)
  end)

  it("keeps group markers actionable without counting them as buffers", function()
    local marker = { focusable = false, current = function() return false end }
    local segments = {
      { text = "Pinned", highlight = "Group" },
      ui.make_clickable("handle_group_click", 1, { attr = { global = true } }),
    }
    local entry = ui.multiline_entry(marker, segments)
    assert.is_false(entry.focusable)
    assert.same({ kind = "group", id = 1 }, entry.runs[1].action)
  end)
end)
