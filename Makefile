format:
	stylua lua/ 

format-check:
	stylua --check lua/

lint:
	luacheck lua/
