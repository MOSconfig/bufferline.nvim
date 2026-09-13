local M = {}

function M.normalize(conf, version)
  local result = vim.deepcopy(conf or {})
  local options = result.options
  if not options or options.multiline == nil then return result end
  local multiline = options.multiline
  assert(type(multiline) == "table", "bufferline: multiline must be a table")
  assert(
    multiline.enabled == nil or type(multiline.enabled) == "boolean",
    "bufferline: multiline.enabled must be boolean"
  )
  multiline.enabled = multiline.enabled == true
  if not multiline.enabled then return result end
  local rows = multiline.max_rows == nil and 3 or multiline.max_rows
  assert(
    type(rows) == "number" and rows > 0 and rows < math.huge and rows == math.floor(rows),
    "bufferline: multiline.max_rows must be a finite positive integer"
  )
  multiline.max_rows = rows

  version = version or vim.version()
  assert(version.major > 0 or version.minor >= 12, "bufferline: multiline requires Neovim 0.12+")
  assert(options.mode == nil or options.mode == "buffers", "bufferline: multiline only supports mode='buffers'")
  assert(not (options.hover and options.hover.enabled), "bufferline: multiline does not support hover")
  assert(not options.show_tab_indicators, "bufferline: multiline does not support show_tab_indicators=true")
  assert(not options.show_close_icon, "bufferline: multiline does not support show_close_icon=true")
  assert(
    options.custom_areas == nil or (type(options.custom_areas) == "table" and next(options.custom_areas) == nil),
    "bufferline: multiline does not support custom_areas"
  )
  options.show_tab_indicators = false
  options.show_close_icon = false
  return result
end

return M
