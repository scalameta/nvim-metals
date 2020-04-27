if exists('g:nvim_metals_loaded')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

command! BuildImport lua require'metals'.build_import()
command! BuildConnect lua require'metals'.build_connect()
command! BuildRestart lua require'metals'.build_restart()
command! SourcesScan lua require'metals'.sources_scan()
command! CompileCascade lua require'metals'.compile_cascade()
command! Format lua vim.lsp.buf.formatting()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:nvim_metals_loaded = 1
