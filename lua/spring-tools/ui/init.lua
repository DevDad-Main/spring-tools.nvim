local M = {}

function M.create_float_win(opts)
  opts = opts or {}
  local width = opts.width or 80
  local height = opts.height or 20
  local row = opts.row or math.floor((vim.o.lines - height) / 2)
  local col = opts.col or math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_name(buf, opts.title or "spring-tools")

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = opts.border or "rounded",
    title = opts.title or "",
    title_pos = "center",
  })

  vim.api.nvim_win_set_option(win, "winhl", "Normal:NormalFloat,FloatBorder:FloatBorder")
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true, nowait = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true, nowait = true })

  return buf, win
end

function M.set_lines(buf, lines, start_row)
  start_row = start_row or 0
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

function M.set_highlights(buf, highlights)
  for _, h in ipairs(highlights) do
    local ns = vim.api.nvim_create_namespace("spring-tools-hl")
    vim.api.nvim_buf_add_highlight(buf, ns, h.group, h.line, h.col_start or 0, h.col_end or -1)
  end
end

function M.close_float(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

function M.show_log_win(lines, title)
  title = title or "Spring Boot Logs"
  local buf, win = M.create_float_win({
    width = 100,
    height = 30,
    title = title,
  })
  M.set_lines(buf, lines)
  vim.api.nvim_win_set_cursor(win, { #lines, 0 })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
  return buf, win
end

function M.run_in_terminal(cmd, cwd, on_exit)
  if vim.fn.executable(cmd[1]) ~= 1 then
    utils.notify("Command not found: " .. cmd[1], vim.log.levels.ERROR)
    return nil
  end

  local term_opts = {
    cmd = cmd,
    cwd = cwd,
    on_exit = on_exit,
    clear_env = false,
  }

  if config.options.terminal == "float" then
    vim.cmd("new")
    vim.cmd("term " .. table.concat(vim.tbl_map(vim.fn.shellescape, cmd), " "))
    vim.cmd("startinsert")
  else
    vim.fn.termopen(cmd, term_opts)
    vim.cmd("startinsert")
  end
end

return M
