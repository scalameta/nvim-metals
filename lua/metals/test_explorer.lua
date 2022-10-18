local log = require("metals.log")
local messages = require("metals.messages")

local M = {}
local state = {}

local TestSuite = {
  fullyQualifiedClassName = "",
  className = "",
  symbol = "",
  canResolveChildren = false,
  location = {
    range = {
      start = { line = 0, character = 0 },
      ["end"] = { line = 0, character = 0 },
    },
    uri = "",
  },
  targetName = "",
  testCases = nil,
}

function TestSuite:new(suite, targetName)
  suite = suite or {}
  suite.targetName = targetName
  setmetatable(suite, self)
  self.__index = self
  return suite
end

function TestSuite:add_test_cases(testCases)
  self.testCases = testCases
end

local function handle_remove_suite(targetName, event)
  state[targetName][event.fullyQualifiedClassName] = nil
end

local function handle_add_suite(targetName, event)
  state[targetName][event.fullyQualifiedClassName] = TestSuite:new(event, targetName)
end

local function handle_update_suite_location(targetName, event)
  state[targetName][event.fullyQualifiedClassName].location = event.location
end

local function handle_add_test_cases(targetName, event)
  state[targetName][event.fullyQualifiedClassName]:add_test_cases(event.testCases)
end

local function handle(targetName, event)
  if event.kind == "removeSuite" then
    handle_remove_suite(targetName, event)
  elseif event.kind == "addSuite" then
    handle_add_suite(targetName, event)
  elseif event.kind == "updateSuiteLocation" then
    handle_update_suite_location(targetName, event)
  elseif event.kind == "addTestCases" then
    handle_add_test_cases(targetName, event)
  else
    log.error("Unknown event in test explorer", targetName, event)
  end
end

local function get_test_suites(test_suite_uri)
  local test_suites = {}
  for _, buildTargetState in pairs(state) do
    for _, test_suite in pairs(buildTargetState) do
      if test_suite_uri == nil or test_suite.location.uri == test_suite_uri then
        table.insert(test_suites, test_suite)
      end
    end
  end
  return test_suites
end

local function get_test_cases(test_suite)
  if test_suite.testCases == nil then
    return {}
  end
  local test_cases = {}
  for _, test_case in pairs(test_suite.testCases) do
    table.insert(test_cases, test_case)
  end
  return test_cases
end

local function dap_run_test(root, test_suite, test_case)
  local dap_ok, dap = pcall(require, "dap")
  if not dap_ok then
    return log.error_and_show(messages.run_test_without_nvim_dap)
  end
  local tests_to_run = {}
  if test_case ~= nil then
    tests_to_run = { test_case.name }
  end
  local arguments = {
    type = "scala",
    request = "launch",
    name = "Run Test",
    -- ScalaTestSuitesDebugRequest
    metals = {
      target = { uri = "file:" .. root .. "/?id=" .. test_suite.targetName },
      requestData = {
        suites = {
          {
            className = test_suite.fullyQualifiedClassName,
            tests = tests_to_run,
          },
        },
        jvmOptions = {},
        environmentVariables = {},
      },
    },
  }
  dap.run(arguments)
end

M.dap_select_test_suite = function(root)
  local test_suites = get_test_suites(nil)
  if #test_suites == 0 then
    return log.warn_and_show(messages.no_test_suites_found)
  end
  local test_suite_runner = function(selected_suite)
    dap_run_test(root, selected_suite, nil)
  end
  vim.ui.select(test_suites, {
    prompt = "Select test suite:",
    format_item = function(item)
      return item.fullyQualifiedClassName
    end,
  }, test_suite_runner)
end

M.dap_select_test_case = function(root)
  local test_suites = get_test_suites(vim.uri_from_bufnr(0))
  if #test_suites == 0 then
    return log.warn_and_show(messages.no_test_suites_found)
  end
  local test_case_selector = function(selected_suite)
    local test_cases = get_test_cases(selected_suite)
    local test_case_runner = function(selected_case)
      dap_run_test(root, selected_suite, selected_case)
    end
    if #test_cases == 0 then
      log.warn_and_show(messages.no_test_cases_found)
      return test_case_runner(nil)
    end
    vim.ui.select(test_cases, {
      prompt = "Select test case:",
      format_item = function(item)
        return item.name
      end,
    }, test_case_runner)
  end

  vim.ui.select(test_suites, {
    prompt = "Select test suite:",
    format_item = function(item)
      return item.fullyQualifiedClassName
    end,
  }, test_case_selector)
end

M.update_state = function(buildTargetUpdates)
  for _, buildTagetUpdate in ipairs(buildTargetUpdates) do
    if state[buildTagetUpdate.targetName] == nil then
      state[buildTagetUpdate.targetName] = {}
    end
    for _, event in ipairs(buildTagetUpdate.events) do
      handle(buildTagetUpdate.targetName, event)
    end
  end
end

M.state = state

return M
