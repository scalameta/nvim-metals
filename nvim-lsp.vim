"=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+
" These settings are a work in progress for using https://scalameta.org/metals
" with the built-in LSP support of Nvim. They assume that you have the
" following plugins installed for the listed reasons. Also ensure that you have
" Nvim nightly installed. The latest stable release does not yet have built-in
" LSP support.
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
" rename currently has issues https://github.com/neovim/neovim/pull/12185
nnoremap <silent> <leader>rn  <cmd>lua vim.lsp.buf.rename()<CR>
nnoremap <silent> <leader>bi  <cmd>lua require'metals'.build_import()<CR>
nnoremap <silent> <leader>f   <cmd>lua vim.lsp.buf.formatting()<CR>

"-----------------------------------------------------------------------------
" nvim-lsp Settings
"-----------------------------------------------------------------------------
autocmd FileType scala setlocal omnifunc=v:lua.vim.lsp.omnifunc

let g:LspDiagnosticsErrorSign = '✘'
let g:LspDiagnosticsWarningSign = '⚠'

"-----------------------------------------------------------------------------
" lua callbacks
"-----------------------------------------------------------------------------
" NOTE: this is a bit verbose, but it easily allows you to add more to it, which
" is the reason why it's done this way.
:lua << EOF
  local nvim_lsp = require'nvim_lsp'
  local M = {}

  M.on_attach = function()
      require'diagnostic'.on_attach()
      require'completion'.on_attach()
    end

  nvim_lsp.metals.setup{
    on_attach = M.on_attach,
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
let g:diagnostic_enable_virtual_text = 1
let g:diagnostic_virtual_text_prefix = ' '

" Mapping specific to complementary plugins
nnoremap <silent> [c          :NextDiagnostic<CR>
nnoremap <silent> ]c          :PrevDiagnostic<CR>
nnoremap <silent> go          :OpenDiagnostic<CR>

"-----------------------------------------------------------------------------
" Helpful general settings
"-----------------------------------------------------------------------------
" Set completeopt to have a better completion experience
set completeopt=menuone,noinsert,noselect

" Avoid showing message extra message when using completion
set shortmess+=c

" always show signcolumns
set signcolumn=yes
