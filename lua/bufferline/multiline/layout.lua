local M = {}
local displaywidth = vim.fn.strdisplaywidth

local function new_row() return { text = "", spans = {}, hits = {} } end

local function append(row, text, highlight, action)
  if text == "" then return end
  local byte_start, cell_start = #row.text, displaywidth(row.text)
  row.text = row.text .. text
  row.spans[#row.spans + 1] = { start_col = byte_start, end_col = #row.text, highlight = highlight }
  if action then
    local previous = row.hits[#row.hits]
    if
      previous
      and previous.end_col == cell_start
      and previous.kind == action.kind
      and previous.id == action.id
      and previous.direction == action.direction
    then
      previous.end_col = displaywidth(row.text)
    else
      row.hits[#row.hits + 1] = {
        start_col = cell_start,
        end_col = displaywidth(row.text),
        kind = action.kind,
        id = action.id,
        direction = action.direction,
      }
    end
  end
end

local function prefix(text, width)
  local bytes = 0
  for index = 0, vim.fn.strchars(text, true) - 1 do
    local char = vim.fn.strcharpart(text, index, 1, true)
    local finish = bytes + #char
    if displaywidth(text:sub(1, finish)) > width then break end
    bytes = finish
  end
  return text:sub(1, bytes)
end

local function fit_entry(entry, width)
  local text, action = "", nil
  for _, run in ipairs(entry.runs) do
    text = text .. run.text
    if run.action and run.action.kind ~= "close" then action = action or run.action end
  end
  local size = displaywidth(text)
  if size <= width then return { entry = entry, runs = entry.runs, width = size } end
  local ellipsis = displaywidth("…") <= width and "…" or ""
  local clipped = prefix(text, width - displaywidth(ellipsis))
  local runs, remaining = {}, #clipped
  for _, run in ipairs(entry.runs) do
    if remaining <= 0 then break end
    local part = run.text:sub(1, remaining)
    runs[#runs + 1] = { text = part, highlight = run.highlight, action = run.action }
    remaining = remaining - #part
  end
  local last = runs[#runs] or entry.runs[1]
  if ellipsis ~= "" then runs[#runs + 1] = { text = ellipsis, highlight = last.highlight, action = action } end
  return { entry = entry, runs = runs, width = displaywidth(clipped .. ellipsis) }
end

local function pack(entries, width)
  local rows = { { entries = {}, width = 0 } }
  for _, entry in ipairs(entries) do
    local item = fit_entry(entry, width)
    local row = rows[#rows]
    if row.width > 0 and row.width + item.width > width then
      row = { entries = {}, width = 0 }
      rows[#rows + 1] = row
    end
    row.entries[#row.entries + 1] = item
    row.width = row.width + item.width
  end
  return rows
end

local function gutter(row, width, count, direction, geometry)
  if width == 0 then return end
  if count == nil then return append(row, string.rep(" ", width), geometry.fill_hl) end
  local text = direction == -1 and ("<" .. count) or (count .. ">")
  local padding = string.rep(" ", width - #text)
  text = direction == -1 and (text .. padding) or (padding .. text)
  append(row, text, geometry.marker_hl, { kind = "scroll", direction = direction })
end

local function offset(row, value, fill_hl)
  if not value or not value.width or value.width == 0 then return end
  local text = prefix(value.text or "", value.width)
  local byte_start = #row.text
  append(row, text, fill_hl)
  for _, span in ipairs(value.spans or {}) do
    local start_col, end_col = math.max(0, span.start_col), math.min(#text, span.end_col)
    if start_col < end_col then
      row.spans[#row.spans + 1] = {
        start_col = byte_start + start_col,
        end_col = byte_start + end_col,
        highlight = span.highlight,
      }
    end
  end
  append(row, string.rep(" ", math.max(0, value.width - displaywidth(text))), fill_hl)
end

local function invalid_frame()
  return {
    valid = false,
    rows = {},
    visible_components = {},
    total_rows = 0,
    first_row = 1,
    before_count = 0,
    after_count = 0,
  }
end

function M.plan(entries, geometry, viewport)
  viewport = viewport or {}
  local left_width = geometry.left and geometry.left.width or 0
  local right_width = geometry.right and geometry.right.width or 0
  local width, max_rows = geometry.width - left_width - right_width, geometry.max_rows
  if width <= 0 then return invalid_frame() end
  local packed, gutter_width = pack(entries, width), 0
  if #packed > max_rows then
    local count = 0
    for _, entry in ipairs(entries) do
      if entry.focusable then count = count + 1 end
    end
    gutter_width = #tostring(count) + 2
    width = width - gutter_width * 2
    if width <= 0 then return invalid_frame() end
    packed = pack(entries, width)
  end
  local first = math.max(1, math.min(viewport.first_row or 1, math.max(1, #packed - max_rows + 1)))
  if viewport.reveal then
    for index, row in ipairs(packed) do
      for _, item in ipairs(row.entries) do
        local entry = item.entry
        local current = viewport.current_id ~= nil and entry.id == viewport.current_id
          or viewport.current_id == nil and entry.current
        if entry.focusable and current then
          if index < first then first = index end
          if index >= first + max_rows then first = index - max_rows + 1 end
        end
      end
    end
  end
  local last = math.min(#packed, first + max_rows - 1)
  local before, after = 0, 0
  for index, row in ipairs(packed) do
    for _, item in ipairs(row.entries) do
      if item.entry.focusable and index < first then before = before + 1 end
      if item.entry.focusable and index > last then after = after + 1 end
    end
  end
  local rows, visible, positions, seen = {}, {}, {}, {}
  for index, packed_row in ipairs(packed) do
    local is_visible = index >= first and index <= last
    local row = new_row()
    offset(row, geometry.left, geometry.fill_hl)
    gutter(row, gutter_width, index == first and first > 1 and before or nil, -1, geometry)
    for _, item in ipairs(packed_row.entries) do
      local position
      for _, run in ipairs(item.runs) do
        local action = run.action
        if item.entry.focusable and action and action.kind == "click" and run.text ~= "" then
          if not seen[action.id] then
            position = { id = action.id, row = index, col = displaywidth(row.text) }
            if is_visible then position.byte_col = #row.text end
            positions[#positions + 1], seen[action.id] = position, true
          end
          if position and is_visible then position.byte_end = #row.text + #run.text end
        end
        append(row, run.text, run.highlight, run.action)
      end
      if is_visible and item.entry.focusable then visible[#visible + 1] = item.entry.component end
    end
    append(
      row,
      string.rep(" ", math.max(0, left_width + gutter_width + width - displaywidth(row.text))),
      geometry.fill_hl
    )
    gutter(row, gutter_width, index == last and last < #packed and after or nil, 1, geometry)
    offset(row, geometry.right, geometry.fill_hl)
    if is_visible then rows[#rows + 1] = row end
  end
  return {
    positions = positions,
    rows = rows,
    visible_components = visible,
    total_rows = #packed,
    first_row = first,
    before_count = before,
    after_count = after,
  }
end

return M
