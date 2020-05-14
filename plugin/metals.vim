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
command! MetalsDoctor lua require'metals'.doctor_run()
command! MetalsLogsToggle lua require'metals'.logs_toggle()

function! metals#status() abort
  return get(g:, 'metals_status', '')
endfunction

function! metals#errors() abort
  let errorCount = luaeval('vim.lsp.util.buf_diagnostics_count("Error")')
  let possibleLspSign = sign_getdefined("LspDiagnosticsErrorSign")
  let sign = get(possibleLspSign, 0, {"text": "E"})
  if (errorCount > 0)
    return sign.text . errorCount
  else
    return ''
  endif
endfunction

function! metals#warnings() abort
  let warningCount = luaeval('vim.lsp.util.buf_diagnostics_count("Warning")')
  let possibleLspSign = sign_getdefined("LspDiagnosticsWarningSign")
  let sign = get(possibleLspSign, 0, {"text": "W"})
  if (warningCount > 0)
    return sign.text . warningCount
  else
    return ''
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let g:nvim_metals_loaded = 1
