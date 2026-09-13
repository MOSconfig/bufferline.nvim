if vim.fn.has("nvim-0.12") == 0 then return end

local api = vim.api
local bufferline = require("bufferline")
local runtime = require("bufferline.multiline.runtime")
local state = require("bufferline.state")

local function enable(extra)
  local options = vim.tbl_deep_extend("force", {
    multiline = { enabled = true, max_rows = 2 },
    show_buffer_icons = false,
    show_buffer_close_icons = true,
    persist_buffer_sort = false,
    max_name_length = 20,
  }, extra or {})
  bufferline.setup({ options = options })
  runtime.flush("test")
end

local function header() return assert(runtime.handles()[api.nvim_get_current_tabpage()], "header missing") end

local function add_buffers(count)
  local ids = {}
  for index = 1, count do
    local buf = api.nvim_create_buf(true, false)
    api.nvim_buf_set_name(buf, "multiline-example-" .. index .. ".txt")
    ids[#ids + 1] = buf
  end
  api.nvim_set_current_buf(ids[1])
  return ids
end

describe("Multiline integration", function()
  local old_columns
  before_each(function()
    runtime.disable()
    vim.o.hidden = true
    vim.o.termguicolors = true
    vim.cmd("silent! tabonly | silent! only | silent! %bwipeout!")
    old_columns = vim.o.columns
    vim.o.columns = 80
  end)
  after_each(function()
    bufferline.setup({ options = { persist_buffer_sort = false } })
    vim.cmd("silent! tabonly | silent! only | silent! %bwipeout!")
    vim.o.columns = old_columns
  end)

  it("wraps buffer entries into plain highlighted rows without a native tabline", function()
    local ids = add_buffers(8)
    enable()
    local h = header()
    local rows = api.nvim_buf_get_lines(h.buf, 0, -1, false)
    assert.same(0, vim.o.showtabline)
    assert.same(2, #rows)
    assert.is_true(#state.components >= #ids)
    assert.is_true(#state.visible_components < #state.components)
    assert.is_nil(table.concat(rows):find("%%#"))
    assert.is_nil(table.concat(rows):find("%%@"))
    assert.is_false(vim.bo[h.buf].buflisted)
    assert.same("nofile", vim.bo[h.buf].buftype)
    assert.same(ids[1], api.nvim_get_current_buf())
  end)

  it("refreshes additions and deletions while showtabline is zero", function()
    local ids = add_buffers(4)
    enable()
    local before = #state.components
    local added = api.nvim_create_buf(true, false)
    api.nvim_buf_set_name(added, "new-row-buffer.txt")
    assert.is_true(vim.wait(1000, function() return #state.components == before + 1 end, 10))
    api.nvim_buf_delete(ids[2], { force = false })
    assert.is_true(vim.wait(1000, function() return #state.components == before end, 10))
    assert.same(0, vim.o.showtabline)
  end)

  it("cycles once through full buffer order including hidden rows", function()
    add_buffers(10)
    enable()
    local components = state.components
    api.nvim_set_current_buf(components[1].id)
    bufferline.cycle(1)
    assert.same(components[2].id, api.nvim_get_current_buf())
    for _ = 1, #components - 2 do
      bufferline.cycle(1)
    end
    assert.same(components[#components].id, api.nvim_get_current_buf())
    runtime.flush("test")
    local found = false
    for _, component in ipairs(state.visible_components) do
      if component.id == api.nvim_get_current_buf() then found = true end
    end
    assert.is_true(found)
  end)

  it("preserves literal percent filenames", function()
    local ids = add_buffers(1)
    api.nvim_buf_set_name(ids[1], "100%.lua")
    enable({ max_name_length = 40 })
    local text = table.concat(api.nvim_buf_get_lines(header().buf, 0, -1, false))
    assert.is_truthy(text:find("100%.lua", 1, true))
    assert.is_nil(text:find("100%%.lua", 1, true))
  end)

  it("retains modified markers and responds to buffer renames", function()
    local ids = add_buffers(2)
    enable({ modified_icon = "[+]", show_buffer_close_icons = false })
    api.nvim_buf_set_lines(ids[1], 0, -1, false, { "unsaved" })
    api.nvim_buf_set_name(ids[1], "renamed%.lua")
    runtime.flush("refresh")
    local text = table.concat(api.nvim_buf_get_lines(header().buf, 0, -1, false))
    assert.is_truthy(text:find("renamed%.lua", 1, true))
    assert.is_truthy(text:find("[+]", 1, true))
  end)

  it("preserves a full-height sidebar beside editor-only rows without offsets", function()
    add_buffers(6)
    local editor = api.nvim_get_current_win()
    vim.cmd("topleft vnew")
    local sidebar = api.nvim_get_current_win()
    vim.bo.buftype = "nofile"
    vim.bo.buflisted = false
    vim.bo.filetype = "multiline_test_sidebar"
    api.nvim_win_set_width(sidebar, 20)
    vim.wo[sidebar].winfixwidth = true
    api.nvim_set_current_win(editor)
    enable({ offsets = { { filetype = "multiline_test_sidebar", text = "Explorer", text_align = "left" } } })
    assert.same(20, api.nvim_win_get_width(sidebar))
    assert.same(editor, api.nvim_get_current_win())
    local h = header()
    assert.same({ 0, 0 }, api.nvim_win_get_position(sidebar))
    assert.same({ 0, 21 }, api.nvim_win_get_position(h.win))
    assert.same(api.nvim_win_get_width(editor), api.nvim_win_get_width(h.win))
    for _, row in ipairs(api.nvim_buf_get_lines(h.buf, 0, -1, false)) do
      assert.is_nil(row:find("Explorer", 1, true))
      assert.same(api.nvim_win_get_width(h.win), vim.fn.strdisplaywidth(row))
    end
    assert.same(0, state.left_offset_size)
  end)

  it("keeps the current header when invalid settings are rejected", function()
    add_buffers(3)
    enable()
    local h = header()
    assert.has_error(function() bufferline.setup({ options = { multiline = { enabled = true, max_rows = 0 } } }) end)
    assert.is_true(runtime.active())
    assert.same(h.win, header().win)
    assert.same(0, vim.o.showtabline)
  end)

  it("keeps group headers actionable and pin order stable", function()
    local ids = add_buffers(5)
    enable({ groups = { items = { { name = "Lua", matcher = function() return true end } } } })
    bufferline.groups.toggle_pin()
    runtime.flush("refresh")
    assert.same(ids[1], state.components[1].id)
    local group_hit
    for _, row in ipairs(header().frame.rows) do
      for _, hit in ipairs(row.hits) do
        if hit.kind == "group" then group_hit = hit end
      end
    end
    assert.is_truthy(group_hit)
    local group = bufferline.groups.get_by_id("Lua")
    local was_hidden = group.hidden
    require("bufferline.commands").dispatch(group_hit, {
      win = api.nvim_get_current_win(),
      tab = api.nvim_get_current_tabpage(),
      button = "l",
    })
    assert.same(not was_hidden, group.hidden)
    bufferline.groups.toggle_pin()
    runtime.flush("refresh")
    assert.is_true(runtime.active())
  end)

  it("supports disabling before saving and restoring a session", function()
    local ids = add_buffers(3)
    enable()
    local session = vim.fn.tempname()
    bufferline.setup({ options = { persist_buffer_sort = false } })
    assert.same(1, #api.nvim_tabpage_list_wins(0))
    vim.cmd("mksession! " .. vim.fn.fnameescape(session))
    vim.cmd("source " .. vim.fn.fnameescape(session))
    vim.fn.delete(session)
    assert.same(1, #api.nvim_tabpage_list_wins(0))
    enable()
    assert.same(2, #api.nvim_tabpage_list_wins(0))
    assert.is_true(api.nvim_buf_is_valid(ids[1]))
  end)

  it("removes all header resources on disabling", function()
    add_buffers(5)
    enable()
    local h = header()
    bufferline.setup({ options = { persist_buffer_sort = false } })
    assert.is_false(runtime.active())
    assert.is_false(api.nvim_win_is_valid(h.win))
    assert.same(1, #api.nvim_tabpage_list_wins(0))
    assert.same(2, vim.o.showtabline)
    assert.is_truthy(nvim_bufferline())
  end)
end)
