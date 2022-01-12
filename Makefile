format:
	stylua lua/ 

format-check:
	stylua --check lua/

lint:
	luacheck lua/

test-setup:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/setup/ { minimal_init = 'tests/minimal.vim', sequential = true }"

test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/tests/ { minimal_init = 'tests/minimal.vim' }"

test-all:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal.vim' }"

clean:
	rm -rf mill-minimal
	rm -rf minimal-scala-cli-test
	rm -rf multiple-build-file-example
