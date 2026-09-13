local api = vim.api

-- Synthetic frames exercise real windows, buffers and input independently of core/layout.
describe("Multiline runtime", function()
  local runtime, editor, options, hooks, frame, calls, child
  local saved = {}
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

  local function child_lua(code, args) return vim.fn.rpcrequest(child, "nvim_exec_lua", code, args or {}) end

  local function start_child()
    child = vim.fn.jobstart(
      { vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE", "-n" },
      { rpc = true }
    )
    assert.is_true(child > 0)
    return child_lua(
      [=[
      vim.opt.runtimepath:prepend(...)
      vim.o.mouse = "a"
      vim.o.mousemodel = "extend"
      vim.o.showtabline = 2
      runtime = require("bufferline.multiline.runtime")
      editor = vim.api.nvim_get_current_win()
      tab = vim.api.nvim_get_current_tabpage()
      seen = {}
      frame = { rows = {
        { text = "one%", spans = {}, hits = { { start_col = 0, end_col = 4, kind = "click", id = vim.api.nvim_get_current_buf() } } },
        { text = "two", spans = {}, hits = {} },
      }, first_row = 1, total_rows = 2, visible_components = {} }
      options = { multiline = { max_rows = 3 }, always_show_bufferline = true, auto_toggle_bufferline = true }
      hooks = {
        frame = function(width, max_rows, viewport) return vim.deepcopy(frame) end,
        native_visibility = function(saved) vim.o.showtabline = saved end,
        dispatch = function(hit, context)
          seen[#seen + 1] = { hit = hit, context = context, win = vim.api.nvim_get_current_win() }
          vim.api.nvim_buf_set_lines(vim.api.nvim_win_get_buf(context.win), 0, -1, false, { "clicked" })
        end,
      }
      runtime.enable(options, hooks)
      runtime.flush("test")
      vim.cmd("redraw")
      return { editor = editor, tab = tab, handle = runtime.handles()[tab] }
    ]=],
      { root }
    )
  end

  local function input(keys)
    vim.fn.rpcrequest(child, "nvim_input", keys)
    child_lua("return true")
    vim.wait(30)
  end

  local function real_layout(count)
    local initial = start_child()
    child_lua(
      [=[
      local count = ...
      ids, entries = {}, {}
      for i = 1, count do
        local id = i == 1 and vim.api.nvim_win_get_buf(editor) or vim.api.nvim_create_buf(true, false)
        ids[i] = id
        entries[#entries + 1] = { id = id, focusable = true, component = { id = id }, runs = {
          { text = i == 1 and "界é01 " or string.format("b%02d---", i), highlight = "Normal", action = { kind = "click", id = id } },
        } }
        if i == 2 then entries[#entries + 1] = { focusable = false, runs = {
          { text = "group---------", highlight = "Normal", action = { kind = "group", id = "group" } },
        } } end
      end
      layout_width = 22
      hooks.frame = function(_, max_rows, viewport)
        local live = vim.tbl_filter(function(e) return not e.id or (vim.api.nvim_buf_is_valid(e.id) and vim.bo[e.id].buflisted) end, entries)
        return require("bufferline.multiline.layout").plan(live,
          { width = layout_width, max_rows = max_rows, fill_hl = "Normal", marker_hl = "Normal" }, viewport)
      end
      hooks.dispatch = function(hit, context)
        seen[#seen + 1] = { hit = hit, context = context, win = vim.api.nvim_get_current_win() }
        vim.api.nvim_win_set_buf(context.win, hit.id)
      end
      runtime.flush("test")
      vim.cmd("redraw")
      function snapshot()
        local h = runtime.handles()[tab]
        return { first = h.first_row, ids = vim.tbl_map(function(c) return c.id end, h.frame.visible_components),
          lines = vim.api.nvim_buf_get_lines(h.buf, 0, -1, false), candidate = h.candidate,
          editor_buf = vim.api.nvim_win_get_buf(editor), win = vim.api.nvim_get_current_win() }
      end
    ]=],
      { count }
    )
    return initial
  end

  before_each(function()
    package.loaded["bufferline.multiline.runtime"] = nil
    runtime = require("bufferline.multiline.runtime")
    saved = { showtabline = vim.o.showtabline, mouse = vim.o.mouse, laststatus = vim.o.laststatus }
    vim.o.showtabline = 2
    vim.o.hidden = true
    editor = api.nvim_get_current_win()
    calls = {}
    options = { multiline = { max_rows = 3 }, always_show_bufferline = true, auto_toggle_bufferline = true }
    frame = {
      rows = {
        {
          text = "one%",
          spans = { { start_col = 0, end_col = 4, highlight = "BufferLineBufferSelected" } },
          hits = { { start_col = 0, end_col = 4, kind = "click", id = api.nvim_get_current_buf() } },
        },
        { text = "two", spans = {}, hits = {} },
      },
      total_rows = 2,
      first_row = 1,
      visible_components = {},
    }
    api.nvim_set_hl(0, "BufferLineFill", { bg = "#112233" })
    api.nvim_set_hl(0, "BufferLineBufferSelected", { fg = "#abcdef" })
    hooks = {
      frame = function(width, max_rows, viewport)
        calls[#calls + 1] =
          { win = api.nvim_get_current_win(), width = width, max_rows = max_rows, viewport = vim.deepcopy(viewport) }
        return vim.deepcopy(frame)
      end,
      native_visibility = function(value) vim.o.showtabline = value end,
      dispatch = function() end,
    }
  end)

  after_each(function()
    if child then
      pcall(vim.fn.jobstop, child)
      child = nil
    end
    if runtime then runtime.disable() end
    vim.cmd("silent! tabonly!")
    vim.cmd("silent! only!")
    vim.cmd("silent! %bwipeout!")
    for name, value in pairs(saved) do
      vim.o[name] = value
    end
    vim.wait(10)
  end)

  it("coalesces refresh events and ignores changes to its own scratch buffer", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    vim.wait(20)
    calls = {}
    for _ = 1, 5 do
      runtime.request("ui.refresh")
    end
    for _, event in ipairs({
      "BufAdd",
      "BufDelete",
      "BufWipeout",
      "BufEnter",
      "BufFilePost",
      "BufModifiedSet",
      "DiagnosticChanged",
      "ColorScheme",
    }) do
      api.nvim_exec_autocmds(event, { modeline = false })
    end
    assert.equals(0, #calls)
    vim.wait(20)
    assert.equals(1, #calls)
    api.nvim_exec_autocmds("BufModifiedSet", { buffer = handle.buf, modeline = false })
    vim.wait(20)
    assert.equals(1, #calls)
  end)

  it("keeps unchanged buffer text and window height stable across refreshes", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    local changedtick = api.nvim_buf_get_changedtick(handle.buf)
    local win, height = handle.win, api.nvim_win_get_height(handle.win)
    for _ = 1, 3 do
      runtime.flush("ui.refresh")
    end
    assert.equals(changedtick, api.nvim_buf_get_changedtick(handle.buf))
    assert.equals(win, runtime.handles()[api.nvim_get_current_tabpage()].win)
    assert.equals(height, api.nvim_win_get_height(win))
  end)

  it("uses the last ordinary editing window while a sidebar or header is focused", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    vim.cmd("vnew")
    local second = api.nvim_get_current_win()
    runtime.flush("test")
    vim.cmd("vnew")
    local sidebar = api.nvim_get_current_win()
    vim.bo.buftype = "nofile"
    runtime.flush("test")
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    assert.equals(second, calls[#calls].win)
    assert.equals(sidebar, api.nvim_get_current_win())
    api.nvim_set_current_win(handle.win)
    assert.equals(handle.win, api.nvim_get_current_win())
    assert.equals(second, handle.editor)
  end)

  it("dispatches the first mouse press from the editor without focusing the header", function()
    local initial = start_child()
    vim.fn.rpcrequest(child, "nvim_input_mouse", "left", "press", "", 0, 0, 1)
    vim.wait(100, function() return child_lua("return #seen") > 0 end)
    local result = child_lua(
      "return { seen = seen, win = vim.api.nvim_get_current_win(), lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(editor), 0, -1, false) }"
    )
    assert.equals(1, #result.seen)
    assert.equals("click", result.seen[1].hit.kind)
    assert.same({ win = initial.editor, tab = initial.tab, button = "l", clicks = 1 }, result.seen[1].context)
    assert.equals(initial.editor, result.seen[1].win)
    assert.equals(initial.editor, result.win)
    assert.same({ "clicked" }, result.lines)
  end)

  it("preserves competing user mouse mappings", function()
    local initial = start_child()
    child_lua([=[
      mapped_clicks = 0
      vim.keymap.set("n", "<LeftMouse>", function() mapped_clicks = mapped_clicks + 1 end)
    ]=])
    vim.fn.rpcrequest(child, "nvim_input_mouse", "left", "press", "", 0, 0, 1)
    assert.is_true(vim.wait(500, function() return child_lua("return mapped_clicks") == 1 end))
    assert.equals(0, child_lua("return #seen"))
    assert.equals(initial.editor, child_lua("return vim.api.nvim_get_current_win()"))
  end)

  it("handles cell-based close/group hits and all buttons while consuming releases and drags", function()
    local initial = start_child()
    child_lua([=[
      frame.rows[2] = { text = "界xg", spans = {}, hits = {
        { start_col = 0, end_col = 2, kind = "click", id = 10 },
        { start_col = 2, end_col = 3, kind = "close", id = 20 },
        { start_col = 3, end_col = 4, kind = "group", id = "group" },
      } }
      runtime.flush("test")
      entered = 0
      vim.api.nvim_create_autocmd("WinEnter", { callback = function() entered = entered + 1 end })
    ]=])
    for _, event in ipairs({
      { "right", "press", 1 },
      { "right", "release", 1 },
      { "middle", "press", 2 },
      { "middle", "release", 2 },
      { "left", "press", 3 },
      { "left", "drag", 7 },
      { "left", "release", 7 },
    }) do
      vim.fn.rpcrequest(child, "nvim_input_mouse", event[1], event[2], "", 0, 1, event[3])
      child_lua("return true")
    end
    vim.wait(100, function() return child_lua("return #seen") == 3 end)
    local result = child_lua("return { seen = seen, entered = entered, win = vim.api.nvim_get_current_win() }")
    assert.equals(3, #result.seen)
    assert.same(
      { "r", "m", "l" },
      { result.seen[1].context.button, result.seen[2].context.button, result.seen[3].context.button }
    )
    assert.same(
      { "click", "close", "group" },
      { result.seen[1].hit.kind, result.seen[2].hit.kind, result.seen[3].hit.kind }
    )
    assert.equals(0, result.entered)
    assert.equals(initial.editor, result.win)
  end)

  it("scrolls rows without snapping back until the active buffer or size changes", function()
    start_child()
    child_lua([=[
      viewports = {}
      hooks.frame = function(width, max_rows, viewport)
        viewports[#viewports + 1] = vim.deepcopy(viewport)
        local first = viewport.reveal and 1 or math.max(1, math.min(7, viewport.first_row))
        return { rows = frame.rows, first_row = first, total_rows = 8, visible_components = {} }
      end
      runtime.flush("test")
    ]=])
    vim.fn.rpcrequest(child, "nvim_input_mouse", "wheel", "down", "", 0, 0, 1)
    vim.wait(100, function() return child_lua("return runtime.handles()[tab].first_row") == 2 end)
    assert.equals(2, child_lua("return runtime.handles()[tab].first_row"))
    child_lua("runtime.flush('ui.refresh')")
    assert.is_false(child_lua("return viewports[#viewports].reveal"))
    assert.equals(2, child_lua("return runtime.handles()[tab].first_row"))
    local changed = child_lua(
      "vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false)); runtime.flush('BufEnter'); return viewports[#viewports]"
    )
    assert.is_true(changed.reveal)
    assert.equals(1, child_lua("return runtime.handles()[tab].first_row"))
    child_lua("runtime.flush('VimResized')")
    assert.is_true(child_lua("return viewports[#viewports].reveal"))
  end)

  it("scrolls real packed text and IDs with wheel input in either focus context", function()
    local initial = real_layout(20)
    for _, focused in ipairs({ false, true }) do
      child_lua("runtime.handles()[tab].first_row = 1; runtime.flush('scroll'); vim.cmd('redraw')")
      if focused then input("<C-w>k") end
      local top = child_lua("return snapshot()")
      assert.equals(focused and initial.handle.win or initial.editor, top.win)
      for _, direction in ipairs({ "down", "down", "up" }) do
        local previous = child_lua("return snapshot()")
        vim.fn.rpcrequest(child, "nvim_input_mouse", "wheel", direction, "", 0, 0, 5)
        assert.is_true(vim.wait(500, function() return child_lua("return snapshot().first") ~= previous.first end))
        local after = child_lua("return snapshot()")
        assert.is_false(vim.deep_equal(previous.ids, after.ids))
        assert.is_false(vim.deep_equal(previous.lines, after.lines))
        assert.equals(top.win, after.win)
        assert.equals(top.editor_buf, after.editor_buf)
        child_lua("runtime.flush('ui.refresh')")
        assert.same(after.ids, child_lua("return snapshot().ids"))
        assert.same(after.lines, child_lua("return snapshot().lines"))
      end
      for _ = 1, 20 do
        vim.fn.rpcrequest(child, "nvim_input_mouse", "wheel", "down", "", 0, 0, 5)
        child_lua("return true")
      end
      assert.equals(
        child_lua("local h = runtime.handles()[tab]; return h.frame.total_rows - #h.frame.rows + 1"),
        child_lua("return snapshot().first")
      )
      local bottom = child_lua("return snapshot()")
      vim.fn.rpcrequest(child, "nvim_input_mouse", "wheel", "down", "", 0, 0, 5)
      child_lua("return true")
      assert.same(bottom, child_lua("return snapshot()"))
      for _ = 1, 20 do
        vim.fn.rpcrequest(child, "nvim_input_mouse", "wheel", "up", "", 0, 0, 5)
        child_lua("return true")
      end
      assert.equals(1, child_lua("return snapshot().first"))
      assert.same(top.ids, child_lua("return snapshot().ids"))
      assert.same(top.lines, child_lua("return snapshot().lines"))
    end
  end)

  it("navigates candidates using actual local input and dispatches only on Enter", function()
    local initial = real_layout(20)
    local ids = child_lua("return ids")
    input("<C-w>k")
    assert.equals(initial.handle.win, child_lua("return snapshot().win"))
    assert.equals(ids[1], child_lua("return snapshot().candidate"))
    input("hk")
    assert.equals(ids[1], child_lua("return snapshot().candidate"))
    input("l")
    assert.equals(ids[2], child_lua("return snapshot().candidate"))
    input("j")
    assert.equals(ids[4], child_lua("return snapshot().candidate"))
    input("k")
    assert.equals(ids[2], child_lua("return snapshot().candidate"))
    input(string.rep("j", 20) .. string.rep("l", 20))
    assert.equals(ids[20], child_lua("return snapshot().candidate"))
    assert.is_true(child_lua("return snapshot().first > 3"))
    assert.equals(ids[1], child_lua("return snapshot().editor_buf"))
    assert.equals(0, child_lua("return #seen"))
    input("<Esc>")
    assert.equals(initial.editor, child_lua("return snapshot().win"))
    assert.equals(ids[1], child_lua("return snapshot().editor_buf"))
    input("<C-w>kl<CR>")
    local seen = child_lua("return seen")
    assert.equals(1, #seen)
    assert.equals(ids[2], seen[1].hit.id)
    assert.equals(initial.editor, seen[1].win)
    assert.same({ win = initial.editor, tab = initial.tab, button = "l", clicks = 1 }, seen[1].context)
    assert.equals(ids[2], child_lua("return snapshot().editor_buf"))
    assert.same(
      {},
      child_lua(
        "return vim.tbl_filter(function(m) return m.lhs == 'h' or m.lhs == 'j' or m.lhs == 'k' or m.lhs == 'l' end, vim.api.nvim_get_keymap('n'))"
      )
    )
  end)

  it("navigates with the real plugin frame and configured click callback", function()
    local initial = real_layout(20)
    child_lua(
      [=[
      local deps = ...
      vim.opt.runtimepath:append(deps .. "/nvim-web-devicons")
      for i, id in ipairs(ids) do vim.api.nvim_buf_set_name(id, "keyboard-buffer-" .. i .. ".lua") end
      require("bufferline").setup({ options = {
        multiline = { enabled = true, max_rows = 3 }, show_buffer_icons = false,
        left_mouse_command = function(id)
          seen[#seen + 1] = { id = id, win = vim.api.nvim_get_current_win() }
          vim.api.nvim_set_current_buf(id)
        end,
      } })
      runtime.flush("test")
      vim.cmd("redraw")
    ]=],
      { os.getenv("NVIM_TEST_DEPS") or (root .. "/.tests") }
    )
    local header_win = child_lua("return runtime.handles()[tab].win")
    input("<C-w>kljjjj")
    assert.equals(header_win, child_lua("return snapshot().win"))
    assert.is_true(child_lua("return snapshot().first > 1"))
    assert.equals(child_lua("return ids[1]"), child_lua("return snapshot().editor_buf"))
    local candidate = child_lua("return snapshot().candidate")
    input("<CR>")
    assert.same({ { id = candidate, win = initial.editor } }, child_lua("return seen"))
  end)

  it("handles empty and single candidates and Unicode cursor/highlight bytes", function()
    for _, count in ipairs({ 0, 1 }) do
      local initial = real_layout(count)
      input("<C-w>khjkl")
      local selected = child_lua("return snapshot().candidate or false")
      assert.equals(count == 1 and child_lua("return ids[1]") or false, selected)
      if count == 1 then
        assert.same({ 1, 0 }, child_lua("return vim.api.nvim_win_get_cursor(runtime.handles()[tab].win)"))
        assert.is_true(child_lua([=[
          local h = runtime.handles()[tab]
          for _, m in ipairs(vim.api.nvim_buf_get_extmarks(h.buf, -1, 0, -1, { details = true })) do
            if m[4].hl_group == "IncSearch" then return m[3] == 0 and m[4].end_col == #"界é01 " end
          end
          return false
        ]=]))
      end
      input("<CR>")
      assert.equals(initial.editor, child_lua("return snapshot().win"))
      assert.equals(count, child_lua("return #seen"))
      vim.fn.jobstop(child)
      child = nil
    end
  end)

  it("preserves candidate IDs across repacking and reconciles removed buffers", function()
    real_layout(20)
    input("<C-w>klllll")
    local selected = child_lua("return snapshot().candidate")
    child_lua("layout_width = 14; runtime.flush('VimResized')")
    assert.equals(selected, child_lua("return snapshot().candidate"))
    assert.is_true(child_lua("return vim.tbl_contains(snapshot().ids, snapshot().candidate)"))
    child_lua("vim.api.nvim_buf_delete(runtime.handles()[tab].candidate, { force = true })")
    assert.is_true(vim.wait(500, function() return child_lua("return snapshot().candidate") ~= selected end))
    assert.equals(child_lua("return ids[1]"), child_lua("return snapshot().candidate"))
    assert.is_true(child_lua("return vim.tbl_contains(snapshot().ids, snapshot().candidate)"))
    input("<CR>")
    assert.equals(child_lua("return ids[1]"), child_lua("return seen[1].hit.id"))
  end)

  it("restores the captured editor before focused teardown and falls back when it disappears", function()
    for _, action in ipairs({ "disable", "fallback", "session", "auto-hide" }) do
      local initial = real_layout(2)
      child_lua([=[
        vim.cmd("vnew")
        other = vim.api.nvim_get_current_win()
        vim.api.nvim_set_current_win(editor)
      ]=])
      input("<C-w>k")
      child_lua(
        [=[
        local action = ...
        if action == "disable" then runtime.disable()
        elseif action == "fallback" then hooks.frame = function() return { valid = false } end; runtime.flush("test")
        elseif action == "session" then vim.api.nvim_exec_autocmds("SessionLoadPre", {})
        else
          options.always_show_bufferline = false
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if b ~= ids[1] then vim.bo[b].buflisted = false end
          end
          runtime.flush("test")
        end
      ]=],
        { action }
      )
      assert.equals(initial.editor, child_lua("return vim.api.nvim_get_current_win()"), action)
      assert.is_false(child_lua("return vim.api.nvim_win_is_valid(" .. initial.handle.win .. ")"))
      vim.fn.jobstop(child)
      child = nil
    end
    for _, key in ipairs({ "<Esc>", "<CR>" }) do
      real_layout(3)
      child_lua("vim.cmd('vnew'); other = vim.api.nvim_get_current_win(); vim.api.nvim_set_current_win(editor)")
      input("<C-w>kl")
      child_lua("vim.api.nvim_win_close(editor, true)")
      input(key)
      assert.equals(child_lua("return other"), child_lua("return vim.api.nvim_get_current_win()"))
      if key == "<CR>" then assert.equals(child_lua("return other"), child_lua("return seen[1].context.win")) end
      vim.fn.jobstop(child)
      child = nil
    end
  end)

  it("does not strand an owned header after focused only or buffer deletion", function()
    for _, command in ipairs({ "only", "only!", "bdelete", "bdelete!" }) do
      for _, dirty in ipairs({ false, true }) do
        local initial = real_layout(3)
        child_lua(
          "vim.o.hidden = false; if ... then vim.api.nvim_buf_set_lines(ids[1], 0, -1, false, {'dirty'}) end",
          { dirty }
        )
        input("<C-w>k")
        local result =
          child_lua("local ok, err = pcall(vim.cmd, ...); return { ok = ok, err = tostring(err) }", { command })
        vim.wait(30)
        assert.is_true(
          child_lua(
            "for _, w in ipairs(vim.api.nvim_list_wins()) do if not runtime.owns(w) and vim.bo[vim.api.nvim_win_get_buf(w)].buftype == '' then return true end end; return false"
          ),
          command .. result.err
        )
        assert.is_true(child_lua("return vim.api.nvim_buf_is_valid(ids[1])"))
        if result.ok then assert.is_false(child_lua("return runtime.owns(vim.api.nvim_get_current_win())")) end
        if dirty then assert.same({ "dirty" }, child_lua("return vim.api.nvim_buf_get_lines(ids[1], 0, -1, false)")) end
        vim.fn.jobstop(child)
        child = nil
      end
    end
  end)

  it("disposes an owned header before its scratch buffer is deleted or wiped", function()
    for _, command in ipairs({ "bdelete", "bwipeout" }) do
      local initial = real_layout(3)
      input("<C-w>k")
      child_lua("vim.cmd(...)", { command })
      vim.wait(30)
      assert.is_false(child_lua("return runtime.active()"))
      assert.is_false(child_lua("return vim.api.nvim_win_is_valid(" .. initial.handle.win .. ")"))
      assert.equals(initial.editor, child_lua("return vim.api.nvim_get_current_win()"))
      assert.equals(1, child_lua("return #vim.api.nvim_list_wins()"))
      vim.fn.jobstop(child)
      child = nil
    end
  end)

  it("returns from focused quit without stranding the header or bypassing modified checks", function()
    for _, dirty in ipairs({ false, true }) do
      local initial = real_layout(1)
      child_lua("if ... then vim.api.nvim_buf_set_lines(ids[1], 0, -1, false, {'dirty'}) end", { dirty })
      input("<C-w>k")
      local result = child_lua(
        "local ok, err = pcall(vim.cmd, 'quit'); return { ok = ok, err = tostring(err), win = vim.api.nvim_get_current_win(), lines = vim.api.nvim_buf_get_lines(ids[1], 0, -1, false) }"
      )
      assert.is_true(result.ok, result.err)
      assert.equals(initial.editor, result.win)
      assert.is_false(child_lua("return runtime.active()"))
      assert.equals(1, child_lua("return #vim.api.nvim_list_wins()"))
      if dirty then
        assert.same({ "dirty" }, result.lines)
        local quit = child_lua("local ok, err = pcall(vim.cmd, 'quit'); return { ok = ok, err = tostring(err) }")
        assert.is_false(quit.ok)
        assert.matches("E37", quit.err)
        vim.fn.jobstop(child)
      else
        vim.fn.rpcnotify(child, "nvim_command", "quit")
        assert.equals(0, vim.fn.jobwait({ child }, 1000)[1])
      end
      child = nil
    end
  end)

  it("restores top-level header geometry after a full-height sidebar opens", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    vim.cmd("topleft vnew")
    local sidebar = api.nvim_get_current_win()
    vim.bo.buftype = "nofile"
    local sidebar_buf = api.nvim_win_get_buf(sidebar)
    runtime.flush("WinResized")
    assert.equals(vim.o.columns, api.nvim_win_get_width(handle.win))
    assert.same({ 0, 0 }, api.nvim_win_get_position(handle.win))
    assert.equals(sidebar_buf, api.nvim_win_get_buf(sidebar))
    assert.equals(sidebar, api.nvim_get_current_win())
    assert.equals(editor, handle.editor)
    assert.equals(vim.o.columns, calls[#calls].width)
  end)

  it("falls back globally on an invalid frame and retries only after a resize", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    local header = runtime.handles()[api.nvim_get_current_tabpage()].win
    local valid = vim.deepcopy(frame)
    frame = { valid = false, rows = {}, first_row = 1, total_rows = 0 }
    runtime.flush("ui.refresh")
    assert.is_false(runtime.active())
    assert.is_false(api.nvim_win_is_valid(header))
    assert.equals(2, vim.o.showtabline)
    calls = {}
    frame = valid
    runtime.request("BufEnter")
    runtime.flush("ui.refresh")
    vim.wait(20)
    assert.equals(0, #calls)
    api.nvim_exec_autocmds("VimResized", { modeline = false })
    vim.wait(20)
    assert.is_true(runtime.active())
    assert.equals(0, vim.o.showtabline)
    assert.equals(1, #calls)
  end)

  it("rolls back scratch allocation when a fixed editing window leaves no header height", function()
    local buffers = api.nvim_list_bufs()
    local height = api.nvim_win_get_height(editor) - 1
    vim.wo[editor].winfixheight = true
    local minimum, preferred = vim.o.winminheight, vim.o.winheight
    vim.o.winheight = height
    vim.o.winminheight = height
    runtime.enable(options, hooks)
    local ok, err = pcall(runtime.flush, "test")
    local active, windows, after = runtime.active(), #api.nvim_list_wins(), api.nvim_list_bufs()
    vim.o.winminheight = minimum
    vim.o.winheight = preferred
    vim.wo[editor].winfixheight = false
    assert.is_true(ok, err)
    assert.is_false(active)
    assert.equals(1, windows)
    assert.same(buffers, after)
    assert.equals(2, vim.o.showtabline)
  end)

  it("suspends globally after manual header closure or only until explicit enable", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    local header = runtime.handles()[api.nvim_get_current_tabpage()].win
    api.nvim_win_close(header, true)
    vim.wait(20)
    assert.is_false(runtime.active())
    assert.equals(2, vim.o.showtabline)
    runtime.request("ui.refresh")
    api.nvim_exec_autocmds("VimResized", { modeline = false })
    vim.wait(20)
    assert.equals(1, #api.nvim_list_wins())
    runtime.enable(options, hooks)
    runtime.flush("test")
    assert.is_true(runtime.active())
    assert.equals(2, #api.nvim_list_wins())
    vim.cmd("only")
    vim.wait(20)
    assert.is_false(runtime.active())
    assert.equals(1, #api.nvim_list_wins())
  end)

  it("creates per-tab headers and distinguishes tab closure from manual header closure", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    local first = api.nvim_get_current_tabpage()
    local header = runtime.handles()[first].win
    vim.cmd("tabnew")
    local second = api.nvim_get_current_tabpage()
    vim.wait(20)
    assert.is_not_nil(runtime.handles()[second])
    assert.is_true(runtime.owns(runtime.handles()[second].win))
    vim.cmd("tabclose")
    vim.wait(20)
    assert.is_true(runtime.active())
    assert.is_nil(runtime.handles()[second])
    assert.equals(header, runtime.handles()[first].win)
    assert.equals(0, vim.o.showtabline)
    calls = {}
    api.nvim_exec_autocmds("TabEnter", { modeline = false })
    api.nvim_exec_autocmds("TabClosed", { modeline = false })
    vim.wait(20)
    assert.equals(1, #calls)
  end)

  it("preserves dirty buffers when native close removes an editor tab with E855", function()
    for _, command in ipairs({ "close", "hide", "api" }) do
      local initial = start_child()
      local result = child_lua(
        [=[
        local command = ...
        vim.o.hidden = true
        vim.cmd("tabnew")
        vim.api.nvim_set_current_tabpage(tab)
        local buf = vim.api.nvim_win_get_buf(editor)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved text" })
        local ok, err = pcall(function()
          if command == "api" then vim.api.nvim_win_close(editor, false) else vim.cmd(command) end
        end)
        return { ok = ok, err = tostring(err), editor_valid = vim.api.nvim_win_is_valid(editor),
          lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false), active = runtime.active(),
          tabs = #vim.api.nvim_list_tabpages(), header_valid = vim.api.nvim_win_is_valid(runtime.handles()[tab] and runtime.handles()[tab].win or -1) }
      ]=],
        { command }
      )
      assert.is_false(result.ok, command)
      assert.matches("E855", result.err)
      assert.is_false(result.editor_valid)
      assert.same({ "unsaved text" }, result.lines)
      assert.is_false(result.active)
      assert.is_false(result.header_valid)
      assert.equals(1, result.tabs)
      vim.fn.jobstop(child)
      child = nil
    end
  end)

  it("tears down headers before quit so clean exits and modified-buffer checks stay native", function()
    start_child()
    vim.fn.rpcnotify(child, "nvim_command", "quit")
    local status = vim.fn.jobwait({ child }, 1000)[1]
    assert.equals(0, status)
    child = nil
    local initial = start_child()
    local result = child_lua([=[
      local buf = vim.api.nvim_win_get_buf(editor)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "dirty" })
      local ok, err = pcall(vim.cmd, "quit")
      return { ok = ok, err = tostring(err), active = runtime.active(), editor_valid = vim.api.nvim_win_is_valid(editor),
        windows = #vim.api.nvim_list_wins(), lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false) }
    ]=])
    assert.is_false(result.ok)
    assert.matches("E37", result.err)
    assert.is_true(result.editor_valid)
    assert.equals(1, result.windows)
    assert.same({ "dirty" }, result.lines)
    assert.is_false(result.active)
  end)

  it("distinguishes floating-window closure from last-editor close and modified-buffer refusal", function()
    start_child()
    assert.is_true(child_lua([=[
      local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), false,
        { relative = "editor", row = 5, col = 5, width = 8, height = 1 })
      vim.api.nvim_win_close(float, true)
      return runtime.active()
    ]=]))
    vim.fn.jobstop(child)
    child = nil
    for _, hidden in ipairs({ true, false }) do
      for _, command in ipairs({ "close", "hide", "api" }) do
        start_child()
        local result = child_lua(
          [=[
          local hidden, command = ...
          vim.o.hidden = hidden
          local buf = vim.api.nvim_win_get_buf(editor)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "dirty" })
          local ok, err = pcall(function()
            if command == "api" then vim.api.nvim_win_close(editor, false) else vim.cmd(command) end
          end)
          return { ok = ok, err = tostring(err), editor_valid = vim.api.nvim_win_is_valid(editor),
            lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false), windows = #vim.api.nvim_list_wins(), active = runtime.active() }
        ]=],
          { hidden, command }
        )
        assert.is_false(result.ok)
        assert.is_true(result.editor_valid)
        assert.same({ "dirty" }, result.lines)
        if hidden or command == "hide" then
          assert.matches("E855", result.err)
          assert.equals(1, result.windows)
          assert.is_false(result.active)
        else
          assert.matches("No write", result.err)
        end
        vim.fn.jobstop(child)
        child = nil
      end
    end
  end)

  it("cleans up before session loading and resumes only while plugin-enabled", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    api.nvim_exec_autocmds("SessionLoadPre", { modeline = false })
    assert.equals(1, #api.nvim_list_wins())
    assert.is_false(runtime.active())
    runtime.request("BufEnter")
    vim.wait(20)
    assert.equals(1, #api.nvim_list_wins())
    api.nvim_exec_autocmds("SessionLoadPost", { modeline = false })
    vim.wait(20)
    assert.is_true(runtime.active())
    assert.equals(2, #api.nvim_list_wins())
    runtime.disable()
    api.nvim_exec_autocmds("SessionLoadPre", { modeline = false })
    api.nvim_exec_autocmds("SessionLoadPost", { modeline = false })
    vim.wait(20)
    assert.is_false(runtime.active())
    assert.equals(1, #api.nvim_list_wins())
  end)

  it("resets the render guard after a failing frame and restores native visibility", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    local normal = hooks.frame
    hooks.frame = function() error("broken formatter") end
    local ok, err = pcall(runtime.flush, "test")
    assert.is_true(ok, err)
    assert.is_false(runtime.active())
    assert.equals(1, #api.nvim_list_wins())
    assert.equals(2, vim.o.showtabline)
    hooks.frame = normal
    api.nvim_exec_autocmds("VimResized", { modeline = false })
    vim.wait(20)
    assert.is_true(runtime.active())
    assert.equals(2, #api.nvim_list_wins())
  end)

  it("relinquishes a header window if it now displays a foreign user buffer", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    vim.bo[handle.buf].bufhidden = "hide"
    local foreign = api.nvim_create_buf(true, false)
    api.nvim_buf_set_lines(foreign, 0, -1, false, { "do not remove" })
    vim.wo[handle.win].winfixbuf = false
    api.nvim_win_set_buf(handle.win, foreign)
    runtime.flush("ui.refresh")
    assert.is_false(runtime.active())
    assert.is_false(runtime.owns(handle.win))
    assert.is_true(api.nvim_win_is_valid(handle.win))
    assert.same({ "do not remove" }, api.nvim_buf_get_lines(foreign, 0, -1, false))
    runtime.disable()
    assert.is_true(api.nvim_win_is_valid(handle.win))
    assert.is_true(api.nvim_buf_is_valid(foreign))
  end)

  it("does not treat closure of a replaced header as closure of owned resources", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    vim.bo[handle.buf].bufhidden = "hide"
    local foreign = api.nvim_create_buf(true, false)
    vim.wo[handle.win].winfixbuf = false
    api.nvim_win_set_buf(handle.win, foreign)
    api.nvim_win_close(handle.win, true)
    assert.is_nil(handle.closing)
    runtime.flush("test")
    assert.is_true(api.nvim_buf_is_valid(foreign))
  end)

  it("remembers the last editor even when focus changes before a deferred refresh", function()
    runtime.enable(options, hooks)
    runtime.flush("test")
    vim.cmd("vnew")
    local second = api.nvim_get_current_win()
    local sidebar_buf = api.nvim_create_buf(false, true)
    local sidebar = api.nvim_open_win(sidebar_buf, false, { split = "right", win = second })
    api.nvim_set_current_win(sidebar)
    runtime.flush("test")
    assert.equals(second, calls[#calls].win)
    assert.equals(sidebar, api.nvim_get_current_win())
  end)

  it("removes hooks and queued work on disable and restores the original native setting", function()
    local listeners = vim.on_key()
    options.auto_toggle_bufferline = false
    runtime.enable(options, hooks)
    assert.equals(0, vim.o.showtabline)
    runtime.flush("test")
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    assert.equals(listeners + 1, vim.on_key())
    calls = {}
    runtime.request("BufEnter")
    runtime.disable()
    vim.wait(20)
    assert.equals(0, #calls)
    assert.equals(listeners, vim.on_key())
    assert.is_false(api.nvim_win_is_valid(handle.win))
    assert.is_false(api.nvim_buf_is_valid(handle.buf))
    assert.same({}, runtime.handles())
    assert.equals(2, vim.o.showtabline)
    assert.is_false(pcall(api.nvim_get_autocmds, { group = "BufferlineMultilineRuntime" }))
    runtime.enable(options, hooks)
    runtime.flush("test")
    runtime.enable(options, hooks)
    runtime.flush("test")
    assert.equals(listeners + 1, vim.on_key())
    assert.equals(2, #api.nvim_list_wins())
    runtime.disable()
    assert.equals(2, vim.o.showtabline)
  end)

  it("auto-hides one listed buffer without suspending and shows exactly one header after BufAdd", function()
    options.always_show_bufferline = false
    runtime.enable(options, hooks)
    runtime.flush("test")
    assert.is_true(runtime.active())
    assert.equals(1, #api.nvim_list_wins())
    assert.equals(0, vim.o.showtabline)
    local extra = api.nvim_create_buf(true, false)
    vim.wait(20)
    assert.equals(2, #api.nvim_list_wins())
    assert.is_true(runtime.owns(runtime.handles()[api.nvim_get_current_tabpage()].win))
    runtime.request("ui.refresh")
    vim.wait(20)
    assert.equals(2, #api.nvim_list_wins())
    api.nvim_buf_delete(extra, { force = true })
    vim.wait(20)
    assert.is_true(runtime.active())
    assert.equals(1, #api.nvim_list_wins())
    assert.equals(0, vim.o.showtabline)
    options.auto_toggle_bufferline = false
    runtime.enable(options, hooks)
    runtime.flush("test")
    assert.equals(2, #api.nvim_list_wins())
  end)

  it("allocates a marked full-width top split with plain rows and byte highlights", function()
    local mouse, laststatus = vim.o.mouse, vim.o.laststatus
    runtime.enable(options, hooks)
    runtime.flush("test")
    local handle = runtime.handles()[api.nvim_get_current_tabpage()]
    assert.is_true(runtime.active())
    assert.is_true(runtime.owns(handle.win))
    assert.equals(editor, api.nvim_get_current_win())
    assert.equals(editor, calls[1].win)
    assert.equals(vim.o.columns, calls[1].width)
    assert.equals(0, vim.o.showtabline)
    assert.equals(mouse, vim.o.mouse)
    assert.equals(laststatus, vim.o.laststatus)
    assert.equals("", api.nvim_win_get_config(handle.win).relative)
    assert.equals(0, api.nvim_win_get_position(handle.win)[1])
    assert.equals(vim.o.columns, api.nvim_win_get_width(handle.win))
    assert.equals(2, api.nvim_win_get_height(handle.win))
    assert.same({ "one%", "two" }, api.nvim_buf_get_lines(handle.buf, 0, -1, false))
    assert.is_false(vim.bo[handle.buf].buflisted)
    assert.equals("nofile", vim.bo[handle.buf].buftype)
    assert.equals("wipe", vim.bo[handle.buf].bufhidden)
    assert.is_false(vim.bo[handle.buf].modifiable)
    assert.is_false(vim.bo[handle.buf].swapfile)
    assert.is_false(vim.wo[handle.win].wrap)
    assert.is_false(vim.wo[handle.win].number)
    assert.is_false(vim.wo[handle.win].relativenumber)
    assert.equals("no", vim.wo[handle.win].signcolumn)
    assert.equals("0", vim.wo[handle.win].foldcolumn)
    assert.equals("", vim.wo[handle.win].winbar)
    assert.is_true(vim.wo[handle.win].winfixheight)
    assert.is_true(vim.wo[handle.win].winfixbuf)
    assert.matches("Normal:BufferLineFill", vim.wo[handle.win].winhighlight, 1, true)
    local marks = api.nvim_buf_get_extmarks(handle.buf, -1, 0, -1, { details = true })
    assert.equals(1, #marks)
    assert.equals(0, marks[1][2])
    assert.equals(0, marks[1][3])
    assert.equals(4, marks[1][4].end_col)
    assert.equals("BufferLineBufferSelected", marks[1][4].hl_group)
  end)
end)
