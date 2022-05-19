format:
	stylua lua/ 

format-check:
	stylua --check lua/ tests/

lint:
	selene lua/ tests/

test-install:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory ./tests/setup/install_spec.lua { minimal = true, sequential = true }"

test-clone:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory ./tests/setup/clone_spec.lua { minimal = true, sequential = true }"

test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/tests/ { minimal = true, sequential = true }"

test-handlers:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/tests/handlers/ { minimal = true, sequential = true }"

clean:
	rm -rf mill-minimal
	rm -rf minimal-scala-cli-test
	rm -rf multiple-build-file-example
