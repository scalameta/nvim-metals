![Nvim + Metals](https://i.imgur.com/UvQ18ST.png)

# nvim-metals

This is a WIP [Metals](https://scalameta.org/metals/) plugin for Nvim users
utilizing the [Nvim built-in LSP module](https://neovim.io/doc/user/lsp.html).

Keep in mind that the level of support is rapidly changing, there are bugs, and
there are missing features. Some of this is changing daily, so expect stuff to
break without warning or change.**

If you follow the conversation
[here](https://github.com/neovim/nvim-lsp/issues/200), you'll notice a couple
things.

1. There is an automated way to install, but not uninstall or update
2. The install feature will probably go away

For now, this is still the best way to install Metals for Nvim.  If the Install
goes away, there is a decent chance I'll handle the Install / Uninstall / Update
right in the plugin.

## Available Commands

Currently, the following commands are available:

Command           |Description
------------------|-------------------------------------
`:BuildImport`    | Import the build
`:BuildConnect`   | Manually connect to the build server
`:BuildRestart`   | Restart the build server
`:SourcesScan`    | Scan all workspace sources
`:CompileCascade` | Compile current open file along with all build targets that depend on it
`:Format`         | Format current buffer

## Settings and Mappings

Some very basic things are enabled by default, like inline diagnostics, but
you'll want a basic configuration for things like finding definitions and
references. The [nvim-lsp.vim](./nvim-lsp.vim) file has these in along with some
settings for the other complementary plugins. _These are opinionated_, and
catered to my work flow. There are also a two other plugin settings under
`completion-nvim` and `diagnostic-nvim` headings. Those plugins, which are
outlined below must also be installed for those settings to work. The The idea
is to use them as a base or an example and to then build off of them or change
them to your liking. The also serve as an example of how to use `lua` in your
configuration if you're not familiar with them. They also have a few vim
configurations that I'd argue are important for you to not go insane (like
having `set signcolumn=yes`). Again, edit this to your liking. They are just in
here as an example.

```vim
nnoremap <silent> gd <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> K  <cmd>lua vim.lsp.buf.hover()<CR>
```

You can sort of assume what many of the mappings do, but you can find more info
on the available options by doing `:h lsp-config`. There is a lot of great info
in the `lsp` section of the docs, but also keep in mind that things are often
changing and some sections are just bare with `TODOs`.

The mappings I've included are a combination of what Metals supports and also
what Nvim LSP supports.

## Complementary Plugins

I've listed two external plugins in the examples that help the diagnostic and
completion experience. The Nvim LSP integration exposes a bunch of call-backs
that allow for easy customization. As far as I know the idea isn't to make an
extremely polished experience out of the box with Nvim LSP, but rather offer a
solid core that allows you to define custom callbacks for how you want to handle
these things. The idea is that this plugin will offer you all the necessary
Metals specific settings, while also allowing other plugins to offer the thing
they do best. This follows the [Unix
philosophy](https://en.wikipedia.org/wiki/Unix_philosophy) of tools doing one
thing, doing them well, and interfacing well with others.

### Completions

Taken from the docs:

> Nvim provides the _vim.lsp.omnifunc_ 'omnifunc' handler which allows
_i_CTRL-X_CTRL-O_ to consume LSP completion. Example config (note the use of
_v:lua_ to call Lua from Vimscript):

```vim
" Use LSP omni-completion in Scala files.
autocmd Filetype scala setlocal omnifunc=v:lua.vim.lsp.omnifunc
```

This will give you completion in Scala files, but you'd need to trigger them
using `i_CTRL-X_CTRL-O`, which you may not want. This is why I include the
following plugin:

- [completion-nvim](https://github.com/haorenW1025/completion-nvim)

```vim
Plug 'haorenW1025/completion-nvim'
```
This plugin will give you completion automatically in the floating window as
your typing. I have a few other settings listed which allow you to use `<Tab>`
to navigate the popup menu.

### Diagnostics

The diagnostics plugin I include mainly allows for easy settings and
customization for how your diagnostics are displayed. For example you can delay
the syntactic diagnostics that Metals provides while typing when you're in
insert mode. You can choose to display them as virtual text or not. Read through
the docs to get an idea of all the options.

- [diagnostic-nvim](https://github.com/haorenW1025/diagnostic-nvim)

```vim
Plug 'haorenW1025/diagnostic-nvim'
```

**Keep in mind that both of these plugins are under active development as well
and things are likely to change**.

### Known limitations

- Some of the default options are a bit off in nvim-lsp since we used coc.nvim
    as a base. There is a pr to fix this here: https://github.com/neovim/nvim-lsp/pull/211
- There is no `window/showMessageRequest` so you'll never get prompted to import
    your build. There is an issue for this here: https://github.com/neovim/neovim/issues/11710
- Renames aren't working correctly since Metals isn't versioning the Documents.
    You can track the Metals part of this here:
    https://github.com/scalameta/metals/issues/1668 and the Nvim side of this
    here: https://github.com/neovim/neovim/pull/12191 since they should account
    for this being `null`. Fair warning, I sent in a pr to fix this and botched
    it... so this is the second attempt.
- Multiline `textEdits` aren't being applied correctly. You can track this
    issue here: https://github.com/neovim/neovim/issues/12195

##### TODO

- [ ] Status line displaying diagnostics
- [ ] Add in more commands
