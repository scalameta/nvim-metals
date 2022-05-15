format:
	stylua lua/ 

format-check:
	stylua --check lua/ tests/

lint:
	selene lua/ tests/

test-setup:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/setup/ { minimal_init = 'tests/minimal.vim', sequential = true }"

test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/tests/ { minimal_init = 'tests/minimal.vim', sequential = true }"

test-handlers:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/tests/handlers/ { minimal_init = 'tests/minimal.vim'}"

clean:
	rm -rf mill-minimal
	rm -rf minimal-scala-cli-test
	rm -rf multiple-build-file-example
