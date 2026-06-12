local M = {}

local function close_buf_by_name(name)
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win_id)
    local buf_name = vim.api.nvim_buf_get_name(buf)
    if buf_name:find(name, 1, true) and vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, true)
    end
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    if buf_name:find(name, 1, true) and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end
end

function M.close_dashboard()
  close_buf_by_name("spring.tools")
end

function M.create_float_win(opts)
  opts = opts or {}
  local fullscreen = opts.fullscreen
  local width, height, row, col

  if fullscreen then
    width = math.floor(vim.o.columns * 0.92)
    height = math.floor(vim.o.lines * 0.88)
    row = math.floor((vim.o.lines - height) / 2)
    col = math.floor((vim.o.columns - width) / 2)
  else
    width = opts.width or 80
    height = opts.height or 20
    row = opts.row or math.floor((vim.o.lines - height) / 2)
    col = opts.col or math.floor((vim.o.columns - width) / 2)
  end

  if opts.close_existing then
    if opts.name then close_buf_by_name(opts.name) end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  if opts.name then
    vim.api.nvim_buf_set_name(buf, opts.name)
  end

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
  return buf, win
end

function M.set_lines(buf, lines)
  pcall(function()
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    local text_lines = {}
    for _, line in ipairs(lines) do
      if type(line) == "table" then
        table.insert(text_lines, line[1] or "")
      else
        table.insert(text_lines, line)
      end
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, text_lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
  end)
end

function M.show_log_viewer(title, lines, opts)
  opts = opts or {}
  close_buf_by_name("spring.tools.logs")

  local buf, win = M.create_float_win({
    width = math.floor(vim.o.columns * 0.85),
    height = math.floor(vim.o.lines * 0.75),
    title = title,
    border = "double",
    name = "spring.tools.logs",
  })

  local display = {}
  local max_lines = 500
  local start = math.max(1, #lines - max_lines + 1)
  for i = start, #lines do
    table.insert(display, lines[i])
  end
  if #lines == 0 then
    table.insert(display, "  (waiting for output... press 'r' to refresh, 'q' to close)")
  end

  M.set_lines(buf, display)
  pcall(function()
    vim.api.nvim_win_set_cursor(win, { #display, 0 })
  end)

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    callback = function()
      pcall(vim.api.nvim_win_close, win, true)
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end, silent = true, nowait = true,
  })

  if opts.on_refresh then
    vim.api.nvim_buf_set_keymap(buf, "n", "r", "", {
      callback = function()
        pcall(vim.api.nvim_win_close, win, true)
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        opts.on_refresh()
      end, silent = true, nowait = true,
    })
  end

  vim.api.nvim_buf_set_keymap(buf, "n", "<C-u>", "", {
    callback = function()
      local cur = vim.api.nvim_win_get_cursor(win)
      vim.api.nvim_win_set_cursor(win, { math.max(1, cur[1] - 20), 0 })
    end, silent = true, nowait = true,
  })

  vim.api.nvim_buf_set_keymap(buf, "n", "<C-d>", "", {
    callback = function()
      local cur = vim.api.nvim_win_get_cursor(win)
      vim.api.nvim_win_set_cursor(win, { math.min(#display, cur[1] + 20), 0 })
    end, silent = true, nowait = true,
  })

  return buf, win
end

function M.start_background_job(cmd, cwd, callbacks)
  callbacks = callbacks or {}
  local all_data = {}

  local function collect_data(data)
    if not data then return end
    for _, line in ipairs(data) do
      if line ~= "" then
        table.insert(all_data, line)
      end
    end
  end

  local job_id = vim.fn.jobstart(cmd, {
    cwd = cwd,
    on_stdout = function(_, data)
      collect_data(data)
      if callbacks.on_stdout then callbacks.on_stdout(data) end
    end,
    on_stderr = function(_, data)
      collect_data(data)
      if callbacks.on_stderr then callbacks.on_stderr(data) end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if callbacks.on_exit then callbacks.on_exit(exit_code, all_data) end
      end)
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })

  return job_id, all_data
end

return M