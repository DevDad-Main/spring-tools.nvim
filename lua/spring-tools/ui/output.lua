local components = require("spring-tools.ui.components")

local M = {}

M.buf = nil
M.win = nil
M.ns = vim.api.nvim_create_namespace("spring_tools_output")
M.title = "Output"

local function buf_is_valid()
  return M.buf and vim.api.nvim_buf_is_valid(M.buf)
end

local function win_is_valid()
  return M.win and vim.api.nvim_win_is_valid(M.win)
end

function M.open()
  if win_is_valid() then return end

  local main_win = nil
  local min_col = math.huge
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local ok, fixwidth = pcall(function() return vim.wo[w].winfixwidth end)
    if ok and fixwidth then goto continue end
    local _, col = unpack(vim.api.nvim_win_get_position(w))
    if col < min_col then min_col = col; main_win = w end
    ::continue::
  end
  if not main_win then
    local max_col = -1
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local _, col = unpack(vim.api.nvim_win_get_position(w))
      if col > max_col then max_col = col; main_win = w end
    end
  end

  if main_win then
    vim.api.nvim_set_current_win(main_win)
  end

  vim.cmd("belowright split")
  M.win = vim.api.nvim_get_current_win()
  local height = math.max(12, math.floor(vim.o.lines * 0.3))
  vim.api.nvim_win_set_height(M.win, height)
  vim.wo[M.win].winfixheight = true

  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.win, M.buf)
  vim.bo[M.buf].buftype = "nofile"
  vim.bo[M.buf].modifiable = false
  vim.bo[M.buf].filetype = "springtools-output"

  M.setup_keymaps()
  M.show({ "Output panel ready" })
end

function M.close()
  if win_is_valid() then
    pcall(vim.api.nvim_win_close, M.win, true)
  end
  if buf_is_valid() then
    pcall(vim.api.nvim_buf_delete, M.buf, { force = true })
  end
  M.win = nil
  M.buf = nil
end

function M.show(lines, title)
  if not buf_is_valid() then
    M.open()
  end
  if not buf_is_valid() then return end

  M.title = title or "Output"
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(M.buf, M.ns, 0, -1)

  local display = { " " .. M.title, " " .. string.rep("─", 60) }
  for _, l in ipairs(lines) do
    table.insert(display, " " .. tostring(l))
  end

  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, display)
  vim.bo[M.buf].modifiable = false

  pcall(function()
    vim.api.nvim_win_set_cursor(M.win, { #display, 0 })
  end)
end

function M.append(line)
  if not buf_is_valid() then return end
  vim.bo[M.buf].modifiable = true
  local lines = vim.api.nvim_buf_get_lines(M.buf, 0, -1, false)
  table.insert(lines, " " .. tostring(line))
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.bo[M.buf].modifiable = false
  pcall(function()
    vim.api.nvim_win_set_cursor(M.win, { #lines, 0 })
  end)
end

function M.clear()
  if not buf_is_valid() then return end
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, { " " .. M.title, " " .. string.rep("─", 60) })
  vim.bo[M.buf].modifiable = false
end

function M.setup_keymaps()
  if not buf_is_valid() then return end
  components.set_keymap(M.buf, "q", function() M.close() end)
  components.set_keymap(M.buf, "<Esc>", function() M.close() end)
end

return M