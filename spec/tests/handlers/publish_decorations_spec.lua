local handlers = require("metals.handlers")

describe("metals/publishDecorations", function()
  it("correctly can publish decorations", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, "test.worksheet.sc")
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "val x = 3" })
    local decoration = {
      uri = "file://test.worksheet.sc",
      options = {
        {
          range = {
            start = {
              line = 0,
              character = 0,
            },
            ["end"] = {
              line = 0,
              character = 9,
            },
          },
          hoverMessage = {
            kind = "markdown",
            value = "```scala\nx: Int  1\n```",
          },
          renderOptions = {
            after = {
              contentText = " // : Int 1",
              fontStyle = "italic",
              color = "green",
            },
          },
        },
      },
    }

    -- The only thing we're really testing here is the handler, so we want to
    -- ensure that it can receive a decoration and not blow up.
    handlers["metals/publishDecorations"](nil, decoration)
  end)
end)
