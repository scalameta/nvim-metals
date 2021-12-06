-- Used mainly for long messages to no clog up the other files
local M = {}

M.coursier_not_installed = [[
It looks like you don't have Coursier installed, which you need to install Metals.

You can find instructions on how to install it here: https://get-coursier.io/docs/cli-installation]]

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

M.server_version_setting_deprecated = [[
Setting the server version via vim.g.metals_server_version is deprecated,
please use config settings instead.]]

M.cant_use_snapshot_setting_with_custom_org = [[
Cannont use the SNAPSHOT feature with another server org.

You need to set an explicit version or remove the setting.]]

M.disabled_mode_global_deprecated = [[
Using g:metals_disabled_mode is deprecated.

Please use disabledMode in the metals settings config instead.

https://github.com/scalameta/nvim-metals/discussions/253#discussioncomment-1749475
]]

return M
