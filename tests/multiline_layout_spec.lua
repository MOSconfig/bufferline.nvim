local function entry(id, text)
  return {
    id = id,
    component = { id = id },
    current = false,
    focusable = true,
    runs = { { text = text, highlight = "Tab", action = { kind = "click", id = id } } },
  }
end

local function geometry(width, max_rows)
  return { width = width, max_rows = max_rows, fill_hl = "Fill", marker_hl = "Marker" }
end

describe("Multiline layout", function()
  it("exposes deduplicated packed buffer positions with visible Unicode byte offsets", function()
    local first = entry(1, "界")
    first.runs[2] = { text = "é", highlight = "Tab", action = { kind = "click", id = 1 } }
    first.runs[3] = { text = "x", highlight = "Close", action = { kind = "close", id = 1 } }
    local group = entry(99, "group---")
    group.focusable = false
    group.runs[1].action = { kind = "group", id = 99 }
    local entries = { first, entry(2, "bb"), group, entry(3, "33333333"), entry(4, "44444444") }
    local geo = geometry(17, 1)
    geo.left = { text = "界", width = 3 }
    local plan = require("bufferline.multiline.layout").plan
    local frame = plan(entries, geo, { first_row = 1 })
    assert.same({
      { id = 1, row = 1, col = 6, byte_col = 7, byte_end = 14 },
      { id = 2, row = 1, col = 10, byte_col = 14, byte_end = 16 },
      { id = 3, row = 3, col = 6 },
      { id = 4, row = 4, col = 6 },
    }, frame.positions)
    local scrolled = plan(entries, geo, { first_row = 3 })
    assert.same({ id = 1, row = 1, col = 6 }, scrolled.positions[1])
    assert.same({ id = 3, row = 3, col = 6, byte_col = 9, byte_end = 17 }, scrolled.positions[3])
    assert.same({}, plan({}, geo).positions)
  end)

  it("highlights whole entries without absorbing neighboring entries or gutters", function()
    local item = entry(1, "界")
    table.insert(item.runs, 1, { text = "┃ ", highlight = "Separator" })
    item.runs[#item.runs + 1] = { text = " × ", highlight = "Close", action = { kind = "close", id = 1 } }
    local frame = require("bufferline.multiline.layout").plan({ item, entry(2, "two") }, geometry(20, 1), {})
    assert.equals(0, frame.positions[1].byte_col)
    assert.equals(#"┃ 界 × ", frame.positions[1].byte_end)
    assert.equals(#"┃ 界 × ", frame.positions[2].byte_col)
    local clipped = require("bufferline.multiline.layout").plan({ item }, geometry(4, 1), {})
    assert.equals(0, clipped.positions[1].byte_col)
    assert.equals("┃ … ", clipped.rows[1].text)
    assert.equals(#"┃ …", clipped.positions[1].byte_end)
  end)

  it("keeps exact-fit entries on one row without overflow controls", function()
    local entries = { entry(1, "aa"), entry(2, "bbb") }
    local frame = require("bufferline.multiline.layout").plan(entries, geometry(5, 1), {})

    assert.equal(1, #frame.rows)
    assert.equal("aabbb", frame.rows[1].text)
    assert.equal(1, frame.total_rows)
    assert.equal(1, frame.first_row)
    assert.equal(0, frame.before_count)
    assert.equal(0, frame.after_count)
    assert.equal(entries[1].component, frame.visible_components[1])
    assert.equal(entries[2].component, frame.visible_components[2])
    assert.same({
      { start_col = 0, end_col = 2, kind = "click", id = 1 },
      { start_col = 2, end_col = 5, kind = "click", id = 2 },
    }, frame.rows[1].hits)
  end)

  it("packs whole entries greedily and pads each row with fill highlights", function()
    local entries = { entry(1, "aaa"), entry(2, "bb"), entry(3, "cc") }
    local frame = require("bufferline.multiline.layout").plan(entries, geometry(4, 3), {})

    assert.same({ "aaa ", "bbcc" }, { frame.rows[1].text, frame.rows[2] and frame.rows[2].text })
    assert.equal(2, frame.total_rows)
    assert.same({
      { start_col = 0, end_col = 3, highlight = "Tab" },
      { start_col = 3, end_col = 4, highlight = "Fill" },
    }, frame.rows[1].spans)
    assert.same({
      { start_col = 0, end_col = 2, kind = "click", id = 2 },
      { start_col = 2, end_col = 4, kind = "click", id = 3 },
    }, frame.rows[2].hits)
    assert.same({ entries[1].component, entries[2].component, entries[3].component }, frame.visible_components)
  end)

  it("caps overflow rows, preserves wheel position, and counts hidden buffers", function()
    local entries = {}
    for id = 1, 5 do
      entries[id] = entry(id, string.rep(tostring(id), 8))
    end
    entries[5].current = true
    local frame = require("bufferline.multiline.layout").plan(entries, geometry(14, 2), {
      first_row = 3,
      current_id = 5,
      reveal = false,
    })

    assert.equal(2, #frame.rows)
    assert.equal(5, frame.total_rows)
    assert.equal(3, frame.first_row)
    assert.equal(2, frame.before_count)
    assert.equal(1, frame.after_count)
    assert.equal("2 33333333   ", frame.rows[1].text)
    assert.equal("   44444444 1", frame.rows[2].text)
    assert.same({ entries[3].component, entries[4].component }, frame.visible_components)
    assert.same({ start_col = 0, end_col = 3, kind = "scroll", direction = -1 }, frame.rows[1].hits[1])
    assert.same({ start_col = 11, end_col = 14, kind = "scroll", direction = 1 }, frame.rows[2].hits[2])
    assert.equal("Marker", frame.rows[1].spans[1].highlight)
  end)

  it("reveals the current row only when requested and clamps stale wheel positions", function()
    local plan = require("bufferline.multiline.layout").plan
    local entries = {}
    for id = 1, 5 do
      entries[id] = entry(id, string.rep(tostring(id), 8))
    end
    entries[5].current = true

    local revealed = plan(entries, geometry(14, 2), { reveal = true })
    assert.equal(4, revealed.first_row)
    assert.equal(entries[5].component, revealed.visible_components[2])
    assert.equal(3, revealed.before_count)
    assert.equal(0, revealed.after_count)
    local previous = plan(entries, geometry(14, 2), { first_row = 4, current_id = 2, reveal = true })
    assert.equal(2, previous.first_row)
    local scrolled = plan(entries, geometry(14, 2), { first_row = 99, reveal = false })
    assert.equal(4, scrolled.first_row)
    local top = plan(entries, geometry(14, 2), { first_row = -9, reveal = false })
    assert.equal(1, top.first_row)
  end)

  it("clips oversized tabs in fixed gutters with both controls on a one-row viewport", function()
    local plan = require("bufferline.multiline.layout").plan
    local entries = {}
    for id = 1, 12 do
      entries[id] = entry(id, "long-name")
    end
    entries[6].current = true
    entries[6].runs[2] = { text = "x", highlight = "Close", action = { kind = "close", id = 6 } }

    local frame = plan(entries, geometry(16, 1), { reveal = true })
    assert.equal("5  long-na…  6", frame.rows[1].text)
    assert.equal(16, vim.fn.strdisplaywidth(frame.rows[1].text))
    assert.equal(12, frame.total_rows)
    assert.equal(6, frame.first_row)
    assert.equal(5, frame.before_count)
    assert.equal(6, frame.after_count)
    assert.same({ entries[6].component }, frame.visible_components)
    assert.same({
      { start_col = 0, end_col = 4, kind = "scroll", direction = -1 },
      { start_col = 4, end_col = 12, kind = "click", id = 6 },
      { start_col = 12, end_col = 16, kind = "scroll", direction = 1 },
    }, frame.rows[1].hits)
    local bottom = plan(entries, geometry(16, 1), { first_row = 12, reveal = false })
    assert.equal("11 long-na…    ", bottom.rows[1].text)
    assert.equal(4, bottom.rows[1].hits[2].start_col)
  end)

  it("clips wide names without splitting UTF-8 or a base from its combining marks", function()
    local item = entry(1, "")
    item.runs = {
      { text = "界e", highlight = "Tab", action = { kind = "click", id = 1 } },
      { text = "́", highlight = "Accent", action = { kind = "click", id = 1 } },
      { text = "%long", highlight = "Tab", action = { kind = "click", id = 1 } },
    }
    local frame = require("bufferline.multiline.layout").plan({ item }, geometry(4, 1))
    local row = frame.rows[1]

    assert.equal("界é…", row.text)
    assert.equal(4, vim.fn.strdisplaywidth(row.text))
    assert.same({
      { start_col = 0, end_col = 4, highlight = "Tab" },
      { start_col = 4, end_col = 6, highlight = "Accent" },
      { start_col = 6, end_col = 9, highlight = "Accent" },
    }, row.spans)
    assert.same({ { start_col = 0, end_col = 4, kind = "click", id = 1 } }, row.hits)
  end)

  it("repeats plain offset labels on every row with byte highlights and cell hits", function()
    local entries = { entry(1, "abcd"), entry(2, "%#x#") }
    local geo = geometry(10, 2)
    geo.left = { text = "界", width = 3, spans = { { start_col = 0, end_col = 3, highlight = "Left" } } }
    geo.right = { text = "%", width = 2, spans = { { start_col = 0, end_col = 1, highlight = "Right" } } }
    local frame = require("bufferline.multiline.layout").plan(entries, geo)

    assert.equal(2, #frame.rows)
    assert.equal("界 abcd % ", frame.rows[1].text)
    assert.equal("界 %#x# % ", frame.rows[2].text)
    for index, row in ipairs(frame.rows) do
      assert.equal(10, vim.fn.strdisplaywidth(row.text))
      assert.same({ { start_col = 3, end_col = 7, kind = "click", id = index } }, row.hits)
      local labels = {}
      for _, span in ipairs(row.spans) do
        if span.highlight == "Left" or span.highlight == "Right" then labels[#labels + 1] = span end
      end
      assert.same({
        { start_col = 0, end_col = 3, highlight = "Left" },
        { start_col = 9, end_col = 10, highlight = "Right" },
      }, labels)
    end
  end)

  it("clips offset labels and their highlights at combining-safe byte boundaries", function()
    local geo = geometry(8, 1)
    geo.left = { text = "é界wide", width = 1, spans = { { start_col = 0, end_col = 10, highlight = "Left" } } }
    geo.right = { text = "界wide", width = 2, spans = { { start_col = 0, end_col = 7, highlight = "Right" } } }
    local frame = require("bufferline.multiline.layout").plan({ entry(1, "ab") }, geo)
    local row = frame.rows[1]

    assert.equal("éab   界", row.text)
    assert.equal(8, vim.fn.strdisplaywidth(row.text))
    local labels = {}
    for _, span in ipairs(row.spans) do
      assert.is_true(span.start_col >= 0 and span.end_col <= #row.text and span.start_col < span.end_col)
      if span.highlight == "Left" or span.highlight == "Right" then labels[#labels + 1] = span end
    end
    assert.same({
      { start_col = 0, end_col = 3, highlight = "Left" },
      { start_col = 8, end_col = 11, highlight = "Right" },
    }, labels)
  end)

  it("returns an invalid empty frame when offsets or overflow gutters consume all width", function()
    local plan = require("bufferline.multiline.layout").plan
    local entries = { entry(1, "long-name"), entry(2, "long-name") }
    local offset_geo = geometry(8, 1)
    offset_geo.left = { text = "panel", width = 8 }
    for _, geo in ipairs({ geometry(0, 1), offset_geo, geometry(6, 1) }) do
      local frame = plan(entries, geo)
      assert.is_false(frame.valid)
      assert.same({}, frame.rows)
      assert.same({}, frame.visible_components)
      assert.equal(1, frame.first_row)
    end
  end)

  it("keeps collapsed group controls reachable without leaking hidden buffer state", function()
    local plan = require("bufferline.multiline.layout").plan
    local group = {
      component = { hidden = true, components = { { id = 90 }, { id = 91 } } },
      focusable = false,
      runs = { { text = "closed-group", highlight = "Group", action = { kind = "group", id = 7 } } },
    }
    local entries = { group, entry(1, "11111111"), entry(2, "22222222") }
    local top = plan(entries, geometry(14, 1), { first_row = 1 })
    assert.equal("   closed-… 2", top.rows[1].text)
    assert.same({}, top.visible_components)
    assert.equal(0, top.before_count)
    assert.equal(2, top.after_count)
    assert.same({ start_col = 3, end_col = 11, kind = "group", id = 7 }, top.rows[1].hits[1])
    local middle = plan(entries, geometry(14, 1), { first_row = 2, reveal = false })
    assert.equal(0, middle.before_count)
    assert.equal(1, middle.after_count)
    assert.equal("0 11111111 1", middle.rows[1].text)
    assert.same({ entries[2].component }, middle.visible_components)
    assert.same({ start_col = 0, end_col = 3, kind = "scroll", direction = -1 }, middle.rows[1].hits[1])
    local empty = plan({}, geometry(14, 1), { first_row = 99 })
    assert.equal(1, #empty.rows)
    assert.equal(string.rep(" ", 14), empty.rows[1].text)
    assert.same({}, empty.rows[1].hits)
    assert.same({}, empty.visible_components)
    assert.equal(1, empty.first_row)
    assert.equal(0, empty.before_count)
    assert.equal(0, empty.after_count)
  end)

  it("measures the ellipsis in display cells and preserves separate close actions", function()
    local previous = vim.o.ambiwidth
    local ok, err = pcall(function()
      vim.o.ambiwidth = "double"
      local item = entry(1, "abc")
      item.current = true
      item.runs[2] = { text = "×", highlight = "Close", action = { kind = "close", id = 1 } }
      local plan = require("bufferline.multiline.layout").plan
      local clipped = plan({ item }, geometry(2, 1)).rows[1]
      assert.equal("…", clipped.text)
      assert.same({ { start_col = 0, end_col = 2, kind = "click", id = 1 } }, clipped.hits)
      local tiny = plan({ item }, geometry(1, 1)).rows[1]
      assert.equal("a", tiny.text)
      assert.same({ { start_col = 0, end_col = 1, kind = "click", id = 1 } }, tiny.hits)
      local full = plan({ item }, geometry(5, 1)).rows[1]
      assert.equal("abc×", full.text)
      assert.same({
        { start_col = 0, end_col = 3, kind = "click", id = 1 },
        { start_col = 3, end_col = 5, kind = "close", id = 1 },
      }, full.hits)
    end)
    vim.o.ambiwidth = previous
    assert.is_true(ok, err)
  end)

  it("does not reveal a nonfocusable group with the same id as the current buffer", function()
    local group = entry(2, "a-group-")
    group.focusable = false
    group.runs[1].action = { kind = "group", id = 2 }
    local entries = { entry(2, "current-"), entry(3, "another-"), group }
    local frame = require("bufferline.multiline.layout").plan(entries, geometry(14, 1), {
      current_id = 2,
      reveal = true,
    })

    assert.equal(1, frame.first_row)
    assert.same({ entries[1].component }, frame.visible_components)
  end)
end)
