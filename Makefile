format:
	stylua lua/ tests/

format-check:
	stylua --check lua/ tests/

lint:
	selene lua/ tests/

local-test-setup:
	git clone https://github.com/ckipp01/multiple-build-file-example.git
	git clone https://github.com/ckipp01/mill-minimal.git
	git clone https://github.com/ckipp01/minimal-scala-cli-test.git

test-setup:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/setup/ { minimal = true, sequential = true }"

test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/tests/ { minimal = true, sequential = true }"

test-handlers:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/tests/handlers/ { minimal = true, sequential = true }"

clean:
	rm -rf mill-minimal
	rm -rf minimal-scala-cli-test
	rm -rf multiple-build-file-example
