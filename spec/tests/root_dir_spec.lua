local eq = assert.are.same

local root_dir = require("metals.rootdir")
local path = require("metals.path")

local multi_build_example = "./multiple-build-file-example/"
local mill_minimal = "./mill-minimal/"
local scala_cli = "./minimal-scala-cli-test/"

if not path.exists(multi_build_example) or not path.exists(mill_minimal) or not path.exists(scala_cli) then
  describe("Should have the repos we need to test.", function()
    it("Failing since you need to run `make local-test-setup` first", function()
      eq(true, false)
    end)
  end)
else
  describe("The find root dir functionality", function()
    it("should return nil when no pattern is detected", function()
      local result = root_dir.find_root_dir({ "build.sbt" }, vim.fn.getcwd(), 1) or "was_nil"
      -- We expect nil here because nvim-metals has logic to then catch this nil and return the file that was opened.
      -- No idea why but locally using nil here works fine by in Linux CI nil here keeps thinking I'm only using
      -- one argument, so we instead replace it with "was_nil" which makes CI happy. who knows.
      eq("was_nil", result)
    end)

    it("should correctly find the root in a multi-build sbt project", function()
      local expected = vim.fs.normalize(multi_build_example)
      eq(
        expected,
        root_dir.find_root_dir(
          { "build.sbt" },
          path.join(vim.fs.normalize(multi_build_example), "core", "src", "main", "scala", "example", "Hello.scala"),
          1
        )
      )
    end)

    it("should correctly find the root in an odly nested multi-build sbt project", function()
      local expected = vim.fs.normalize(multi_build_example)
      eq(
        expected,
        root_dir.find_root_dir(
          { "build.sbt" },
          path.join(
            vim.fs.normalize(multi_build_example),
            "other",
            "nested",
            "src",
            "main",
            "scala",
            "example",
            "Hello.scala"
          ),
          2 -- set to two here because we want to skip the other/nested/buid.sbt
        )
      )
    end)

    it("should correctly find the root in a minimal mill build", function()
      local expected = vim.fs.normalize(mill_minimal)
      eq(
        expected,
        root_dir.find_root_dir(
          { "build.sc" },
          path.join(vim.fs.normalize(mill_minimal), "MillMinimal", "src", "example", "Hello.scala"),
          1
        )
      )
    end)

    -- .scala is a root pattern meaning src here should be the root, not the root
    -- of the directorty that contains the .git
    it("should correct pick up pattern instead of the .git root", function()
      local expected = path.join(vim.fs.normalize(scala_cli), "src")
      local result = root_dir.find_root_dir(
        { ".scala", ".scala-build", ".git" },
        path.join(vim.fs.normalize(scala_cli), "src", "Main.scala"),
        1
      )
      eq(expected, result)
    end)
  end)
end
