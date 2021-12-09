local install = require("metals.install")
local eq = assert.are.same
local Path = require("plenary.path")
local config = require("metals.config")
local util = require("metals.util")

describe("install", function()
  local path = Path:new(util.nvim_metals_cache_dir, "metals")

  before_each(function()
    path:rm()
  end)

  it("should be able to install", function()
    -- Just initialized an empty config since when you try to install it will try
    -- to access your config.metals.settings table
    local current_buf = vim.api.nvim_get_current_buf()
    local _ = config.validate_config({}, current_buf)

    eq(path:exists(), false)
    install.install_or_update(true)
    eq(path:exists(), true)
  end)

  it("should be able to install with a snapshot", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.settings = { serverVersion = "0.10.9+131-30f6a57b-SNAPSHOT" }
    config.validate_config(bare_config, vim.api.nvim_get_current_buf())

    eq(path:exists(), false)
    install.install_or_update(true)
    eq(path:exists(), true)
  end)
end)
