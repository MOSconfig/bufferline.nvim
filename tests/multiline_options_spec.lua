describe("Multiline options", function()
  local options
  before_each(function() options = require("bufferline.multiline.options") end)

  it("keeps the default renderer unchanged on older Neovim", function()
    assert.same({}, options.normalize({}, { major = 0, minor = 8 }))
    local conf =
      { options = { mode = "buffers", show_close_icon = true, show_tab_indicators = true, max_name_length = 12 } }
    local result = options.normalize(conf, { major = 0, minor = 8 })
    assert.same(conf, result)
    assert.is_true(result.options.show_close_icon)
    assert.is_true(result.options.show_tab_indicators)
    conf.options.multiline = { enabled = false }
    assert.is_false(options.normalize(conf, { major = 0, minor = 8 }).options.multiline.enabled)
  end)

  it("ignores inactive row settings when multiline is disabled", function()
    local conf = { options = { multiline = { enabled = false, max_rows = 0 } } }
    assert.same(conf, options.normalize(conf, { major = 0, minor = 8 }))
  end)

  it("normalizes only multiline defaults without mutating the input", function()
    local input = { options = { multiline = { enabled = true } } }
    local result = options.normalize(input, { major = 0, minor = 12 })
    assert.same({ enabled = true, max_rows = 3 }, result.options.multiline)
    assert.is_false(result.options.show_tab_indicators)
    assert.is_false(result.options.show_close_icon)
    assert.is_nil(input.options.multiline.max_rows)
    assert.is_nil(input.options.show_close_icon)
  end)

  it("rejects unsupported versions and invalid row limits", function()
    assert.has_error(
      function() options.normalize({ options = { multiline = { enabled = true } } }, { major = 0, minor = 11 }) end
    )
    for _, rows in ipairs({ 0, -1, 1.5, math.huge, "3", false }) do
      assert.has_error(
        function()
          options.normalize(
            { options = { multiline = { enabled = true, max_rows = rows } } },
            { major = 0, minor = 12 }
          )
        end
      )
    end
  end)

  it("rejects explicit unsupported features", function()
    for _, extra in ipairs({
      { mode = "tabs" },
      { hover = { enabled = true } },
      { show_tab_indicators = true },
      { show_close_icon = true },
      { custom_areas = { left = function() return {} end } },
    }) do
      extra.multiline = { enabled = true }
      assert.has_error(function() options.normalize({ options = extra }, { major = 0, minor = 12 }) end)
    end
  end)

  it("requires a table with boolean enabled", function()
    for _, value in ipairs({ true, 3, "rows", { enabled = 1 } }) do
      assert.has_error(function() options.normalize({ options = { multiline = value } }, { major = 0, minor = 12 }) end)
    end
  end)

  it("leaves the active setup intact after invalid reconfiguration", function()
    local bufferline = require("bufferline")
    bufferline.setup({ options = { max_name_length = 9 } })
    local tabline = vim.o.tabline
    assert.has_error(function() bufferline.setup({ options = { multiline = { enabled = true, max_rows = 0 } } }) end)
    assert.same(9, require("bufferline.config").options.max_name_length)
    assert.same(tabline, vim.o.tabline)
  end)
end)
