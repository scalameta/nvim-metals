local eq = assert.are.same

local root_dir = require("metals.rootdir")

local Path = require("plenary.path")
local Job = require("plenary.job")

local multi_build_example = Path:new("multiple-build-file-example/")
local mill_minimal = Path:new("mill-minimal/")

local clone = function(repo)
  Job
    :new({
      command = "git",
      args = { "clone", repo },
      on_exit = function(_, status)
        if not status == 0 then
          print("Something went wrong cloning")
        else
          print("Correctly cloned")
        end
      end,
    })
    :start()
end

if not (multi_build_example:exists()) then
  clone("https://github.com/ckipp01/multiple-build-file-example.git")
end

if not (mill_minimal:exists()) then
  clone("https://github.com/ckipp01/mill-minimal.git")
end

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
end)
