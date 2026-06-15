local project = require("spring-tools.project")
local utils = require("spring-tools.utils")
local config = require("spring-tools.config")

local M = {}

function M._show_prompt(title, on_submit)
  local width = math.min(64, vim.o.columns - 4)
  local row = math.floor((vim.o.lines - 3) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "prompt"
  pcall(vim.fn.prompt_setprompt, buf, "")
  vim.bo[buf].complete = ""

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = 1,
    row = row, col = col, style = "minimal",
    border = "rounded", title = " " .. title .. " ", title_pos = "center",
  })
  vim.wo[win].winfixbuf = true

  local closing = false
  local function cleanup()
    if closing then return end
    closing = true
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end

  vim.fn.prompt_setcallback(buf, function(text)
    cleanup()
    on_submit(text)
  end)

  local km = config.options.command_input.keymaps
  vim.keymap.set("i", km.close, function() cleanup() end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", km.close, function() cleanup() end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", km.close_alt, function() cleanup() end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", km.popup_next, "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", km.popup_prev, "<Nop>", { buffer = buf, silent = true })
  vim.api.nvim_set_current_win(win)
  vim.cmd("startinsert!")
end

local default_suggestions = {
  { word = "-H \"Content-Type: application/json\"", menu = "set JSON content type" },
  { word = "-H \"Authorization: Bearer \"", menu = "auth bearer token" },
  { word = "-H \"Accept: application/json\"", menu = "accept JSON response" },
  { word = "-H \"X-API-Key: \"", menu = "custom API key header" },
  { word = "-d '{}'", menu = "empty JSON body" },
  { word = "-d '{\"key\": \"value\"}'", menu = "JSON body with data" },
  { word = "-v", menu = "verbose output" },
  { word = "-i", menu = "include response headers" },
  { word = "-s", menu = "silent mode (no progress)" },
  { word = "-L", menu = "follow redirects" },
  { word = "-o /dev/null", menu = "discard response body" },
  { word = "-w '\\n%{http_code}'", menu = "print HTTP status code" },
}

function M._show_curl_input(endpoint, default_text, on_submit, resolved_path)
  resolved_path = resolved_path or endpoint.path
  local width = math.min(80, vim.o.columns - 4)
  local row = math.floor((vim.o.lines - 3) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "prompt"
  pcall(vim.fn.prompt_setprompt, buf, "")
  vim.bo[buf].complete = ""
  vim.b[buf].cmp_enabled = false
  vim.b[buf].cmp_disable = true
  vim.b[buf].blink_cmp_disable = true

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " curl args for " .. endpoint.method .. " " .. resolved_path .. " ",
    title_pos = "center",
  })
  vim.wo[win].winfixbuf = true

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default_text or "" })

  local closing = false
  local function cleanup()
    if closing then return end
    closing = true
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end

  -- Prompt callback submits on Enter
  vim.fn.prompt_setcallback(buf, function(text)
    vim.schedule(function()
      cleanup()
      on_submit(text)
    end)
  end)

  -- Setup omnifunc
  if not M._omni_reg then
    M._omni_reg = true
    pcall(vim.cmd, [[
      function! SpringToolsCurlOmni(findstart, base)
        return luaeval("require('spring-tools.http_client')._curl_omni(_A[1], _A[2])", [a:findstart, a:base])
      endfunction
    ]])
  end
  vim.bo[buf].omnifunc = "SpringToolsCurlOmni"

  local km = config.options.command_input.keymaps

  -- Tab: cycle popup or trigger completion
  vim.keymap.set("i", km.complete, function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n")
    else
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  -- Ctrl+Space: trigger completion
  vim.keymap.set("i", km.trigger, function()
    vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n")
  end, { buffer = buf, silent = true })

  -- Popup nav
  vim.keymap.set("i", km.popup_next, function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })
  vim.keymap.set("i", km.popup_prev, function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-p>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  -- Close
  vim.keymap.set("i", km.close, function() cleanup() end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", km.close_alt, function() cleanup() end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", km.close, function() cleanup() end, { buffer = buf, silent = true, nowait = true })

  -- Block window nav
  vim.keymap.set("n", "<C-w>", "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-h>", "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-j>", "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-k>", "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-l>", "<Nop>", { buffer = buf, silent = true })

  -- Auto-trigger completion as user types
  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      if vim.fn.pumvisible() == 1 then return end
      local col = vim.api.nvim_win_get_cursor(0)[2]
      if col < 1 then return end
      local line = vim.api.nvim_get_current_line()
      local char = line:sub(col + 1, col + 1)
      if not char:match("[%w:_%-.@/]") then return end
      vim.schedule(function()
        if vim.fn.mode() ~= "i" then return end
        vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n")
      end)
    end,
  })

  -- Close when focus leaves
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      if closing then return end
      vim.schedule(function()
        local ok, _ = pcall(vim.api.nvim_win_is_valid, win)
        if ok then cleanup() end
      end)
    end,
  })

  vim.bo[buf].filetype = "springtools-curl-input"
  vim.cmd("startinsert!")
  vim.api.nvim_win_set_cursor(win, { 1, #default_text })
end
function M._curl_omni(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local start = col
    while start > 0 and line:sub(start, start):match("[^%s]") do
      start = start - 1
    end
    return start
  end

  local results = {}
  local suggestions = config.options.command_input.curl_suggestions or default_suggestions
  for _, s in ipairs(suggestions) do
    if s.word:lower():find(base:lower(), 1, true) then
      results[#results + 1] = s
    end
  end

  -- Include history
  local cache_key = "curl_args_history"
  local history = (utils.cache.data and utils.cache.data[cache_key]) or {}
  local seen = {}
  for i = #history, 1, -1 do
    local cmd = history[i]
    if cmd:lower():find(base:lower(), 1, true) and not seen[cmd] then
      seen[cmd] = true
      results[#results + 1] = { word = cmd, menu = "history" }
    end
  end

  return results
end

function M.send(endpoint, extra_args, resolved_path)
  extra_args = extra_args or ""
  M._send_resolved(endpoint, extra_args, resolved_path or endpoint.path)
end

function M._send_resolved(endpoint, extra_args, path)

  -- Save to history (non-empty, unique args)
  if extra_args ~= "" then
    local cache_key = "curl_args_history"
    if not utils.cache.data then utils.cache.data = {} end
    local history = utils.cache.data[cache_key] or {}
    history[#history + 1] = extra_args
    if #history > 20 then table.remove(history, 1) end
    utils.cache.data[cache_key] = history
    utils.mark_dirty()
    utils.save_cache()
  end

  -- Auto-detect port from any running process
  local port = "8080"
  local backend = require("spring-tools.core.backend")
  local all_procs = backend.ProcessManager.get_all()
  for _, proc in pairs(all_procs) do
    if proc.status == "running" and proc.port then
      port = proc.port
      break
    end
  end
  -- Fallback: read server.port from active project's properties
  if port == "8080" then
    local proj = project.get_active_project()
    if proj then
      local prop_path = proj.root .. "/src/main/resources/application.properties"
      local ok, lines = pcall(vim.fn.readfile, prop_path)
      if ok and lines then
        for _, line in ipairs(lines) do
          local p = line:match("^server%.port%s*=%s*(%d+)")
          if p then port = p; break end
        end
      end
    end
  end

  local url = "http://localhost:" .. port .. path
  local cmd = string.format(
    "curl -s -w '\\n\\n--- RESPONSE ---\\nHTTP_CODE:%%{http_code}\\nTIME:%%{time_total}s\\nSIZE:%%{size_download} bytes' %s -X %s '%s'",
    extra_args, endpoint.method, url
  )

  local use_jq = vim.fn.executable("jq") == 1

  local stderr_lines = {}
  vim.fn.jobstart({ "sh", "-c", cmd }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      vim.schedule(function()
        local result = table.concat(data or {}, "\n")
        local response_body, meta = M._split_response(result)

        if use_jq and response_body ~= "" then
          local jq_out = vim.fn.systemlist("echo " .. vim.fn.shellescape(response_body) .. " | jq . 2>/dev/null")
          if #jq_out > 0 then response_body = table.concat(jq_out, "\n") end
        end

        local verbose = table.concat(stderr_lines, "\n")
        M._show_response(endpoint, port, response_body, meta, extra_args, path, verbose)
        utils.notify(endpoint.method .. " " .. endpoint.path .. " → done", vim.log.levels.INFO)
      end)
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then stderr_lines[#stderr_lines + 1] = line end
      end
    end,
  })
end

function M._split_response(raw)
  local body, meta = raw, {}
  local sep = raw:find("\n\n--- RESPONSE ---\n")
  if sep then
    body = raw:sub(1, sep - 1)
    local meta_str = raw:sub(sep)
    for line in meta_str:gmatch("[^\n]+") do
      local k, v = line:match("^(%w+):(.+)$")
      if k and v then meta[k] = v end
    end
  end
  return body, meta
end

function M._show_response(endpoint, port, body, meta, extra_args, resolved_path, verbose_out)
  resolved_path = resolved_path or endpoint.path
  verbose_out = verbose_out or ""
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = true

  local lines = {}
  local url = "http://localhost:" .. port .. resolved_path

  table.insert(lines, string.rep("─", 60))
  table.insert(lines, "  " .. endpoint.method .. " " .. url)
  if extra_args ~= "" then
    table.insert(lines, "  Args: " .. extra_args)
  end
  table.insert(lines, string.rep("─", 60))
  table.insert(lines, "")

  if meta.HTTP_CODE then
    table.insert(lines, "  Status: " .. meta.HTTP_CODE)
  end
  if meta.TIME then
    table.insert(lines, "  Time:   " .. meta.TIME)
  end
  if meta.SIZE then
    table.insert(lines, "  Size:   " .. meta.SIZE)
  end
  table.insert(lines, "")

  if body ~= "" then
    table.insert(lines, "  Response:")
    for line in body:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
  else
    table.insert(lines, "  (empty response)")
  end

  if verbose_out ~= "" then
    table.insert(lines, "")
    table.insert(lines, string.rep("─", 60))
    table.insert(lines, "  Verbose:")
    for line in verbose_out:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  if body:match('^%s*[{[]') then
    vim.bo[buf].filetype = "json"
  end

  local sidebar_mod = require("spring-tools.ui.sidebar")
  local main_win = nil
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if w ~= sidebar_mod.win then
      local b = vim.api.nvim_win_get_buf(w)
      if vim.bo[b].filetype ~= "springtools-output" then main_win = w; break end
    end
  end
  if main_win then vim.api.nvim_set_current_win(main_win) end
  vim.api.nvim_set_current_buf(buf)

  local function close()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, nowait = true })

  vim.keymap.set("n", "t", function()
    M._show_curl_input(endpoint, extra_args, function(input)
      M.send(endpoint, input, resolved_path)
    end, resolved_path)
  end, { buffer = buf, silent = true, nowait = true, desc = "Re-send request" })
end

return M
