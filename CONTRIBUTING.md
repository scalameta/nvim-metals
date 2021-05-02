# Contributing to nvim-metals

First off, thanks for taking the time to contribute!

Keep in mind that the issue you are trying to fix or feature you are trying to
implement may actually live in another place. So before diving into something,
make sure that this is the correct place to implement it. Some places to check
off to make sure they aren't better there:

  - [ ] [Neovim core](https://github.com/neovim/neovim) - Depending on what you
      are trying to do, if it's LSP server agnostic, it's always better to try
      and get it pushed upstream. There are some cases where we ignore this and
      do something directly in `nvim-metals`, but for the most part we like to
      keep `nvim-metals` Metals-specific focused on automatic configuration,
      setup, and support for Metals-specific LSP extensions.
  - [ ] [Metals](https://github.com/scalameta/metals) - Something you may want
      may simply not exist in Metals yet, or the actual issue may not be with
      `nvim-metals`, but in Metals itself.

## Developing locally

The process of developing nvim-metals locally should be pretty pain-free.

  - `git clone git@github.com:scalameta/nvim-metals.git`
  - Load up the plugin to test what you're doing. There are basically two ways
      to do this:
      1.  You can directly use the plugin from your filesystem using
          [`packer`](https://github.com/wbthomason/packer.nvim) as outlined in
          the docs. This will basically just be `use '~/your-path-to/nvim-metals'`.
      2. You can also just manually add the plugin to your `runtimepath` with an
         alias. For example you could have something like `nvim --cmd 'set rtp+=/your-path-to/nvim-metals`.

Then you should be able to just make changes and restart Neovim and see them
right away.

## Tooling

The project uses [`lucheck`](https://github.com/mpeterv/luacheck) for static
code analysis, and this is ran during CI on your project. You'll need to install
this locally via luarocks: `luarocks install luacheck`. I also use
[`StyLua`](https://github.com/JohnnyMorganz/StyLua) for formatting. Pleas also
use this as it gets rid of any need to discuss formatting. You can install it in
various ways found on the github page, but the easiest is with cargo via `cargo
install stylua`.

After installed you can just use the commands in the Makefile to use them.

## Logging

A helpful part of seeing what's going on when working on stuff is the various
logging files. Starting at the most basic, you can look in the
`.metals/metals.log` file to see basic logs given from Metals. The
`:MetalsLogsToggle` actually just looks at this file. If you want to further
look at the communication between Metals and Neovim, you can create trace files
as outlined [here on the Metals
site](https://scalameta.org/metals/docs/contributors/getting-started.html#json-rpc-trace).

The deepest layer of logs that you can take a look at is from Neovim by setting
`vim.lsp.set_log_level("trace")`. Then you can view them in
`$XDG_CACHE_HOME/nvim/lsp.log`.

## LSP

More than likely, whatever you are looking to implement will have something to
do with LSP. It will be helpful to read through the official [Language Server
Protocol](https://microsoft.github.io/language-server-protocol/) site if you're
not familiar with the spec. It's a great resource.

Finally, don't be afraid to ask questions.
