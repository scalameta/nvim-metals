# Contributing to nvim-metals

First off, thanks for taking the time to contribute! We like to keep it positive
and friendly here in `nvim-metals`. As a wise man once said:

> You know what, it doesn't matter who was last touching it, friendship is importanter

- Anton aka @keynmol aka velvetbaldmime

So welcome friends.

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
  - [ ] [`scalacenter/scala-debug-adapter`](https://github.com/scalacenter/scala-debug-adapter) -
      If the behavior you're seeing while debugging is unexpected, for example
      an error while doing expression evaluation in the DAP REPL then this may
      be an issue with `scala-debug-adapter`, which Metals uses indirectly from
      the build servers that support DAP.
  - [ ] [`mfussenegger/nvim-dap`](https://github.com/mfussenegger/nvim-dap) -
      If you are looking for more functionality while debugging in
      `nvim-metals`, this is implemented in `nvim-dap`, so the change might need
      to be made there.

## Developing locally

  - `git clone git@github.com:scalameta/nvim-metals.git`
  - Load up the plugin to test what you're doing. There are basically two ways
      to do this:
      1.  You can directly use the plugin from your filesystem using
          [`packer`](https://github.com/wbthomason/packer.nvim) as outlined in
          the docs. This will basically just be `use '~/your-path-to/nvim-metals'`.
      2. You can also just manually add the plugin to your `runtimepath` with an
         alias. For example you could have something like `nvim --cmd 'set rtp+=/your-path-to/nvim-metals`.
  - Make sure to branch off main to send in your changes. This allows the
      maintainers to push another commit on top of your changes if they need to.

Then you should be able to just make changes and restart Neovim and see them
right away.

## Tooling

The project uses [`selene`](https://kampfkarren.github.io/selene/selene.html)
for linting , and is ran during CI. You'll need to install this locally via
cargo: `cargo install selene`. I also use
[`StyLua`](https://github.com/JohnnyMorganz/StyLua) for formatting. Please also
use this as it gets rid of any need to discuss formatting. You can install it in
various ways found on the github page, but the easiest is with cargo via `cargo
install stylua`. You can check the version that is being used by looking in the
`./.github/workflows/ci.yml` file.

After installed you can just use the commands in the Makefile to use them.

## Testing

You can find the tests that exist for `nvim-metals` in the `tests/` directory.
These are ran using the
[`plenary.test_harness`](https://github.com/nvim-lua/plenary.nvim/tree/master#plenarytest_harness).
It's useful to give the plenary page a read about this to better understand what
is happening. However, before running the tests locally make sure to run `make
local-test-setup` which will clone some repos used for testing. After this you
can use `make test`.

## Other Libraries / Integrations

`nvim-metals` utilizes
[`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim) for a few
things such as popups, jobs, and some utility methods. You can check out that
project for _some_ documentation, but you'll need to dig into the code a bit to
see what's going on. We also use this for testing.

Debugging support in `nvim-metals` is provided by
[`mfussenegger/nvim-dap`](https://github.com/mfussenegger/nvim-dap/blob/master/doc/dap.txt).
Please read the docs over there if you are every working on debugging related
stuff with as they are pretty thorough and insightful. Mathias does a great job
at making sure his stuff is stable and documented.

The metals commands are also available as a
[telescope](https://github.com/nvim-telescope/telescope.nvim) extension. The
code for this is pretty self contained and can be found in
`https://github.com/scalameta/nvim-metals/tree/main/lua/telescope/_extensions`.


## Logging

A helpful part of seeing what's going on when working on stuff is the various
logging files. Starting at the most basic, you can look in the
`.metals/metals.log` file to see basic logs given from Metals. The
`:MetalsToggleLogs` actually just looks at this file. If you want to further
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
