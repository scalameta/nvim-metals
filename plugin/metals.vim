if exists('g:nvim_metals_loaded')
  finish
endif

command! Format lua vim.lsp.buf.formatting()

command! MetalsAmmoniteEnd lua require'metals'.ammonite_end()
command! MetalsAmmoniteStart lua require'metals'.ammonite_start()
command! MetalsBspSwitch lua require'metals'.bsp_switch()
command! MetalsBuildConnect lua require'metals'.build_connect()
command! MetalsBuildDisconnect lua require'metals'.build_disconnect()
command! MetalsBuildImport lua require'metals'.build_import()
command! MetalsBuildRestart lua require'metals'.build_restart()
command! MetalsCompileCancel lua require'metals'.compile_cancel()
command! MetalsCompileCascade lua require'metals'.compile_cascade()
command! MetalsCompileClean lua require'metals'.compile_clean()
command! MetalsDoctor lua require'metals'.doctor_run()
command! MetalsGenerateBspConfig lua require'metals'.generate_bsp_config()
command! MetalsInfo lua require'metals'.info()
command! MetalsInstall lua require'metals'.install_or_update()
command! MetalsLogsToggle lua require'metals'.logs_toggle()
command! MetalsNewScalaFile lua require'metals'.new_scala_file()
command! MetalsSourcesScan lua require'metals'.sources_scan()

function! metals#status() abort
  return get(g:, 'metals_status', '')
endfunction

function! metals#errors() abort
  let errorCount = luaeval("vim.lsp.diagnostic.get_count(vim.fn.bufnr('%'), [[Error]])")
  let possibleLspSign = sign_getdefined("LspDiagnosticsErrorSign")
  let sign = get(possibleLspSign, 0, {"text": "E"})
  if (errorCount > 0)
    return sign.text . errorCount
  else
    return ''
  endif
endfunction

function! metals#warnings() abort
  let warningCount = luaeval("vim.lsp.diagnostic.get_count(vim.fn.bufnr('%'), [[Warning]])")
  let possibleLspSign = sign_getdefined("LspDiagnosticsWarningSign")
  let sign = get(possibleLspSign, 0, {"text": "W"})
  if (warningCount > 0)
    return sign.text . warningCount
  else
    return ''
  endif
endfunction

let g:nvim_metals_loaded = 1
