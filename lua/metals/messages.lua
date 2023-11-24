-- Used mainly for long messages to no clog up the other files
local M = {}

M.binary_path_set_but_cant_find = [[
You have `metalsBinaryPath` set, but it seems to not exist.
Please make sure it exists and try again..]]

M.binary_path_set_so_cant_update = [[
You have `metalsBinaryPath` set , so nvim-metals can't install or update your Metals executable.
If you'd like nvim-metals to handle this for you, remove the `metalsBinaryPath` setting and try again.]]

M.coursier_not_installed = [[
It looks like you don't have Coursier installed, which you need to install Metals.

You can find instructions on how to install it here: https://get-coursier.io/docs/cli-installation]]

M.coursier_not_installed_windows = [[
Warning: Could not find cs.bat in PATH
You can find instructions on how to install it here: https://get-coursier.io/docs/cli-installation#windows
Make sure to run cs.exe once to install Coursier and add it's installation directory to your path.
See the note in the Readme.]]

-- TODO figure out a way to just prompt this and do the install
M.install_message = [[
It looks like you don't have Metals installed yet.

You can do this using `:MetalsInstall`.

If you need to set a specific version, you can set it in your settings table.]]

M.metals_not_installed = [[
You need to install Metals first before using `:MetalsInfo`.

To install, use `:MetalsInstall`]]

M.use_global_set_but_cant_find = [[
You have `useGlobalExecutable` set to true, but nvim-metals is unable to find
your executable Metals. Make sure `metals` is on your $PATH. If you want
nvim-metals to install Metals for you, remove the `useGlobalExecutable`
setting.]]

M.use_global_set_so_cant_update = [[
You have `useGlobalExecutable` set to true, so nvim-metals can't install or
update your Metals executable. If you'd like nvim-metals to handle this for
you, remove the `useGlobalExecutable` setting and try again.]]

M.setup_dap_without_nvim_dap = [[
You can not call require("metals").setup_dap() without `nvim-dap` being installed.
Please make sure `mfussenegger/nvim-dap` is installed.]]

M.no_test_suites_found = [[
No test suites could be found in current file.]]

M.no_test_cases_found = [[
No test cases found in selected suite. Fallback to run whole suite.]]

M.run_test_without_nvim_dap = [[
You can not run test without `nvim-dap` being installed.
Please make sure `mfussenegger/nvim-dap` is installed.]]

M.scala_3_tree_view = [[
You recieved a null response for the tree view.
If you're using Scala 3, this is expected as it's not support yet.
If you're using Scala 2, please create an issue for this in nvim-metals.]]

M.enable_test_explorer = [[
You can't use this command unless you have "Test Explorer" set as the value of testUserInterface in your config.
You can read more about this in :h metals-nvim-dap.]]
return M
