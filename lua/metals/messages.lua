local M = {}

M.coursier_not_installed = [[
It looks like you don't have coursier isntalled, which you need to install Metals.

You can find instructions on how to install it here: https://get-coursier.io/docs/cli-installation
]]

-- TODO figure out a way to just prompt this and do the install
M.install_message = [[
It looks like you don't have Metals installed yet.

You can do this using `:MetalsInstall`.

If you need to set a specific version, you can use `g:metals_server_version`.
]]

return M
