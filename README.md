![Nvim + Metals](https://i.imgur.com/UvQ18ST.png)

# nvim-metals

This is a WIP [Metals](https://scalameta.org/metals/) plugin and guide for Nvim
users wanting to utilize the [Nvim built-in LSP
module](https://neovim.io/doc/user/lsp.html). The goal of this plugin is to
provide the extra functionality that you need for Metals and the rest will serve
as a guide and example.

_NOTE:_ Keep in mind that the level of support is rapidly changing, there are bugs, and
there are a lot of missing features. Some of this is changing daily, *so expect
stuff to break without warning or change*.

If you're first getting starting with Metals, consider using
[coc-metals](https://github.com/scalameta/coc-metals) if you're looking for a
more feature-full and stable Metals + Nvim experience.

If you're a `coc-metals` user and want to try this but are worried about
`coc.nvim` and the built-in LSP conflicting in any way, take a look at how I
handle this [in the
wiki](https://github.com/scalameta/nvim-metals/wiki/Try-nvim-metals-without-conflicting-with-coc-metals)

## Table of Contents
  - [Prerequisites](#prerequisites)
      - [Plugins](#plugins)
  - [Getting Started](#getting-started)
  - [Settings and Mappings](#settings-and-mappings)
  - [Available Commands](#available-commands)
  - [Custom Functions](#custom-functions)
  - [Custom Callbacks](#custom-callbacks)
  - [Statusline Integration](#statusline-integration)
  - [Importing Your Build](#importing-your-build)
  - [Troubleshooting](#troubleshooting)

## Prerequisites

Before you get started you need to ensure that you have the nightly/development
build of Nvim. LSP support hasn't landed in stable yet. You can find
instructions for how to do this for you OS
[here](https://github.com/neovim/neovim/wiki/Installing-Neovim). It's best to
re-build often as LSP support is changing daily. The easiest way to ensure
you're on nightly is to to do a `nvim --version`. If you see anything `v0.4.x`
then it didn't work. You're looking for `v0.5.x`:

```vim
❯ nvim --version
NVIM v0.5.0-3de9452
...
```

### Plugins

Apart from this plugin, you'll also want to have the
[neovim/nvim-lsp](https://github.com/neovim/nvim-lsp) plugin installed. For now,
this plugin offers automated installation and some default configurations for
Metals.

Use whichever plugin manager to install both.
[vim-plug](https://github.com/junegunn/vim-plug) is probably the most common, so
I'll use that as an example:

```vim
call plug#begin('~/.vim/plugged')
  " Necessary plugins
  Plug 'neovim/nvim-lsp'
  Plug 'scalameta/nvim-metals'
call plug#end()
```

_NOTE_: Some of the default LSP functionality is a bit rough around the edges,
so take a look at some of the complimentary plugins out there. I have some
listed in the [Example
Configuration](https://github.com/scalameta/nvim-metals/wiki/Example-Configuration)
in the wiki.

## Getting started

First things first, you need to install Metals. This functionality is provided
by the [nvim-lsp](https://github.com/neovim/nvim-lsp) plugin. It offers
automated installation of servers and basic configurations so you don't have to
do it manually.

If you'd like to use a Snapshot version of metals, you can set it like below
before you do the `LspInstall`. If you've already installed, you need to remove
the installation, set this, and then install again. Hopefully this process will
be smoother in the future.

```vim
let g:metals_server_version = '0.9.4+18-744ffa6f-SNAPSHOT'
```

```vim
:LspInstall metals
```

There isn't a lot of feedback on whether or not this worked, so after you do
this, issue the following command to ensure that it's installed. This will also
show you the directory that it's installed in.

```vim
:LspInstallInfo
```

If it's installed, you should see something like the following:

```vim
{
  metals = {
    cmd = { "/Users/ckipp/.cache/nvim/nvim_lsp/metals/metals" },
    install_dir = "/Users/ckipp/.cache/nvim/nvim_lsp/metals",
    is_installed = "file"
  }
}
```

Make sure to take a look at the [`setup()`
function](https://github.com/neovim/nvim-lspconfig#setup-function) which will
show you how to override certain values or add extra settings. You can see all
of the default Metals values in the
[readme](https://github.com/neovim/nvim-lsp#metals) or checkout
[nvim-lsp/lua/nvim_lsp/metals.lua](https://github.com/neovim/nvim-lspconfig/blob/master/lua/nvim_lsp/metals.lua).

Once installed, you'll need to set up mappings for all of the common LSP
functionality. I have an example of what this looks like along with some
examples of how to use complementary plugins in the [wiki under
Example-Configuration](https://github.com/scalameta/nvim-metals/wiki/Example-Configuration).

If you'd want no other functionality than to use all the defaults you'd just
have the following:

```lua
require'nvim_lsp'.metals.setup{}
```

However, this won't leave you with the best experience so it's recommended to
look through the example configuration and the possible additional plugins.

**Fair warning, the installation is probably all going to change.**
In you following the conversation
[here](https://github.com/neovim/nvim-lspconfig/issues/200), you'll notice a couple
things.

1. There is an automated way to install, but not uninstall or update
2. The install feature will probably go away

For now, this is still the best way to install Metals for Nvim.  If the Install
goes away, there is a decent chance I'll handle the Install / Uninstall / Update
right in this plugin.

## Settings and Mappings

In addition to the mappings in the wiki, you can also create custom mappings to
utilize some of the commands that this plugin offers. For example, let's say we
wanted to add a custom mapping for `BuildImport`, you could by doing the
following:

```vim
nnoremap <silent> <leader>bi  <cmd>lua require'metals'.build_import()<CR>
```

This would allow you to do `<leader>bi` to trigger an import, the same way
`:BuildImport` does.

## Available Commands

To view all of the available commands, check out `:h metals-commands`.

## Custom Functions

Custom functions are similar to Custom Callbacks in that you use them to
override a default setup option for Metals.

Currently if you use a build definition structure with multiple nested build
files, the Nvim LSP client will re-initialize when you go into a module with
another build file. In order to prevent this, use the `metals.root_pattern()`
function to override the `root_dir` function like below:

```lua
local metals = require'metals'
nvim_lsp.metals.setup{
  root_dir = metals.root_pattern("build.sbt", "build.sc", ".git");
}
```

This `root_pattern()` function is almost identical to the one that is in
`nvim-lsp`, but it adds in the ability to check to ensure that there isn't
another build file in the parent directory.

_NOTE:_ If you are only using nvim-metals
with projects that only ever have one build file, then there is no need to set
this.

## Custom Callbacks

The Nvim LSP module heavily relies on callback for each type of message that it
receives from the server. These can all be overridden and customized. You can
either override them globally, or just for Metals. An example of global override
using one of the custom callbacks nvim-metals provides would look like this:

```lua
local metals = require'metals'
lsp.callbacks['textDocument/hover'] = metals['textDocument/hover']
```

Example usage for only Metals:
```lua
local metals = require'metals'
nvim_lsp.metals.setup{
  callbacks = {
    ['textDocument/hover'] = metals['textDocument/hover']
  }
}
```

To view all of the custom callbacks, check out `:h metals-custom-callbacks`.
Currently, nvim-metals has the following callbacks that you can use:

## Statusline integration

nvim-metals provides a few functions that can be used in your statusline in
order to show Errors, Warnings, and Metals status. For diagnostics you can use
them like below:

```vim
...
set statusline+=%{metals#errors()}
set statusline+=%{metals#warnings()}
...
```

![Statusline](https://i.imgur.com/y4hij0S.png)

The colors are using a custom highlighting group that you'd need to define or
assign yourself.

You can also enable
[`metals/status`](https://scalameta.org/metals/docs/editors/new-editor.html#metalsstatus)
which will allow for you to use the `metals#status()` function in your
statusline to show the status messages coming from Metals. This can be used like
the below example or added into an existing statusline integration:

```vim
...
set statusline+=%{metals#status()}
...
```

## Importing your build

**You need to do this before any Metals functionality will work**

Since `window/showMessageRequest` is not yet supported in the Nvim LSP module,
you need to trigger this manually. As you would normally, open your project and
then issue a `:BuildImport` command which will send the request to Metals to
import your build.

## Troubleshooting

Before submitting an issue, check out the
[Troubleshooting](https://github.com/scalameta/nvim-metals/wiki/Troubleshooting)
and [known
limitations](https://github.com/scalameta/nvim-metals/wiki/Known-limitations)
section of the wiki.
