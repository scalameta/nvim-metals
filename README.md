![nvim-metals logo](https://i.imgur.com/7gqEQOi.png)
# nvim-metals

nvim-metals is a Lua plugin built to provide a better experience while using
Metals, the Scala Language Server, with Neovim's built-in [LSP
support](https://neovim.io/doc/user/lsp.html). This plugin provides the
necessary commands you'll need to develop with nvim and Metals. This extension
also implements many of the custom Metals LSP extensions that will give you a
much richer experience than just using Metals with the default
[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) setup, as well as
automatically setting all of the correct `init_options`.

_NOTE:_ Keep in mind that the level of support is rapidly changing, there are
bugs, missing features, and some of this is is changing daily,
*so expect stuff to break without warning or change* until this is removed.

If you're first getting starting with Metals, consider using
[coc-metals](https://github.com/scalameta/coc-metals) if you're looking for a
more feature-full and stable Metals + Nvim experience.

## Table of Contents
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Getting Started](#getting-started)
  - [Settings and Mappings](#settings-and-mappings)
  - [Available Commands and Options](#available-commands-and-options)
  - [Metals Handlers](#metals-handlers)
  - [Statusline Integration](#statusline-integration)
  - [Importing Your Build](#importing-your-build)

## Prerequisites

- Before you get started you need to ensure that you have the nightly/development
    build of Nvim. LSP support hasn't landed in stable yet. You can find
    instructions for how to do this for your OS
    [here](https://github.com/neovim/neovim/wiki/Installing-Neovim). It's best to
    re-build often as LSP support is changing daily. The easiest way to ensure
    you're on nightly is to to do a `nvim --version`. If you see anything `v0.4.x`
    then it didn't work. You're looking for `v0.5.x`. _NOTE_: Make sure the
    version you're using includes commit #6e660d4 to ensure
    `window/showMessageRequest`s work.
- Ensure [Coursier](https://get-coursier.io/docs/cli-installation) is installed
    on your machine. nvim-metals uses Coursier to download and update Metals.
- Remove `F` from `shortmess`. `set shortmess-=F` _NOTE_: Without doing this,
    autocommands that deal with filetypes prohibit messages from being shown...
    and since we heavily rely on this, this _must_ be set.

```vim
❯ nvim --version
NVIM v0.5.0-3de9452
...
```

## Installation

_NOTE_: This plugin works without needing to install
[neovim/nvim-lspconfig](https://github.com/neovim/nvim-lspconfig). If you have
it installed for other languages, that's not a problem, but make sure you do not
have Metals configured through `nvim-lspconfig` while using this plugin. If you
have `nvim/lsp-config` registered with `nvim-lspconfig`, you'll want to remove
it.

Use whichever plugin manager you prefer to install this. Here is an example for
[vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'scalameta/nvim-metals'
```

## Getting started

nvim-metals is triggered by an auto command to start on and Scala files. The
following is the most basic setup to get started:

```vim
if has('nvim-0.5')
  augroup lsp
    au!
    au FileType scala,sbt lua require('metals').initialize_or_attach({})
  augroup end
endif
```

Once you open a Scala file, you'll be prompted to install metals. You can do
this with the following command:

```vim
:MetalsInstall
```

This will install the `latest.stable` of Metals, but if you'd like to use a
snapshot, you can set it like so:

```vim
let g:metals_server_version = '0.9.7+18-744ffa6f-SNAPSHOT'
```

_NOTE_: If you didn't see a prompt to install metals, make sure you have the
following set and try again.

```vim
set shortmess-=F
```

Keep in mind that when a new version of Metals comes out or when you change this
value, you'll need to just run `:MetalsInstall` again to update. If you want to
know what version of Metals you're using, you can use the `:MetalsInfo` command.

If you'd like a more advanced setup, the `{}` that you pass into
`initialize_or_attach()` is very similar to the config object that gets passed
to `vim.lsp.start_client()`, so you have full access to edit anything to start
the server in addition to also being able to set Metals settings. If you're not
just going to pass in `{}` require a bare config which gives you the basic table
shape you'll need. To give an example of this, below is an example setup in order
to register [completion-nvim](https://github.com/nvim-lua/completion-nvim) for
better completions, set the `statusBarProvider` to `'on'` instead of
`'show-message'`, to update the way `publishDiagnostics` work to include a
fancier prefix, and to set a few available Metals settings.

```lua
metals_config = require'metals'.bare_config
metals_config.settings = {
  showImplicitArguments = true,
  excludePackages = {
    "akka.actor.typed.javadsl",
    "com.github.swagger.akka.javadsl"
  }
}

metals_config.on_attach = function()
  require'completion'.on_attach();
end

metals_config.init_options.statusBarProvider = 'on'

metals_config.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
  vim.lsp.diagnostic.on_publish_diagnostics, {
    virtual_text = {
      prefix = '',
    }
  }
)
```

## Settings and Mappings

The nvim LSP implementation comes with a rich Lua API, but you need to set up
your mappings yourself. For example, here are some mappings to get you started,
but you should feel free to change them to your liking:

```vim
nnoremap <silent> gd          <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> K           <cmd>lua vim.lsp.buf.hover()<CR>
nnoremap <silent> gi          <cmd>lua vim.lsp.buf.implementation()<CR>
nnoremap <silent> gr          <cmd>lua require'telescope.builtin'.lsp_references{}<CR>
nnoremap <silent> <leader>s   <cmd>lua require'telescope.builtin'.lsp_workspace_symbols{}<CR> 
nnoremap <silent> gds         <cmd>lua vim.lsp.buf.document_symbol()<CR>
nnoremap <silent> gws         <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
nnoremap <silent> <leader>rn  <cmd>lua vim.lsp.buf.rename()<CR>
nnoremap <silent> <leader>f   <cmd>lua vim.lsp.buf.formatting()<CR>
nnoremap <silent> <leader>ca  <cmd>lua vim.lsp.buf.code_action()<CR>
nnoremap <silent> <leader>ws  <cmd>lua require'metals'.worksheet_hover()<CR>
nnoremap <silent> <leader>a   <cmd>lua require'metals'.open_all_diagnostics()<CR>
```

You can also map any of the functions from the nvim-metals api as well. You can
see all the options in `:h metals-lua-api`. Here is an example of mapping the
`build-import` command:

```vim
nnoremap <silent> <leader>bi  <cmd>lua require'metals'.build_import()<CR>
```

Or in Lua

```lua
vim.api.nvim_set_key('n', '<leader>bi', '<cmd>lua require'metals'.build_import()<CR>', {noremap = true})
```

This would allow you to do `<leader>bi` to trigger an import, the same way
`:MetalsBuildImport` does.

_NOTE_: You can find a full example of a configuration
[here](https://github.com/scalameta/nvim-metals/discussions/39).

## Available Commands and Options

To view all of the available commands, check out `:h metals-commands` in the
help docs. Similarly, to see the available configuration options, check out `:h
metals-options`, and for settings, `:h metals-settings`.

## Metals Handlers

The nvim LSP integration relies on a series of handlers to handle various LSP
methods. This is also the way custom LSP extensions can be handled. Metals
implements a fair amount of these, and you can see all of the custom handlers
that nvim-metals adds by viewing them in the help docs: `:h
metals-custom-handlers`.

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
