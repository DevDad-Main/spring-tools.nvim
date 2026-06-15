local project = require("spring-tools.project")
local utils = require("spring-tools.utils")

local M = {}

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

  -- Try to pretty-print JSON if jq is available
  local use_jq = vim.fn.executable("jq") == 1

  vim.fn.jobstart({ "sh", "-c", cmd }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      vim.schedule(function()
        local result = table.concat(data or {}, "\n")
        local response_body, meta = M._split_response(result)

        -- Pretty-print body if JSON
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

  -- Metadata
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

  -- Response body
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

  -- Detect if response is JSON and apply syntax
  if body:match('^%s*[{[]') then
    vim.bo[buf].filetype = "json"
  end

  -- Open in main editor
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

  -- Add "t" to re-send
  vim.keymap.set("n", "t", function()
    M.send(endpoint, extra_args)
  end, { buffer = buf, silent = true, nowait = true, desc = "Re-send request" })
end

return M
