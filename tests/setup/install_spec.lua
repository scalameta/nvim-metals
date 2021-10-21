local install = require("metals.install")
local eq = assert.are.same
local Path = require("plenary.path")
local util = require("metals.util")

describe("install", function()
  it("should be able to install", function()
    install.install_or_update(true)
    eq(Path:new(util.nvim_metals_cache_dir, "metals"):exists(), true)
  end)
end)
