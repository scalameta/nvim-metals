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
end)
