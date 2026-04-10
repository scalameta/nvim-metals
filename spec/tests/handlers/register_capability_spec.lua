local handlers = require("metals.handlers")

describe("client/registerCapability", function()
  it("strips file:// URI scheme from string glob patterns", function()
    local captured_params = nil

    -- Mock the builtin handler to capture what gets passed to it
    local original = vim.lsp.handlers["client/registerCapability"]
    vim.lsp.handlers["client/registerCapability"] = function(_, params, _ctx)
      captured_params = params
    end

    local params = {
      registrations = {
        {
          method = "workspace/didChangeWatchedFiles",
          registerOptions = {
            watchers = {
              { globPattern = "file:///Users/test/workspace/*.sbt" },
              { globPattern = "file:///Users/test/workspace/*.scala" },
            },
          },
        },
      },
    }

    handlers["client/registerCapability"](nil, params, { client_id = 0 })

    assert.are.same(
      "/Users/test/workspace/*.sbt",
      captured_params.registrations[1].registerOptions.watchers[1].globPattern
    )
    assert.are.same(
      "/Users/test/workspace/*.scala",
      captured_params.registrations[1].registerOptions.watchers[2].globPattern
    )

    vim.lsp.handlers["client/registerCapability"] = original
  end)

  it("leaves non-URI string glob patterns unchanged", function()
    local captured_params = nil

    local original = vim.lsp.handlers["client/registerCapability"]
    vim.lsp.handlers["client/registerCapability"] = function(_, params, _ctx)
      captured_params = params
    end

    local params = {
      registrations = {
        {
          method = "workspace/didChangeWatchedFiles",
          registerOptions = {
            watchers = {
              { globPattern = "**/*.sbt" },
            },
          },
        },
      },
    }

    handlers["client/registerCapability"](nil, params, { client_id = 0 })

    assert.are.same("**/*.sbt", captured_params.registrations[1].registerOptions.watchers[1].globPattern)

    vim.lsp.handlers["client/registerCapability"] = original
  end)

  it("leaves RelativePattern objects unchanged", function()
    local captured_params = nil

    local original = vim.lsp.handlers["client/registerCapability"]
    vim.lsp.handlers["client/registerCapability"] = function(_, params, _ctx)
      captured_params = params
    end

    local relative_pattern = { baseUri = "file:///Users/test/workspace", pattern = "*.sbt" }
    local params = {
      registrations = {
        {
          method = "workspace/didChangeWatchedFiles",
          registerOptions = {
            watchers = {
              { globPattern = relative_pattern },
            },
          },
        },
      },
    }

    handlers["client/registerCapability"](nil, params, { client_id = 0 })

    assert.are.same(relative_pattern, captured_params.registrations[1].registerOptions.watchers[1].globPattern)

    vim.lsp.handlers["client/registerCapability"] = original
  end)
end)
