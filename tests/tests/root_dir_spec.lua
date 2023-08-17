local eq = assert.are.same

local root_dir = require("metals.rootdir")

local Path = require("plenary.path")

local multi_build_example = Path:new("./multiple-build-file-example/")
local mill_minimal = Path:new("./mill-minimal/")
local scala_cli = Path:new("./minimal-scala-cli-test/")

if not (multi_build_example:exists()) or not (mill_minimal:exists()) or not (scala_cli:exists()) then
  describe("Should have the repos we need to test.", function()
    it("Failing since you need to run `make local-test-setup` first", function()
      eq(true, false)
    end)
  end)
else
  describe("The find root dir functionality", function()
    it("should return nil when no pattern is detected", function()
      local result = root_dir.find_root_dir({ "build.sbt" }, Path:new("."):expand(), 1) or "was_nil"
      -- We expect nil here because nvim-metals has logic to then catch this nil and return the file that was opened.
      -- No idea why but locally using nil here works fine by in Linux CI nil here keeps thinking I'm only using
      -- one argument, so we instead replace it with "was_nil" which makes CI happy. who knows.
      eq("was_nil", result)
    end)

    it("should correctly find the root in a multi-build sbt project", function()
      local expected = multi_build_example:expand()
      eq(
        expected,
        root_dir.find_root_dir(
          { "build.sbt" },
          Path:new(multi_build_example:expand(), "core", "src", "main", "scala", "example", "Hello.scala").filename,
          1
        )
      )
    end)

    it("should correctly find the root in an odly nested multi-build sbt project", function()
      local expected = multi_build_example:expand()
      eq(
        expected,
        root_dir.find_root_dir(
          { "build.sbt" },
          Path:new(multi_build_example:expand(), "other", "nested", "src", "main", "scala", "example", "Hello.scala").filename,
          2 -- set to two here because we want to skip the other/nested/buid.sbt
        )
      )
    end)

    it("should correctly find the root in a minimal mill build", function()
      local expected = mill_minimal:expand()
      eq(
        expected,
        root_dir.find_root_dir(
          { "build.sc" },
          Path:new(mill_minimal:expand(), "MillMinimal", "src", "example", "Hello.scala").filename,
          1
        )
      )
    end)

    -- .scala is a root pattern meaning src here should be the root, not the root
    -- of the directorty that contains the .git
    it("should correct pick up pattern instead of the .git root", function()
      local expected = Path:new(scala_cli:expand(), "src").filename
      local result = root_dir.find_root_dir(
        { ".scala", ".scala-build", ".git" },
        Path:new(scala_cli:expand(), "src", "Main.scala").filename,
        1
      )
      eq(expected, result)
    end)
  end)
end
