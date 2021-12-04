local version = require("metals.version")

local function ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

describe("version", function()
  it("should be able to retrieve the latest snapshot", function()
    local latest = version.get_latest_snapshot()

    assert.is_true(ends_with(latest, "SNAPSHOT"))
  end)
end)
