![Nvim + Metals](https://i.imgur.com/UvQ18ST.png)

# nvim-metals

This is a WIP guide for [Metals](https://scalameta.org/metals/) users to get
started with the [built-in LSP support in
Nvim](https://neovim.io/doc/user/lsp.html). Keep in mind that the level of
support is rapidly changing, there are bugs, and there are missing features.
Some of this is changing daily, and the aim of this repo is to track some of
this as it pertains to Metals users.

If you're first getting starting with Metals, consider using
[coc-metals](https://github.com/scalameta/coc-metals) if you're looking for a
more featureful and stable Metals + Vim/Nvim experience.


## Prerequisites

Before you get started you need to ensure that you have the nighly/development
build. LSP support hasn't landed in stable yet. You can find instructions for
how to do this for you OS
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
This guild also assumes that you have a few extra plugins installed. Down below
we'll go into detail about why each is required and what it offers you, but for
now, ensure that you have these installed via whatever method you use to install
plugins. Below is an example using
[vim-plug](https://github.com/junegunn/vim-plug):

```vim
call plug#begin('~/.vim/plugged')
  Plug 'neovim/nvim-lsp'
  Plug 'haorenW1025/completion-nvim'
  Plug 'haorenW1025/diagnostic-nvim'
call plug#end()
```

### Settings and Mappings

Some very basic things are enabled by default, like inline diagnostics, but
you'll want a basic configuration for things like finding definitions and
references. The [nvim-lsp.vim](./nvim-lsp.vim) file has these in along with some
settings for the other plugins. _These are opinionated_, and catered to my work
flow. The idea is to use them as a base or an example and to then build off of
them or change them to your liking. The also serve as an example of how to use
`lua` in your configuration if you're not familiar with them. They also have a
few vim configurations that I'd argue are important for you to not go insane
(like having `set signcolumn=yes`).

## Getting Started

First things first, you install Metals. For now, that's the main purpose of the
[nvim-lsp](https://github.com/neovim/nvim-lsp) plugin. It offers automated
installation of servers and basic configurations so you don't have to do it
manually.

**Fair warning, this is probably going to change.**

If you follow the conversation
[here](https://github.com/neovim/nvim-lsp/issues/200), you'll notice a couple
things.

1. There is an automated way to install, but not uninstall or update
2. The install feature will probably go away

For now, this is still the best way to install Metals for Nvim. Some of the
defaults are actually a bit off at the moment, but I'm working on fixing them,
and sending in prs to update them. So for now, you'll want to do the following
to install Metals.

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
function](https://github.com/neovim/nvim-lsp#setup-function) which will show you
how to override certain values. You can see some of the default Metals values in
the [readme](https://github.com/neovim/nvim-lsp#metals) or checkout
[nvim-lsp/lua/nvim_lsp/metals.lua](https://github.com/neovim/nvim-lsp/blob/master/lua/nvim_lsp/metals.lua).

## Customizing your mappings

As mentioned earlier, many of the common mappings that you'll want aren't set.
You'll need to add them yourself. If you look in [./nvim-lsp.vim] you'll notice
a bunch of mappings like below:

```vim
nnoremap <silent> gd          <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> K           <cmd>lua vim.lsp.buf.hover()<CR>
```

You can sort of assume what they do, but you can find more info on the available
options by doing `:h lsp-config`. There is a lot of great info in the `lsp`
section of the docs, but also keep in mind that things are often changing and
some sections are just bare with `TODOs`.

The mappings I've included are a combination of what Metals supports and also
what Nvim LSP supports.

## Plugins

I include two external plugins in the examples that help the diagnostic and
completion experience. The Nvim LSP integration exposes a bunch of call-backs
that allow for easy customization. As far as I know the idea isn't to make an
extremely polished experience out of the box with Nvim LSP, but rather offer a
solid core that allows you to define custom callbacks for how you want to handle
these things.

### Completions

Taken from the docs:

> Nvim provides the _vim.lsp.omnifunc_ 'omnifunc' handler which allows
_i_CTRL-X_CTRL-O_ to consume LSP completion. Example config (note the use of
_v:lua_ to call Lua from Vimscript):

```vim
" Use LSP omni-completion in Python files.
autocmd Filetype scala setlocal omnifunc=v:lua.vim.lsp.omnifunc
```

This will give you completion in Scala files, but you'd need to trigger them
using `i_CTRL-X_CTRL-O`, which you may not want. This is why I include the
following plugin:

- [completion-nvim](https://github.com/haorenW1025/completion-nvim)

This plugin will give you completion automatically in the floating window as
your typing. I have a few other settings listed which allow you to use `<Tab>`
to navigate the popup menu.

### Diagnostics

The diagnostics plugin I include mainly allow for easy settings and
customization for how your diagnostics are displayed. For example you can delay
the syntactic diagnostics that Metals provides while typing when you're in
insert mode. You can choose to display them as virtual text or not. Read through
the docs to get an idea of all the options.

- [diagnostic-nvim](https://github.com/haorenW1025/diagnostic-nvim)

**Keep in mind that both of these plugins are under active development and
things are likely to change**.
