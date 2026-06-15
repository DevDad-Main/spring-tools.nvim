local project = require("spring-tools.project")
local utils = require("spring-tools.utils")

local M = {}

local curl_suggestions = {
  "-H \"Content-Type: application/json\"",
  "-H \"Authorization: Bearer \"",
  "-H \"Accept: application/json\"",
  "-d '{}'",
  "-d '{\"key\": \"value\"}'",
  "-v",
  "-i",
  "-s",
  "-L",
  "-o /dev/null",
  "-w '\\n%{http_code}'",
}

function M._show_curl_input(endpoint, default_text, on_submit)
  local width = math.min(80, vim.o.columns - 4)
  local row = math.floor((vim.o.lines - 3) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "prompt"
  vim.bo[buf].filetype = "springtools-curl-input"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = 1,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " curl args for " .. endpoint.method .. " " .. endpoint.path .. " ",
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
    vim.cmd([[
      function! SpringToolsCurlOmni(findstart, base)
        return v:lua.require'spring-tools.http_client'._curl_omni(a:findstart, a:base)
      endfunction
    ]])
  end
  vim.bo[buf].omnifunc = "SpringToolsCurlOmni"
  vim.bo[buf].complete = "."

  -- Tab: trigger or cycle completion
  vim.keymap.set("i", "<Tab>", function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n")
    else
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-o>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  -- Ctrl+j/k navigate popup
  vim.keymap.set("i", "<C-j>", function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-n>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("i", "<C-k>", function()
    if vim.fn.pumvisible() == 1 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-p>", true, false, true), "n")
    end
  end, { buffer = buf, silent = true })

  -- Escape / q close
  vim.keymap.set("i", "<Esc>", function() cleanup() end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "q", function() cleanup() end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", function() cleanup() end, { buffer = buf, silent = true, nowait = true })

  -- Block window navigation in normal mode
  vim.keymap.set("n", "<C-w>", "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-h>", "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-j>", "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-k>", "<Nop>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<C-l>", "<Nop>", { buffer = buf, silent = true })

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

  vim.cmd("startinsert!")
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
  for _, s in ipairs(curl_suggestions) do
    if s:lower():find(base:lower(), 1, true) then
      results[#results + 1] = { word = s, menu = "curl" }
    end
  end
  return results
end

function M.send(endpoint, extra_args)
  extra_args = extra_args or ""

  -- Auto-detect port from running process
  local port = "8080"
  local proj = project.get_active_project()
  if proj then
    local be = project.get_backend_for_project(proj)
    if be and be.get_port then
      local p = be:get_port(proj)
      if p and p ~= "" then port = p end
    end
  end

  local url = "http://localhost:" .. port .. endpoint.path
  local cmd = string.format(
    "curl -s -w '\\n\\n--- RESPONSE ---\\nHTTP_CODE:%%{http_code}\\nTIME:%%{time_total}s\\nSIZE:%%{size_download} bytes' %s -X %s '%s'",
    extra_args, endpoint.method, url
  )

  local use_jq = vim.fn.executable("jq") == 1

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

        M._show_response(endpoint, port, response_body, meta, extra_args)
        utils.notify(endpoint.method .. " " .. endpoint.path .. " → done", vim.log.levels.INFO)
      end)
    end,
    on_stderr = function(_, data)
      vim.schedule(function()
        local err = table.concat(data or {}, "\n")
        if err ~= "" then
          utils.notify("Request error: " .. err, vim.log.levels.WARN)
        end
      end)
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

function M._show_response(endpoint, port, body, meta, extra_args)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = true

  local lines = {}
  local url = "http://localhost:" .. port .. endpoint.path

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
      M.send(endpoint, input)
    end)
  end, { buffer = buf, silent = true, nowait = true, desc = "Re-send request" })
end

return M
