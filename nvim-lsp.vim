"=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
" These settings are a work in progress for using https://scalameta.org/metals
" with the built-in LSP support of Nvim. They are also meant to serve as an
" example of what a setup can look like. They aren't necessarily meant to be
" copied verbatim, but rather referenced, improved, tweaked, etc.
" They assume that you have the following plugins installed for the listed
" reasons. Also ensure that you have Nvim nightly installed. The latest stable
" release does not yet have built-in LSP support.
"
" - https://github.com/neovim/nvim-lsp
"     (automated installation and basic setup info)
" - https://github.com/haorenW1025/completion-nvim
"     (completions much like your familiar to with other LSP clients)
" - https://github.com/haorenW1025/diagnostic-nvim
"     (a bit more sensible diagnostic than what ships by default)
"=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+

"-----------------------------------------------------------------------------
" nvim-lsp Mappings
"-----------------------------------------------------------------------------
nnoremap <silent> gd          <cmd>lua vim.lsp.buf.definition()<CR>
nnoremap <silent> K           <cmd>lua vim.lsp.buf.hover()<CR>
nnoremap <silent> gi          <cmd>lua vim.lsp.buf.implementation()<CR>
nnoremap <silent> gr          <cmd>lua vim.lsp.buf.references()<CR>
nnoremap <silent> gs          <cmd>lua vim.lsp.buf.workspace_symbol()<CR>
nnoremap <silent> <leader>rn  <cmd>lua vim.lsp.buf.rename()<CR>
nnoremap <silent> <leader>f   <cmd>lua vim.lsp.buf.formatting()<CR>

"-----------------------------------------------------------------------------
" nvim-lsp Settings
"-----------------------------------------------------------------------------
" If you just use the latest stable version, then this setting isn't necessary
let g:metals_server_version = '0.9.0+18-27d4652a-SNAPSHOT'

"-----------------------------------------------------------------------------
" lua callbacks
"-----------------------------------------------------------------------------
:lua << EOF
  local nvim_lsp = require'nvim_lsp'
  local metals = require'metals'
  local M = {}

  M.on_attach = function()
      require'diagnostic'.on_attach()
      require'completion'.on_attach()
    end

  nvim_lsp.metals.setup{
    on_attach = M.on_attach;
    root_dir = metals.root_pattern("build.sbt", "build.sc");
    init_options = {
      -- If you set this, make sure to have the `metals#status()` function
      -- in your statusline, or you won't see any status messages
      statusBarProvider = "on";
    };
    callbacks = {
      ["textDocument/hover"] = metals.hover_wrap;
      ["metals/status"] = metals.metals_status;
    };
  }
EOF

"-----------------------------------------------------------------------------
" completion-nvim settings
"-----------------------------------------------------------------------------
" Use <Tab> and <S-Tab> to navigate through popup menu
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

"-----------------------------------------------------------------------------
" diagnostic-nvim settings
"-----------------------------------------------------------------------------
" This is disabled by default. I'm still unsure if I like this on
let g:diagnostic_enable_virtual_text = 1
" Again edit this to your liking
let g:diagnostic_virtual_text_prefix = ' '

nnoremap <silent> [c          :NextDiagnostic<CR>
nnoremap <silent> ]c          :PrevDiagnostic<CR>
nnoremap <silent> go          :OpenDiagnostic<CR>

"-----------------------------------------------------------------------------
" statusline function examples
"-----------------------------------------------------------------------------
" I re-utilize the signs that you may have already set for `LspDiagnosticsErrorSign`
" and `LspDiagnosticsWarningSign`, and if not give you defaults. If you're wondering
" how to set these, look at the `call sign_define` examples down below.
function! LspErrors() abort
  let errorCount = luaeval('vim.lsp.util.buf_diagnostics_count("Error")')
  if (errorCount > 0)
    let possibleLspSign = sign_getdefined("LspDiagnosticsErrorSign")
    let sign = get(possibleLspSign, 0, {"text": "E"})
    return sign.text . errorCount
  else
    return ''
  endif
endfunction

function! LspWarnings() abort
  let warningCount = luaeval('vim.lsp.util.buf_diagnostics_count("Warning")')
  if (warningCount > 0)
    let possibleLspSign = sign_getdefined("LspDiagnosticsWarningSign")
    let sign = get(possibleLspSign, 0, {"text": "W"})
    return sign.text . warningCount
  else
    return ''
  endif
endfunction

"-----------------------------------------------------------------------------
" Helpful general settings, I recommend making sure these are set
"-----------------------------------------------------------------------------
" This is needed to enable completions
autocmd FileType scala setlocal omnifunc=v:lua.vim.lsp.omnifunc

" Needed if you want to set your own gutter signs
" NOTE: the `texthl` groups I created. You can use the defaults or create your
" own to match your statusline for example
call sign_define("LspDiagnosticsErrorSign", {"text" : "✘", "texthl" : "LspGutterError"})
call sign_define("LspDiagnosticsWarningSign", {"text" : "", "texthl" : "LspGutterWarning"})

" Set completeopt to have a better completion experience
set completeopt=menuone,noinsert,noselect

" Avoid showing message extra message when using completion
set shortmess+=c

" always show signcolumns
set signcolumn=yes
