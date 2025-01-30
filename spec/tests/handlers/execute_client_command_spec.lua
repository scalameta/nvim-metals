local handlers = require("metals.handlers")

describe("metals/executeClientCommand", function()
  it("handles metals-diagnostics-focus", function()
    local bufs_before = vim.api.nvim_list_bufs()
    local buf = bufs_before[1]
    local namespace = vim.api.nvim_create_namespace("metals")
    vim.diagnostic.set(namespace, buf, { { lnum = 1, col = 1, message = "hoi" } }, {})

    handlers["metals/executeClientCommand"](nil, { command = "metals-diagnostics-focus" })

    local bufs_after = vim.api.nvim_list_bufs()
    -- Another buffer should be open after the call since we opened the diagnostic window
    assert.are.same(#bufs_before + 1, #bufs_after)
  end)

  it("handles metals-goto-location", function()
    local name = "/fake-file.scala"
    local uri = "file://" .. name
    local location = {
      uri = uri,
      range = {
        start = {
          line = 0,
          character = 0,
        },
        ["end"] = {
          line = 0,
          character = 0,
        },
      },
    }

    handlers["metals/executeClientCommand"](nil, { command = "metals-goto-location", arguments = { location } })
    local buf_name = vim.api.nvim_buf_get_name(0)
    assert.are.same(name, buf_name)
  end)

  it("handles metals-doctor-run and metals-doctor-reload", function()
    local doctor_json =
      '{"title":"Metals Doctor","header":{"buildServer":"Build server currently being used is Bloop v1.5.0.","serverInfo":"Metals Server version: 0.11.5+71-3c4c3316-SNAPSHOT","buildTargetDescription":"These are the installed build targets for this workspace. One build target corresponds to one classpath. For example, normally one sbt project maps to two build targets: main and test.","jdkInfo":"Metals Java: 11.0.14 from GraalVM Community located at /Users/ckipp/.sdkman/candidates/java/22.0.0.2.r11-grl"},"version":3,"targets":[{"buildTarget":"Sanity","gotoCommand":"metalsDecode:file%3A%2F%2F%2Fsanity%2FSanity.metals-buildtarget","compilationStatus":"✅ ","targetType":"Scala 2.12.13","diagnostics":"✅ ","interactive":"✅ ","semanticdb":"✅ ","debugging":"✅ ","java":"✅ ","recommendation":""},{"buildTarget":"Sanity.test","gotoCommand":"metalsDecode:file%3A%2F%2F%2Fsanity%2FSanity.test.metals-buildtarget","compilationStatus":"✅","targetType":"Scala 2.12.13","diagnostics":"✅ ","interactive":"✅ ","semanticdb":"✅ ","debugging":">✅ ","java":"✅ ","recommendation":""}],"explanations":[{"title":"Compilation status:","explanations":["✅  - code is compiling"]},{"title":"Diagnostics:","explanations":["✅  - diagnostics correctly being reported by the build server"]},{"title":"Interactive features (completions, hover):","explanations":["✅ - supported Scala version"]},{"title":"Semanticdb features (references, renames, go to implementation):","explanations":["✅  - build tool automatically creating needed semanticdb files"]},{"title":"Debugging (run/test, breakpoints, evaluation):","explanations":["✅  - users can run or test their code with debugging capabilities"]},{"title":"Java Support:","explanations":["✅  - working non-interactive features(references, rename etc.)"]}]}'

    local before_window = vim.api.nvim_get_current_win()
    handlers["metals/executeClientCommand"](nil, { command = "metals-doctor-run", arguments = { doctor_json } })
    local first_doctor_win = vim.api.nvim_get_current_win()

    -- Ensure that the doctor window is opened and is the current one
    assert.are.not_same(before_window, first_doctor_win)

    handlers["metals/executeClientCommand"](nil, { command = "metals-doctor-reload", arguments = { doctor_json } })

    local second_doctor_win = vim.api.nvim_get_current_win()

    -- Ensure the old doctor window is gone and no longer valid
    assert.are.same(false, vim.api.nvim_win_is_valid(first_doctor_win))
    -- Ensure we're not back to the original window but in the new one
    assert.are.not_same(before_window, second_doctor_win)
  end)

  it("handles metals-model-refresh", function()
    -- The only thing we are testing here is that we can actaully handle the
    -- case where nvim-metals gets a metals-model-refresh and calls a
    -- codelense.refresh. If something about the codelense api changes this
    -- should blow up warning us
    handlers["metals/executeClientCommand"](nil, { command = "metals-model-refresh" })
  end)
end)
