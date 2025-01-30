local install = require("metals.install")
local eq = assert.are.same

describe("install_version", function()
  it("should be able to know that old versions need 2.12", function()
    local server_version = "0.11.1"

    local binary_version = install._scala_version_for_install(server_version)
    eq("2.12", binary_version)
  end)

  it("should be able to know that 0.11.2 still needs 2.12", function()
    local server_version = "0.11.2"

    local binary_version = install._scala_version_for_install(server_version)
    eq("2.12", binary_version)
  end)

  it("should be able to know that 0.11.3 needs 2.13", function()
    local server_version = "0.11.3"

    local binary_version = install._scala_version_for_install(server_version)
    eq("2.13", binary_version)
  end)

  it("should be able to know that 0.11.11 needs 2.13", function()
    local server_version = "0.11.11"

    local binary_version = install._scala_version_for_install(server_version)
    eq("2.13", binary_version)
  end)

  it("should be able to know that a new snapshot needs 2.13", function()
    local server_version = "0.11.9+79-81aaecb7-SNAPSHOT	"

    local binary_version = install._scala_version_for_install(server_version)
    eq("2.13", binary_version)
  end)
end)
