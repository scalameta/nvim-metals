rockspec_format = '3.0'
package = 'nvim-metals'
version = 'scm-1'

test_dependencies = {
  'lua >= 5.1',
  'nlua',
  'nui.nvim',
  'plenary.nvim'
}

source = {
  url = 'git://github.com/scalameta/' .. package,
}

build = {
  type = 'builtin',
}
