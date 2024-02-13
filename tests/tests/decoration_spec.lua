describe("decorations", function()
  local decoration = require("metals.decoration")
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "val x = 3" })

  local base_decoration = {
    range = {
      start = {
        line = 0,
        character = 0,
      },
      ["end"] = {
        line = 0,
        character = 9,
      },
    },
    hoverMessage = {
      kind = "markdown",
      value = "```scala\nx: Int 1\n```",
    },
    renderOptions = {
      after = {
        contentText = " // : Int 1",
        fontStyle = "italic",
        color = "green",
      },
    },
  }

  it("should be able to correctly set decorations", function()
    local bufs_before = vim.api.nvim_list_bufs()
    decoration.set_decoration(bufnr, base_decoration)
    vim.api.nvim_win_set_cursor(0, { 1, 1 })
    decoration.hover_worksheet()
    local bufs_after = vim.api.nvim_list_bufs()
    -- We should have one more floating buf now with the contents of the virtual text
    assert.are.same(#bufs_before + 1, #bufs_after)

    local hover_contents = vim.api.nvim_buf_get_lines(bufs_after[#bufs_after], 0, 1, true)

    assert.are.same(1, #hover_contents)

    -- A bit hacky but the next iteration of Neovim changes this a bit and just to make it easy
    -- we check for both and just assert that it's one of the two. Once the new minor version of
    -- Neovim comes out we can ditch this and instead check the entire contents.
    local hover_result = hover_contents[1] == "x: Int 1" or hover_contents[1] == "```scala"
    assert.are.same(true, hover_result)
  end)

  it("should be able to clear and replace existing decorations", function()
    decoration.clear(bufnr)
    base_decoration.hoverMessage.value = "```scala\nx: Int 2\n```"
    base_decoration.renderOptions.after.contentText = " // : Int 2"
    decoration.set_decoration(bufnr, base_decoration)
    decoration.hover_worksheet()
    local bufs_after = vim.api.nvim_list_bufs()

    local hover_contents = vim.api.nvim_buf_get_lines(bufs_after[#bufs_after], 0, 1, true)

    assert.are.same(1, #hover_contents)

    -- A bit hacky but the next iteration of Neovim changes this a bit and just to make it easy
    -- we check for both and just assert that it's one of the two. Once the new minor version of
    -- Neovim comes out we can ditch this and instead check the entire contents.
    local hover_result = hover_contents[1] == "x: Int 2" or hover_contents[1] == "```scala"
    assert.are.same(true, hover_result)
  end)
end)
