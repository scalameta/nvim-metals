local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

local eq = assert.are.same

local base_capabilities = lsp.protocol.make_client_capabilities()

-- Base asserts that are all expected to be true when starting from nothing.
local function base_asserts(valid_config)
  -- It can't find something with root patterns, so it defaults to the cwd
  eq(valid_config.root_dir, fn.getcwd())
  -- Since the path to metals will be different per machine, for this we just
  -- ensure that the cmd is actually getting set
  eq(#valid_config.cmd, 1)
  eq(valid_config.capabilities, base_capabilities)
  eq(valid_config.settings, { metals = { superMethodLensesEnabled = true } })
  eq(valid_config.filetypes, { "sbt", "scala" })
  eq(valid_config.init_options, require("metals.config").metals_init_options)
end

describe("config", function()
  local current_buf = api.nvim_get_current_buf()
  local config = require("metals.config")
  local utils = require("metals.util")
  local Path = require("plenary.path")

  before_each(function()
    package.loaded["metals.config"] = nil
    config = require("metals.config")
  end)

  it("should handle an empty table", function()
    local valid_config = config.validate_config({}, current_buf)
    base_asserts(valid_config)
  end)

  it("should handle a bare config", function()
    local bare_config = require("metals.setup").bare_config()

    local valid_config = config.validate_config(bare_config, current_buf)
    base_asserts(valid_config)
  end)

  it("should persist the config in cache", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.settings = {
      verboseCompilation = true,
    }

    local valid_config = config.validate_config(bare_config, current_buf)

    eq(valid_config.settings, { metals = { superMethodLensesEnabled = true, verboseCompilation = true } })

    local cache = config.get_config_cache()

    eq(valid_config, cache)
  end)

  it("should strip out java_opts we don't want", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.settings.serverProperties = { "-Xmx", "XsomeCoolThing" }

    local valid_config = config.validate_config(bare_config, current_buf)

    eq(#valid_config.cmd, 3)
  end)

  it("should be able to handle tvp configs", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.tvp = { panel_width = 1000 }

    local valid_config = config.validate_config(bare_config, current_buf)
    eq(valid_config.tvp.panel_width, 1000)
  end)

  it("should be able to handle a custom cmd without adding anything to it", function()
    local bare_config = require("metals.setup").bare_config()
    local cmd = { "cs", "launch", "metals" }
    bare_config.cmd = cmd

    local valid_config = config.validate_config(bare_config, current_buf)
    eq(valid_config.cmd, cmd)
  end)

  it("should be able to use metalsBinaryPath and retain valid serverProperties", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.settings.serverProperties = { "-XX", "someFakeProperty" }

    local metals_path = Path:new(utils.nvim_metals_cache_dir, "metals").filename

    bare_config.settings.metalsBinaryPath = metals_path

    local valid_config = config.validate_config(bare_config, current_buf)

    eq(valid_config.cmd, { metals_path, "-J-XX", "-JsomeFakeProperty" })
  end)

  it("should error if you try to use metalsBinaryPath and it doesn't exist", function()
    local bare_config = require("metals.setup").bare_config()
    bare_config.settings.metalsBinaryPath = "i/dont/exist"

    local valid_config = config.validate_config(bare_config, current_buf)

    eq(valid_config, nil)
  end)
end)
