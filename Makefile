format:
	stylua lua/ spec/

format-check:
	stylua --check lua/ spec/

lint:
	selene lua/ spec/

local-test-setup:
	git clone https://github.com/ckipp01/multiple-build-file-example.git
	git clone https://github.com/ckipp01/mill-minimal.git
	git clone https://github.com/ckipp01/minimal-scala-cli-test.git

test-setup:
	luarocks test spec/setup --local

test:
	luarocks test --local

test-handlers:
	luarocks test spec/tests/test-handlers --local

clean:
	rm -rf mill-minimal
	rm -rf minimal-scala-cli-test
	rm -rf multiple-build-file-example
