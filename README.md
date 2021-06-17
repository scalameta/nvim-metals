![nvim-metals logo](https://i.imgur.com/7gqEQOi.png)

# nvim-metals

nvim-metals is a Lua plugin built to provide a better experience while using
Metals, the Scala Language Server, with Neovim's built-in [LSP
support](https://neovim.io/doc/user/lsp.html). This plugin provides the
necessary commands you'll need to develop with nvim and Metals. This extension
also implements many of the custom Metals LSP extensions that will give you a
much richer experience than just using Metals with the default
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) setup, as well as
automatically setting all of the correct `init_options`, and offering some
integrations with other projects such as
[nvim-dap](https://github.com/mfussenegger/nvim-dap).

<p align="center">
    <a href="https://gitter.im/scalameta/metals-vim">
        <img alt="link to gitter" src="https://img.shields.io/gitter/room/scalameta/metals-vim?style=flat-square">
    </a>
    <a href="https://github.com/scalameta/nvim-metals/blob/master/doc/metals.txt">
        <img alt="link to help docs" src="https://img.shields.io/badge/docs-%3Ah%20nvim--metals-blue?style=flat-square">
    </a>
</p>

## Prerequisites

- Before you get started you need to ensure that you have the nightly/development
    build of Neovim. LSP support hasn't landed in stable yet. You can find
    instructions for how to do this for your OS
    [here](https://github.com/neovim/neovim/wiki/Installing-Neovim). It's best to
    re-build often as LSP support is changing daily. The easiest way to ensure
    you're on nightly is to to do a `nvim --version`. If you see anything `v0.4.x`
    then it didn't work. You're looking for `v0.5.x`. _NOTE_: If you hit on something
    that doesn't work, ensure you're on the latest nvim nightly version as there
    is no compatibility guarantees until 0.5.0 releases.
- Ensure [Coursier](https://get-coursier.io/docs/cli-installation) is installed
    on your machine. `nvim-metals` uses Coursier to download and update Metals.
- Remove `F` from `shortmess`. `set shortmess-=F` _NOTE_: Without doing this,
    autocommands that deal with filetypes prohibit messages from being shown...
    and since we heavily rely on this, this _must_ be set.
- Ensure that you have mappings created for functionality that you desire. By
    default methods for things like goto definition, find references, etc are
    there, but not automatically mapped. You can find both minimal mixed
    Vimscript/Lua and pure Lua example configurations for `nvim-metals`
    [here](https://github.com/scalameta/nvim-metals/discussions/39).

## Installation

_NOTE_: This plugin works without needing to install
[neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig). If you have
it installed for other languages, that's not a problem, but make sure you do not
have Metals configured through `nvim-lspconfig` while using this plugin. If you
have `nvim/lsp-config` registered with `nvim-lspconfig`, you'll want to remove
it.

`nvim-metals` is just a plugin installed like any other Neovim plugin. For
example if using [`packer`](https://github.com/wbthomason/packer.nvim):

```lua
use({'scalameta/nvim-metals'})
```

## Getting started

To get started with `nvim-metals`, _please read_ [`:help
nvim-metals`](https://github.com/scalameta/nvim-metals/blob/master/doc/metals.txt).
This will give you a thorough overview of the setup and settings.

## Settings, Commands, and Options

To view all of the available commands, check out `:help metals-commands` in the
help docs. Similarly, to see the available configuration options, check out
`:help metals-options`, and `:help metals-settings` for settings.

_NOTE_: You can find an example of a minimal configuration showing how to set
various settings and options
[here](https://github.com/scalameta/nvim-metals/discussions/39).

## Integrations

To see the full details on the available configurations, checkout out `:help
metals-integrations`. The currently available integrations are:
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)
- [Telescope](https://github.com/nvim-telescope/telescope.nvim)
