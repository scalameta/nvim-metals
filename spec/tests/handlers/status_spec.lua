local handlers = require("metals.handlers")

-- We're not going to test the entire status functionality here, but only the
-- handler part of it just to ensure we can get a display a status.
describe("metals/status", function()
  it("correctly can set the status", function()
    local msg = "here is some text"
    local metals_status = {
      text = msg,
    }
    local ctx = {
      client_id = "metals",
      bufnr = "1",
    }
    handlers["metals/status"](nil, metals_status, ctx)
    local first_status = vim.api.nvim_get_var("metals_status")
    assert.are.same(msg, first_status)

    metals_status.hide = true

    handlers["metals/status"](nil, metals_status, ctx)
    local empty_status = vim.api.nvim_get_var("metals_status")
    assert.are.same("", empty_status)
  end)

  it("correctly can set the bsp status", function()
    local msg = "bsp message"
    local metals_status = {
      text = msg,
      statusType = "bsp",
    }
    local ctx = {
      client_id = "metals",
      bufnr = "2",
    }
    handlers["metals/status"](nil, metals_status, ctx)
    local first_status = vim.api.nvim_get_var("metals_bsp_status")
    assert.are.same(msg, first_status)

    metals_status.hide = true

    handlers["metals/status"](nil, metals_status, ctx)
    local empty_status = vim.api.nvim_get_var("metals_bsp_status")
    assert.are.same("", empty_status)
  end)
end)

describe("status.set_status", function()
  it("correctly scapes % characters", function()
    local msg = "50% double %%"
    local expected_msg = "50%% double %%%%"
    require("metals.status").set_status(msg)
    local status = vim.api.nvim_get_var("metals_status")
    assert.are.same(expected_msg, status)
  end)
end)
