local install = require("metals.install")
local eq = assert.are.same
local path = require("metals.path")
local config = require("metals.config")
local util = require("metals.util")

describe("install", function()
  local metals_path = path.join(util.nvim_metals_cache_dir, "metals")

  before_each(function()
    vim.fn.delete(metals_path)
  end)

  it("should be able to install latest.stable", function()
    -- Just initialized an empty config since when you try to install it will try
    -- to access your config.metals.settings table
    local current_buf = vim.api.nvim_get_current_buf()
    local _ = config.validate_config({}, current_buf)

    eq(path.exists(metals_path), false)
    install.install_or_update(true)
    eq(path.exists(metals_path), true)
  end)

  it("should be able to install with an old 2.12", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.settings = { serverVersion = "0.11.0" }
    config.validate_config(bare_config, vim.api.nvim_get_current_buf())

    eq(path.exists(metals_path), false)
    install.install_or_update(true)
    eq(path.exists(metals_path), true)
  end)

  it("should be able to install with a new 2.13 snapshot", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.settings = { serverVersion = "1.6.4+48-e2f699ed-SNAPSHOT" }
    config.validate_config(bare_config, vim.api.nvim_get_current_buf())

    eq(path.exists(metals_path), false)
    install.install_or_update(true)
    eq(path.exists(metals_path), true)
  end)

  it("should block you from using latest.snapshot with a imposter metals", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.settings = { serverVersion = "latest.snapshot", serverOrg = "some-other-org" }
    config.validate_config(bare_config, vim.api.nvim_get_current_buf())

    eq(path.exists(metals_path), false)
    install.install_or_update(true)
    eq(path.exists(metals_path), false)
  end)

  it("should be able to install with latest.snapshot", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.settings = { serverVersion = "latest.snapshot" }
    config.validate_config(bare_config, vim.api.nvim_get_current_buf())

    eq(path.exists(metals_path), false)
    -- This takes a bit longer here so we just pause for a couple seconds to
    -- ensure both jobs runs.
    vim.wait(2000, install.install_or_update(true))
    eq(path.exists(metals_path), true)
  end)
end)
