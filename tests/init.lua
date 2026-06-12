-- Minimal test bootstrap for plenary.nvim / busted
-- Usage: nvim --headless -c "luafile tests/init.lua" -c "q"

package.path = package.path .. ";./lua/?.lua"
_G._TEST = true

local ok, _ = pcall(require, "plenary.busted")
if not ok then
  vim.notify("plenary.nvim not found. Install for test support.", vim.log.levels.WARN)
end
