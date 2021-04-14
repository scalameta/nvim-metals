if exists('g:nvim_metals_loaded')
  finish
endif

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
