describe("Multiline shared state", function()
  local bufferline, state
  before_each(function()
    bufferline = require("bufferline")
    state = require("bufferline.state")
    vim.o.hidden = true
    vim.o.termguicolors = true
    bufferline.setup({ options = { show_buffer_icons = false, persist_buffer_sort = false } })
  end)
  after_each(function()
    bufferline.setup({ options = { persist_buffer_sort = false } })
    vim.cmd("silent! %bwipeout!")
  end)

  it("computes complete ordered entries without evaluating a native tabline", function()
    vim.cmd("edit first.txt")
    vim.cmd("edit second.txt")
    vim.o.showtabline = 0
    local components = bufferline.compute()
    assert.same(2, #components)
    assert.same(2, #state.components)
    assert.same(components[2].id, vim.api.nvim_get_current_buf())
  end)

  it("reuses native output after a standalone computation", function()
    vim.cmd("edit native.txt")
    local before = nvim_bufferline()
    bufferline.compute()
    assert.same(before, nvim_bufferline())
  end)

  it("dispatches a click in its captured editing window", function()
    vim.cmd("edit origin.txt")
    local origin = vim.api.nvim_get_current_win()
    local target = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(target, "target.txt")
    vim.cmd("vsplit")
    local other = vim.api.nvim_get_current_win()
    local original = vim.api.nvim_get_current_buf()
    require("bufferline.commands").dispatch({ kind = "click", id = target }, {
      win = origin,
      tab = vim.api.nvim_get_current_tabpage(),
      button = "l",
    })
    assert.same(target, vim.api.nvim_win_get_buf(origin))
    assert.same(original, vim.api.nvim_win_get_buf(other))
    assert.same(origin, vim.api.nvim_get_current_win())
    vim.cmd("only")
  end)

  it("preserves configured function and string callback semantics", function()
    local commands = require("bufferline.commands")
    local config = require("bufferline.config")
    local target = vim.api.nvim_get_current_buf()
    local context = { win = vim.api.nvim_get_current_win(), tab = vim.api.nvim_get_current_tabpage(), button = "m" }
    local received
    config.options.middle_mouse_command = function(id) received = id end
    commands.dispatch({ kind = "click", id = target }, context)
    assert.same(target, received)
    config.options.right_mouse_command = "let g:multiline_dispatch_id = %d"
    context.button = "r"
    commands.dispatch({ kind = "click", id = target }, context)
    assert.same(target, vim.g.multiline_dispatch_id)
  end)

  it("does not dispatch into a closed editing context", function()
    local target = vim.api.nvim_get_current_buf()
    assert.is_false(require("bufferline.commands").dispatch({ kind = "click", id = target }, {
      win = -1,
      tab = vim.api.nvim_get_current_tabpage(),
      button = "l",
    }))
  end)
end)
