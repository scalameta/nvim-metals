format:
	stylua lua/ 

format-check:
	stylua --check lua/

lint:
	luacheck lua/

test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal.vim' }"

