local install = require("metals.install")
local eq = assert.are.same
local Path = require("plenary.path")
local config = require("metals.config")
local util = require("metals.util")

-- Just initialized an empty config since when you try to install it will try
-- to access your config.metals.settings table
local current_buf = vim.api.nvim_get_current_buf()
local _ = config.validate_config({}, current_buf)

describe("install", function()
  it("should be able to install", function()
    install.install_or_update(true)
    eq(Path:new(util.nvim_metals_cache_dir, "metals"):exists(), true)
  end)
end)
