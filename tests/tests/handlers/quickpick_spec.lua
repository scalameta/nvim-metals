local handlers = require("metals.handlers")
local stub = require("luassert.stub")

describe("metals quickpick", function()
  it("correctly puts together lables for the user to choose", function()
    stub(vim.fn, "inputlist")

    local items = {
      items = {
        {
          id = "scala-class",
          label = "Class",
        },
        {
          id = "scala-trait",
          label = "Trait",
        },
      },
      placeHolder = "Select the kind of file to create",
    }

    local labels = {
      "1 - Class",
      "2 - Trait",
    }

    handlers["metals/quickPick"](nil, items)
    assert.stub(vim.fn.inputlist).was_called_with(labels)
  end)
end)
