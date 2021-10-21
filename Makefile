format:
	stylua lua/ 

format-check:
	stylua --check lua/

lint:
	luacheck lua/

test-setup:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/setup/ { minimal_init = 'tests/minimal.vim' }"

test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/tests/ { minimal_init = 'tests/minimal.vim' }"

test-all:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal.vim' }"


