local api = vim.api
local M = {}
local namespace = api.nvim_create_namespace("bufferline.multiline.runtime")
local marker = "bufferline_multiline"
local handles = {}
local options, hooks, saved
local mode = "disabled"
local generation, pending, guard, group, loading, warned = 0, nil, false, nil, false, false

-- Temporary unavailability must not change the configured renderer.
function M.selected() return mode ~= "disabled" end
function M.active() return mode == "active" end
function M.handles() return handles end

function M.owns(win)
  if not win or not api.nvim_win_is_valid(win) then return false end
  for _, handle in pairs(handles) do
    if handle.win == win and api.nvim_win_get_buf(win) == handle.buf then
      return vim.w[win][marker] == namespace and vim.b[handle.buf][marker] == namespace
    end
  end
  return false
end

local function ordinary(win, tab)
  return win
    and api.nvim_win_is_valid(win)
    and api.nvim_win_get_tabpage(win) == tab
    and not M.owns(win)
    and api.nvim_win_get_config(win).relative == ""
    and vim.bo[api.nvim_win_get_buf(win)].buftype == ""
end

local function editor_for(tab, handle)
  local current = api.nvim_get_current_win()
  if ordinary(current, tab) then return current end
  if ordinary(handle.editor, tab) then return handle.editor end
  for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
    if ordinary(win, tab) then return win end
  end
end

local mouse_keys = {}
for name, button in pairs({ Left = "l", Middle = "m", Right = "r" }) do
  for _, suffix in ipairs({ "Mouse", "Release", "Drag" }) do
    mouse_keys[api.nvim_replace_termcodes("<" .. name .. suffix .. ">", true, false, true)] = {
      button = button,
      press = suffix == "Mouse",
    }
  end
end
for name, direction in pairs({ Up = -1, Down = 1, Left = -1, Right = 1 }) do
  mouse_keys[api.nvim_replace_termcodes("<ScrollWheel" .. name .. ">", true, false, true)] = { direction = direction }
end

local function queue_hit(hit, context, handle)
  local captured, gen, dispatch = vim.deepcopy(hit), generation, hooks.dispatch
  vim.schedule(function()
    if gen ~= generation or not M.active() or handles[context.tab] ~= handle then return end
    if captured.kind == "scroll" then
      handle.first_row = math.max(
        1,
        math.min(math.max(1, handle.frame.total_rows - #handle.frame.rows + 1), handle.first_row + captured.direction)
      )
      M.flush("scroll")
    else
      dispatch(captured, context)
    end
  end)
end

local function candidates(handle)
  local result = {}
  for _, position in ipairs(handle.frame and handle.frame.positions or {}) do
    if api.nvim_buf_is_valid(position.id) and vim.bo[position.id].buflisted then result[#result + 1] = position end
  end
  return result
end

local function reconcile(handle, current)
  local positions = candidates(handle)
  for _, position in ipairs(positions) do
    if position.id == handle.candidate then return position end
  end
  local selected = positions[1]
  for _, position in ipairs(positions) do
    if position.id == current then selected = position end
  end
  handle.candidate = selected and selected.id or nil
  return selected
end

local function return_to_editor(tab, handle)
  local editor = ordinary(handle.editor, tab) and handle.editor or editor_for(tab, handle)
  if editor then api.nvim_set_current_win(editor) end
  return editor
end

local function close_candidate(tab, handle, positions, index)
  local id, editor = handle.candidate, editor_for(tab, handle)
  if not id or not editor then return end
  local gen, dispatch = generation, hooks.dispatch
  vim.schedule(function()
    if gen ~= generation or not M.active() or handles[tab] ~= handle then return end
    if not M.owns(handle.win) or api.nvim_get_current_win() ~= handle.win or not ordinary(editor, tab) then return end
    if not api.nvim_buf_is_valid(id) or not vim.bo[id].buflisted then return end
    local ok, err = pcall(dispatch, { kind = "close", id = id }, { win = editor, tab = tab, button = "l", clicks = 1 })
    if gen == generation and M.active() and handles[tab] == handle and M.owns(handle.win) then
      handle.candidate = id
      if not api.nvim_buf_is_valid(id) or not vim.bo[id].buflisted then
        handle.candidate = nil
        local function surviving(i)
          local candidate = positions[i].id
          if api.nvim_buf_is_valid(candidate) and vim.bo[candidate].buflisted then
            handle.candidate = candidate
            return true
          end
        end
        for i = index + 1, #positions do
          if surviving(i) then break end
        end
        if not handle.candidate then
          for i = index - 1, 1, -1 do
            if surviving(i) then break end
          end
        end
      end
      if api.nvim_get_current_win() == editor then
        guard = true
        api.nvim_set_current_win(handle.win)
        guard = false
      end
      M.flush("navigate")
    end
    if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
  end)
end

local function navigate(handle, key)
  local tab = api.nvim_get_current_tabpage()
  if not M.active() or handles[tab] ~= handle or not M.owns(api.nvim_get_current_win()) then return end
  M.flush("navigate")
  if not M.active() or handles[tab] ~= handle then return end
  if key == "<Esc>" or key == "<CR>" then
    local editor = return_to_editor(tab, handle)
    if key == "<CR>" and editor and handle.candidate then
      queue_hit(
        { kind = "click", id = handle.candidate },
        { win = editor, tab = tab, button = "l", clicks = 1 },
        handle
      )
    end
    M.request("selection")
    return
  end
  local positions = candidates(handle)
  local selected, index
  for i, position in ipairs(positions) do
    if position.id == handle.candidate then
      selected, index = position, i
    end
  end
  if not selected then return end
  if key == "x" then return close_candidate(tab, handle, positions, index) end
  local target
  if key == "h" or key == "l" then
    target = positions[index + (key == "h" and -1 or 1)]
  else
    local direction = key == "k" and -1 or 1
    for i = index + direction, direction == 1 and #positions or 1, direction do
      local position = positions[i]
      if (position.row - selected.row) * direction > 0 then
        if target and target.row ~= position.row then break end
        if not target or math.abs(position.col - selected.col) < math.abs(target.col - selected.col) then
          target = position
        end
      end
    end
  end
  if target then handle.candidate = target.id end
  M.flush("navigate")
end

local function on_key(key)
  local action = mouse_keys[key]
  if not action or not M.active() then return end
  local mouse = vim.fn.getmousepos()
  if not M.owns(mouse.winid) then return end
  local tab = api.nvim_win_get_tabpage(mouse.winid)
  local handle = handles[tab]
  local row = handle.frame and handle.frame.rows[mouse.winrow]
  local editor = editor_for(tab, handle)
  local context = { win = editor, tab = tab, button = action.button, clicks = 1 }
  if action.direction then
    queue_hit({ kind = "scroll", direction = action.direction }, context, handle)
  elseif action.press and row and editor then
    for _, hit in ipairs(row.hits or {}) do
      if mouse.wincol - 1 >= hit.start_col and mouse.wincol - 1 < hit.end_col then
        queue_hit(hit, context, handle)
        break
      end
    end
  end
  return ""
end

function M.request(reason)
  -- Pending headers recover on events rather than requiring setup again.
  if not M.selected() or mode == "paused" or guard or pending then return end
  local token = {}
  local gen = generation
  pending = token
  vim.schedule(function()
    if generation ~= gen or pending ~= token then return end
    pending = nil
    M.flush(reason)
  end)
end

-- Dispose only what this tab positively owns.
local function dispose(tab, handle)
  local previous = guard
  guard = true
  if M.owns(handle.win) and api.nvim_get_current_win() == handle.win then return_to_editor(tab, handle) end
  if M.owns(handle.win) then pcall(api.nvim_win_close, handle.win, true) end
  if handle.buf and api.nvim_buf_is_valid(handle.buf) and vim.b[handle.buf][marker] == namespace then
    pcall(api.nvim_buf_delete, handle.buf, { force = true })
  end
  handles[tab] = nil
  guard = previous
end

local function leave(next_mode)
  generation, pending, mode = generation + 1, nil, next_mode
  for tab, handle in pairs(handles) do
    dispose(tab, handle)
  end
  handles = {}
  -- Native returns only when the renderer is switched off, never on unavailability.
  if hooks and next_mode == "disabled" then hooks.native_visibility(saved) end
end

-- Temporary unavailability: drop this tab's header, stay selected, keep native hidden.
local function unavailable(tab, err)
  generation, pending = generation + 1, nil
  if tab and handles[tab] then
    dispose(tab, handles[tab])
  elseif not tab then
    for key, handle in pairs(handles) do
      dispose(key, handle)
    end
    handles = {}
  end
  -- Other tabs' surviving headers must still accept input.
  if mode ~= "paused" then mode = next(handles) and "active" or "pending" end
  vim.o.showtabline = 0
  if err and not warned then
    warned = true
    vim.notify("bufferline: multiline unavailable: " .. tostring(err), vim.log.levels.WARN)
  end
end

-- WinClosed runs before removal, so the closing window is still counted here.
local function editors_in(tab)
  local count = 0
  for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
    if not M.owns(win) and api.nvim_win_get_config(win).relative == "" then count = count + 1 end
  end
  return count
end

-- Re-render once the layout settles. Generation-guarded, so it cannot spin.
local function recover(reason)
  local gen = generation
  vim.schedule(function()
    if generation ~= gen or not M.selected() or mode == "paused" then return end
    M.request(reason)
  end)
end

function M.disable()
  if group then api.nvim_del_augroup_by_id(group) end
  group = nil
  vim.on_key(nil, namespace)
  leave("disabled")
  options, hooks, saved, loading, warned = nil, nil, nil, false, false
end

function M.enable(config, callbacks)
  M.disable()
  saved = vim.o.showtabline
  options, hooks = config, callbacks
  -- Selected immediately; "active" is only reached once a header actually renders.
  mode = "pending"
  vim.o.showtabline = 0
  vim.on_key(on_key, namespace)
  group = api.nvim_create_augroup("BufferlineMultilineRuntime", { clear = true })
  api.nvim_create_autocmd({
    "BufAdd",
    "BufDelete",
    "BufWipeout",
    "BufEnter",
    "BufFilePost",
    "BufModifiedSet",
    "DiagnosticChanged",
    "ColorScheme",
    "TabEnter",
    "TabClosed",
  }, {
    group = group,
    callback = function(event)
      if api.nvim_buf_is_valid(event.buf) and vim.b[event.buf][marker] == namespace then return end
      M.request(event.event)
    end,
  })
  api.nvim_create_autocmd("SessionLoadPre", {
    group = group,
    callback = function()
      -- Paused: selected, no header, and native stays hidden until the load finishes.
      loading = true
      leave("paused")
    end,
  })
  api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = function()
      if not loading then return end
      loading, mode = false, "pending"
      M.request("SessionLoadPost")
    end,
  })
  api.nvim_create_autocmd("QuitPre", {
    group = group,
    callback = function()
      if guard or not M.selected() or mode == "paused" then return end
      local tab = api.nvim_get_current_tabpage()
      -- Quitting the header itself never quits the editor; WinClosed disposes it.
      if not ordinary(api.nvim_get_current_win(), tab) then return end
      local editors = 0
      for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
        if ordinary(win, tab) then editors = editors + 1 end
      end
      if editors > 1 then return end
      -- Owned headers must not prevent final quit; a refused quit can recover.
      if #api.nvim_list_tabpages() > 1 then
        unavailable(tab)
      else
        unavailable()
      end
      recover("QuitPre")
    end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(event)
      if guard or not M.selected() or mode == "paused" then return end
      local win = tonumber(event.match)
      if not api.nvim_win_is_valid(win) or api.nvim_win_get_config(win).relative ~= "" then return end
      for tab, handle in pairs(handles) do
        if handle.win == win and M.owns(win) then
          -- Wait until the closing command finishes before recreating the header.
          handle.closing = true
          local gen = generation
          vim.schedule(function()
            if handles[tab] ~= handle then return end
            if not api.nvim_tabpage_is_valid(tab) then
              dispose(tab, handle)
            elseif generation == gen and M.selected() then
              unavailable(tab)
            end
            recover("WinClosed")
          end)
          return
        end
      end
      local tab = api.nvim_get_current_tabpage()
      local handle = handles[tab]
      if not handle or handle.closing or not M.owns(handle.win) then return end
      -- WinClosed runs before removal, so a real split still exists during header teardown.
      if editors_in(tab) == 1 and api.nvim_win_get_tabpage(win) == tab then
        unavailable(tab)
        recover("WinClosed")
      end
    end,
  })
  api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
    group = group,
    callback = function(event)
      if guard then return end
      M.request(event.event)
    end,
  })
  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if guard or not M.selected() or mode == "paused" then return end
      local tab = api.nvim_get_current_tabpage()
      local handle = handles[tab]
      if handle and ordinary(api.nvim_get_current_win(), tab) then handle.editor = api.nvim_get_current_win() end
      if handle and M.owns(api.nvim_get_current_win()) then
        local editor = editor_for(tab, handle)
        handle.candidate = editor and api.nvim_win_get_buf(editor) or nil
        reconcile(handle, handle.candidate)
      end
      M.request("WinEnter")
    end,
  })
  M.request("enable")
end

local function allocate(handle, height)
  handle.buf = api.nvim_create_buf(false, true)
  vim.b[handle.buf][marker] = namespace
  for _, key in ipairs({ "h", "j", "k", "l", "x", "<CR>", "<Esc>" }) do
    vim.keymap.set(
      "n",
      key,
      function() navigate(handle, key) end,
      { buffer = handle.buf, silent = true, nowait = true }
    )
  end
  for name, value in pairs({
    buftype = "nofile",
    filetype = "bufferline",
    bufhidden = "wipe",
    swapfile = false,
    buflisted = false,
  }) do
    vim.bo[handle.buf][name] = value
  end
  handle.win =
    api.nvim_open_win(handle.buf, false, { split = "above", win = handle.editor, height = height, noautocmd = true })
  vim.w[handle.win][marker] = namespace
  for name, value in pairs({
    wrap = false,
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    foldenable = false,
    winbar = "",
    statuscolumn = "",
    winfixheight = true,
    winfixbuf = true,
    cursorline = false,
    cursorcolumn = false,
    spell = false,
    list = false,
    colorcolumn = "",
    winhighlight = "Normal:BufferLineFill",
  }) do
    vim.wo[handle.win][name] = value
  end
end

-- Keep the header in its split region when another editor gains focus.
local function header_region(layout, win, tab)
  if layout[1] == "leaf" then return false end
  local function editors_below(node)
    if node[1] == "leaf" then return ordinary(node[2], tab) end
    -- Only the top edge borders the header; a bottom utility split is harmless.
    if node[1] == "col" then return editors_below(node[2][1]) end
    for _, child in ipairs(node[2]) do
      if not editors_below(child) then return false end
    end
    return true
  end
  for index, child in ipairs(layout[2]) do
    if child[1] == "leaf" and child[2] == win then
      if layout[1] ~= "col" or index ~= 1 then return false end
      return layout[2][2] ~= nil and editors_below(layout[2][2])
    end
    if header_region(child, win, tab) then return true end
  end
  return false
end

local function minimum_height(layout)
  if layout[1] == "leaf" then
    if M.owns(layout[2]) then return 0 end
    return math.max(1, vim.o.winminheight) + (vim.wo[layout[2]].winbar ~= "" and 1 or 0)
  end
  local height, count = 0, 0
  for _, child in ipairs(layout[2]) do
    local value = minimum_height(child)
    if value > 0 then
      count = count + 1
      height = layout[1] == "row" and math.max(height, value) or height + value
    end
  end
  return height + (layout[1] == "col" and math.max(0, count - 1) or 0)
end

local function render(reason)
  if
    options.auto_toggle_bufferline
    and not options.always_show_bufferline
    and require("bufferline.utils").get_buf_count() <= 1
  then
    -- Deliberate auto-hide, not unavailability: stay ready, drop headers, hide native.
    if next(handles) then leave("active") end
    mode = "active"
    vim.o.showtabline = 0
    return
  end
  local tab = api.nvim_get_current_tabpage()
  local handle = handles[tab] or { first_row = 1 }
  handles[tab] = handle
  if handle.win and not M.owns(handle.win) then
    -- A foreign buffer's window is no longer ours to dispose.
    unavailable(tab)
    return
  end
  handle.editor = editor_for(tab, handle)
  if not handle.editor then return end
  if handle.win and not header_region(vim.fn.winlayout(), handle.win, tab) then
    api.nvim_win_set_config(handle.win, { split = "above", win = handle.editor })
  end
  local current = api.nvim_win_get_buf(handle.editor)
  local budget = vim.o.lines
    - vim.o.cmdheight
    - (vim.o.laststatus > 0 and 1 or 0)
    - minimum_height(vim.fn.winlayout())
    - 1
  if budget < 1 then
    -- Not enough height right now. Temporary, not an error: no header, no native, no warning.
    unavailable(tab)
    return
  end
  local focused = M.owns(api.nvim_get_current_win())
  local function build_frame()
    return api.nvim_win_call(
      handle.editor,
      function()
        return hooks.frame(
          api.nvim_win_get_width(handle.win or handle.editor),
          math.min(options.multiline.max_rows, budget),
          {
            first_row = handle.first_row,
            current_id = focused and handle.candidate or current,
            reveal = focused
                and (reason == "navigate" or reason == "WinEnter" or reason == "WinResized" or reason == "VimResized")
              or not focused and (current ~= handle.last_current or reason == "WinResized" or reason == "VimResized"),
          }
        )
      end
    )
  end
  local frame = build_frame()
  if focused and frame and frame.valid ~= false then
    handle.frame = frame
    local previous = handle.candidate
    reconcile(handle, current)
    if previous ~= handle.candidate then
      reason = "navigate"
      frame = build_frame()
    end
  end
  if not frame or frame.valid == false or #frame.rows == 0 or #frame.rows > budget then
    -- Frame could not be produced or does not fit: temporary, recovers on the next event.
    unavailable(tab)
    return
  end
  vim.o.showtabline = 0
  local ok = pcall(function()
    if not handle.win then allocate(handle, #frame.rows) end
    if api.nvim_win_get_height(handle.win) ~= #frame.rows then api.nvim_win_set_height(handle.win, #frame.rows) end
    assert(api.nvim_win_get_height(handle.win) == #frame.rows)
    for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
      if ordinary(win, tab) then assert(api.nvim_win_get_height(win) >= math.max(1, vim.o.winminheight)) end
    end
  end)
  if not ok then
    -- Allocation or height enforcement failed: roll back this tab and stay hidden.
    unavailable(tab)
    return
  end
  local lines = {}
  for _, row in ipairs(frame.rows) do
    lines[#lines + 1] = row.text
  end
  if not vim.deep_equal(lines, api.nvim_buf_get_lines(handle.buf, 0, -1, false)) then
    vim.bo[handle.buf].modifiable = true
    api.nvim_buf_set_lines(handle.buf, 0, -1, false, lines)
    vim.bo[handle.buf].modifiable = false
  end
  api.nvim_buf_clear_namespace(handle.buf, namespace, 0, -1)
  for i, row in ipairs(frame.rows) do
    for _, span in ipairs(row.spans or {}) do
      api.nvim_buf_set_extmark(handle.buf, namespace, i - 1, span.start_col, {
        end_col = span.end_col,
        hl_group = span.highlight,
        priority = 100,
      })
    end
  end
  vim.bo[handle.buf].modifiable = false
  handle.frame, handle.first_row, handle.last_current = frame, frame.first_row, current
  for _, position in ipairs(frame.positions or {}) do
    if position.id == current and position.byte_col then
      api.nvim_buf_set_extmark(handle.buf, namespace, position.row - frame.first_row, position.byte_col, {
        end_col = position.byte_end,
        hl_group = "BufferLineBufferSelected",
        priority = 150,
      })
    end
  end
  local selected = reconcile(handle, current)
  if focused and selected and selected.byte_col then
    api.nvim_win_set_cursor(handle.win, { selected.row - frame.first_row + 1, selected.byte_col })
    api.nvim_buf_set_extmark(handle.buf, namespace, selected.row - frame.first_row, selected.byte_col, {
      end_col = selected.byte_end,
      hl_group = "IncSearch",
      priority = 200,
    })
  end
  if vim.tbl_contains({ "slope", "slant", "padded_slope", "padded_slant" }, options.separator_style) then
    local fill = api.nvim_get_hl(0, { name = "BufferLineFill", link = false })
    api.nvim_set_hl(0, "BufferLineMultilineSlope", { fg = fill.bg or "NONE" })
    for i, row in ipairs(frame.rows) do
      for _, span in ipairs(row.spans or {}) do
        if span.highlight and span.highlight:match("^BufferLineSeparator") then
          local text = row.text:sub(span.start_col + 1, span.end_col)
          local start_col = span.start_col
          for _, char in ipairs(vim.fn.split(text, "\\zs")) do
            if char == "" or char == "" or char == "" then
              api.nvim_buf_set_extmark(handle.buf, namespace, i - 1, start_col, {
                end_col = start_col + #char,
                hl_group = "BufferLineMultilineSlope",
                priority = 210,
              })
            end
            start_col = start_col + #char
          end
        end
      end
    end
  end
  -- A header is on screen: readiness is restored and a later error may warn again.
  mode, warned = "active", false
end

function M.flush(reason)
  -- Session loading must finish before any recovery render.
  if not M.selected() or mode == "paused" or guard then return end
  pending, guard = nil, true
  vim.o.showtabline = 0
  for tab, handle in pairs(handles) do
    if not api.nvim_tabpage_is_valid(tab) then dispose(tab, handle) end
  end
  local tab = api.nvim_get_current_tabpage()
  local ok, err = pcall(render, reason)
  guard = false
  if not ok then unavailable(tab, err) end
end

return M
