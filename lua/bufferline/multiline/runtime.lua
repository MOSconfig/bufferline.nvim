local api = vim.api
local M = {}
local namespace = api.nvim_create_namespace("bufferline.multiline.runtime")
local marker = "bufferline_multiline"
local handles = {}
local options, hooks, saved
local mode = "disabled"
local generation, pending, guard, group, loading = 0, nil, false, nil, false

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
  if not M.active() or guard or pending then return end
  local token = {}
  local gen = generation
  pending = token
  vim.schedule(function()
    if generation ~= gen or pending ~= token then return end
    pending = nil
    M.flush(reason)
  end)
end

local function leave(next_mode)
  generation, pending, mode = generation + 1, nil, next_mode
  guard = true
  for tab, handle in pairs(handles) do
    if M.owns(handle.win) and api.nvim_get_current_win() == handle.win then return_to_editor(tab, handle) end
    if M.owns(handle.win) then pcall(api.nvim_win_close, handle.win, true) end
    if handle.buf and api.nvim_buf_is_valid(handle.buf) and vim.b[handle.buf][marker] == namespace then
      pcall(api.nvim_buf_delete, handle.buf, { force = true })
    end
  end
  handles = {}
  guard = false
  if hooks and next_mode ~= "active" then hooks.native_visibility(saved) end
end

function M.disable()
  if group then api.nvim_del_augroup_by_id(group) end
  group = nil
  vim.on_key(nil, namespace)
  leave("disabled")
  options, hooks, saved, loading = nil, nil, nil, false
end

function M.enable(config, callbacks)
  M.disable()
  saved = vim.o.showtabline
  options, hooks = config, callbacks
  mode = "active"
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
      loading = true
      leave("suspended")
    end,
  })
  api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = function()
      if not loading then return end
      loading, mode = false, "active"
      M.request("SessionLoadPost")
    end,
  })
  api.nvim_create_autocmd("QuitPre", {
    group = group,
    callback = function()
      if M.active() and not guard then leave("suspended") end
    end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(event)
      if guard or not M.active() then return end
      local win = tonumber(event.match)
      if not api.nvim_win_is_valid(win) or api.nvim_win_get_config(win).relative ~= "" then return end
      for tab, handle in pairs(handles) do
        if handle.win == win and M.owns(win) then
          handle.closing = true
          local gen = generation
          vim.schedule(function()
            if generation ~= gen then return end
            if api.nvim_tabpage_is_valid(tab) then
              leave("suspended")
            else
              handles[tab] = nil
            end
          end)
          return
        end
      end
      local tab = api.nvim_get_current_tabpage()
      local handle = handles[tab]
      if not handle or handle.closing or not M.owns(handle.win) then return end
      local count = 0
      for _, candidate in ipairs(api.nvim_tabpage_list_wins(tab)) do
        if not M.owns(candidate) and api.nvim_win_get_config(candidate).relative == "" then count = count + 1 end
      end
      -- WinClosed runs before removal, so a real split still exists during header teardown.
      if count == 1 and api.nvim_win_get_tabpage(win) == tab then leave("suspended") end
    end,
  })
  api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
    group = group,
    callback = function(event)
      if guard then return end
      if mode == "fallback" then mode = "active" end
      M.request(event.event)
    end,
  })
  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if guard or not M.active() then return end
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
  for _, key in ipairs({ "h", "j", "k", "l", "<CR>", "<Esc>" }) do
    vim.keymap.set(
      "n",
      key,
      function() navigate(handle, key) end,
      { buffer = handle.buf, silent = true, nowait = true }
    )
  end
  for name, value in pairs({ buftype = "nofile", bufhidden = "wipe", swapfile = false, buflisted = false }) do
    vim.bo[handle.buf][name] = value
  end
  handle.win = api.nvim_open_win(handle.buf, false, { split = "above", win = -1, height = height, noautocmd = true })
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
    if next(handles) then leave("active") end
    vim.o.showtabline = 0
    return
  end
  local tab = api.nvim_get_current_tabpage()
  local handle = handles[tab] or { first_row = 1 }
  handles[tab] = handle
  if handle.win and not M.owns(handle.win) then
    leave("suspended")
    return
  end
  handle.editor = editor_for(tab, handle)
  if not handle.editor then return end
  if
    handle.win
    and (api.nvim_win_get_width(handle.win) ~= vim.o.columns or api.nvim_win_get_position(handle.win)[1] ~= 0)
  then
    api.nvim_win_set_config(handle.win, { split = "above", win = -1 })
  end
  local current = api.nvim_win_get_buf(handle.editor)
  local budget = vim.o.lines
    - vim.o.cmdheight
    - (vim.o.laststatus > 0 and 1 or 0)
    - minimum_height(vim.fn.winlayout())
    - 1
  if budget < 1 then
    leave("fallback")
    return
  end
  local focused = M.owns(api.nvim_get_current_win())
  local function build_frame()
    return api.nvim_win_call(
      handle.editor,
      function()
        return hooks.frame(vim.o.columns, math.min(options.multiline.max_rows, budget), {
          first_row = handle.first_row,
          current_id = focused and handle.candidate or current,
          reveal = focused
              and (reason == "navigate" or reason == "WinEnter" or reason == "WinResized" or reason == "VimResized")
            or not focused and (current ~= handle.last_current or reason == "WinResized" or reason == "VimResized"),
        })
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
    leave("fallback")
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
    leave("fallback")
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
      })
    end
  end
  vim.bo[handle.buf].modifiable = false
  handle.frame, handle.first_row, handle.last_current = frame, frame.first_row, current
  local selected = reconcile(handle, current)
  if focused and selected and selected.byte_col then
    api.nvim_win_set_cursor(handle.win, { selected.row - frame.first_row + 1, selected.byte_col })
    api.nvim_buf_set_extmark(handle.buf, namespace, selected.row - frame.first_row, selected.byte_col, {
      end_col = selected.byte_end,
      hl_group = "IncSearch",
      priority = 200,
    })
  end
end

function M.flush(reason)
  if not M.active() or guard then return end
  pending, guard = nil, true
  local ok = pcall(render, reason)
  guard = false
  if not ok then leave("fallback") end
end

return M
