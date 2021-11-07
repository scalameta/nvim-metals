local eq = assert.are.same

local root_dir = require("metals.rootdir")

local Path = require("plenary.path")

local multi_build_example = Path:new("multiple-build-file-example/")
local mill_minimal = Path:new("mill-minimal/")
local scala_cli = Path:new("minimal-scala-cli-test/")

if not (multi_build_example:exists()) or not (mill_minimal:exists()) or not (scala_cli:exists()) then
  describe("Should have the repos we need to test.", function()
    it("Failing since you need to run `make test-setup` first", function()
      eq(true, false)
    end)
  end)
else
  describe("The find root dir functionality", function()
    it("should correctly fall back to the cwd if no build file", function()
      eq(root_dir.find_root_dir({ "build.sbt" }, Path:new()._absolute), Path:new()._absolute)
    end)

    it("should correctly find the root in a multi-build sbt project", function()
      eq(
        root_dir.find_root_dir(
          { "build.sbt" },
          Path:new(multi_build_example, "core", "src", "main", "scala", "example", "Hello.scala").filename
        ),
        multi_build_example._absolute
      )
    end)

    it("should correctly find the root in a minimal mill build", function()
      eq(
        root_dir.find_root_dir({ "build.sc" }, Path:new(mill_minimal, "MillMinimal", "src", "example", "Hello.scala")),
        mill_minimal._absolute
      )
    end)

    -- .scala is a root pattern meaning src here should be the root, not the root
    -- of the directorty that contains the .git
    it("should correct pick up pattern instead of the .git root", function()
      eq(
        root_dir.find_root_dir({ ".scala", ".git" }, Path:new(scala_cli, "src", "Main.scala")),
        Path:new(scala_cli, "src")._absolute
      )
    end)
  end)
end
