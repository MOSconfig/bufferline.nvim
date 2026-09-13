if vim.fn.has("nvim-0.12") == 0 then return end

local api = vim.api
local bufferline = require("bufferline")
local runtime = require("bufferline.multiline.runtime")
local state = require("bufferline.state")

describe("Multiline picking", function()
  local old_getchar
  before_each(function()
    old_getchar = vim.fn.getchar
    runtime.disable()
    vim.o.hidden = true
    vim.cmd("silent! tabonly | silent! only | silent! %bwipeout!")
    for index = 1, 8 do
      vim.cmd("badd pick-example-" .. index .. ".txt")
    end
    vim.cmd("buffer pick-example-1.txt")
    bufferline.setup({ options = { multiline = { enabled = true, max_rows = 2 }, persist_buffer_sort = false } })
    runtime.flush("test")
  end)
  after_each(function()
    vim.fn.getchar = old_getchar
    bufferline.setup({ options = { persist_buffer_sort = false } })
    vim.cmd("silent! tabonly | silent! only | silent! %bwipeout!")
  end)

  it("paints pick labels synchronously before requesting input", function()
    local target
    vim.fn.getchar = function()
      assert.is_true(state.is_picking)
      local h = runtime.handles()[api.nvim_get_current_tabpage()]
      local text = table.concat(api.nvim_buf_get_lines(h.buf, 0, -1, false))
      target = state.visible_components[#state.visible_components]
      assert.is_truthy(text:find(target.letter, 1, true))
      return vim.fn.char2nr(target.letter)
    end
    bufferline.pick()
    assert.same(target.id, api.nvim_get_current_buf())
    assert.is_false(state.is_picking)
  end)

  it("clears picking after a configured close callback throws", function()
    require("bufferline.config").options.close_command = function() error("close refused") end
    vim.fn.getchar = function() return vim.fn.char2nr(state.components[1].letter) end
    assert.has_error(function() bufferline.close_with_pick() end)
    assert.is_false(state.is_picking)
  end)
end)
