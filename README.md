![nvim-metals logo](https://i.imgur.com/7gqEQOi.png)

# nvim-metals

`nvim-metals` is a Lua plugin built to provide a better experience while using
Metals, the Scala Language Server, with Neovim's built-in [LSP
support](https://neovim.io/doc/user/lsp.html).[^no-lspconfig] You can see all
the available features
[here](https://github.com/scalameta/nvim-metals/discussions/279).

<p align="center">
    <a href="https://discord.gg/FaVDrJegEh">
        <img alt="link to discord" src="https://img.shields.io/discord/632642981228314653?style=flat-square">
    </a>
    <a href="https://github.com/scalameta/nvim-metals/blob/master/doc/metals.txt">
        <img alt="link to help docs" src="https://img.shields.io/badge/docs-%3Ah%20nvim--metals-blue?style=flat-square">
    </a>
</p>

## Prerequisites

- Before you get started you need to ensure that you are using the latest nvim
v.0.10.x or newer. If you're still on v0.9.x then you'll want to target the
`v0.9.x` tag.
- Ensure [Coursier](https://get-coursier.io/docs/cli-installation) is
    installed locally.[^coursier]
- Ensure that you have all the LSP mappings for the core functionality you want
    setup.[^mappings]
- Ensure [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) is
    installed.[^plenary]
- Subscribe to [this
    discussion](https://github.com/scalameta/nvim-metals/discussions/253) which
    will notify you of any breaking changes.
- Unfamiliar with Lua and Neovim? Check out the great
    [`:h lua-guide`](https://neovim.io/doc/user/lua-guide.html#lua-guide).

## Getting started

_NOTE_: This plugin works without needing to install
[neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig). If you have
it installed for other languages, that's not a problem, but make sure you do not
have Metals configured through `nvim-lspconfig` while using this plugin.[^no-lspconfig]

## Absolute minimal example using [Lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "scalameta/nvim-metals",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  ft = { "scala", "sbt", "java" },
  opts = function()
    local metals_config = require("metals").bare_config()
    metals_config.on_attach = function(client, bufnr)
      -- your on_attach function
    end

    return metals_config
  end,
  config = function(self, metals_config)
    local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      pattern = self.ft,
      callback = function()
        require("metals").initialize_or_attach(metals_config)
      end,
      group = nvim_metals_group,
    })
  end
}
```

**NOTE**: The above assumes you have your own attach function that sets up all
your LSP mappings. It also doesn't make use of _any_ configuration. You'll
likely want a more involved setup than this, so check out the full minimal
example configuration link below.

- You can find a full [minimal example configuration
    here](https://github.com/scalameta/nvim-metals/discussions/39).
- You can find the full documentation with [`:help
    nvim-metals`](https://github.com/scalameta/nvim-metals/blob/main/doc/metals.txt).
- You can find a full [list of features here](https://github.com/scalameta/nvim-metals/discussions/279).

### Settings and Commands

To view all of the available commands, check out `:help metals-commands` in the
help docs. Similarly, to see the available configuration settings check out
`:help metals-settings`.

## Integrations

To see the full details on the available configurations, checkout out `:help
metals-integrations`. The currently available integrations are:
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [Telescope](https://github.com/nvim-telescope/telescope.nvim)


[^no-lspconfig]: If you're familiar with nvim and LSP you'll probably know of
  [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig) which also has a
  Metals configuration. Note that this is a very minimal version with no
  specific Metals commands and no Metals extensions. You can see more info on
  this [here](https://github.com/scalameta/nvim-metals/discussions/93). **DO
  NOT** try to use Metals both with `nvim-lspconfig` and with `nvim-metals` as
  stuff *will* not work right.
[^coursier]: `nvim-metals` uses Coursier to download and update Metals. _NOTE_:
  On Windows, you should run `coursier` or `cs.exe` once from the command line
  as this is how it will install itself. Once this is done you should add
  `C:\Users\YOURNAME\AppData\Coursier\data\bin` to your path. To verify that it
  is properly installed you can run `cs --help` from a new shell.
[^mappings]: By default methods for things like goto definition, find
  references, etc are there, but not automatically mapped. You can find a
  minimal example configuration
  [here](https://github.com/scalameta/nvim-metals/discussions/39).
[^plenary]: You're more than likely already relying on for other plugins.
  However, make sure to also have this installed as Metals uses it for things
  like Jobs, popups, and paths.
