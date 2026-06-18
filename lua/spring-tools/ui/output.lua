local components = require("spring-tools.ui.components")
local utils = require("spring-tools.utils")
local config = require("spring-tools.config")
local builtin_patterns = {
  { pattern = "%sERROR%s", hl = "SpringToolsLogError" },
  { pattern = "%sWARN%s", hl = "SpringToolsLogWarn" },
  { pattern = "%sINFO%s", hl = "SpringToolsLogInfo" },
  { pattern = "%sDEBUG%s", hl = "SpringToolsLogDebug" },
  { pattern = "%sTRACE%s", hl = "SpringToolsLogTrace" },
  { pattern = "%sFATAL%s", hl = "SpringToolsLogError" },
  { pattern = "%sSEVERE%s", hl = "SpringToolsLogError" },
  { pattern = "%[ERROR%]", hl = "SpringToolsLogError" },
  { pattern = "%[WARNING%]", hl = "SpringToolsLogWarn" },
  { pattern = "%[WARN%]", hl = "SpringToolsLogWarn" },
  { pattern = "%[INFO%]", hl = "SpringToolsLogInfo" },
  { pattern = "%[DEBUG%]", hl = "SpringToolsLogDebug" },
  { pattern = "%[TRACE%]", hl = "SpringToolsLogTrace" },
}
local service_hl_colors = {
  "SpringToolsLogInfo", "SpringToolsAccent", "SpringToolsLogWarn",
  "SpringToolsRunning", "SpringToolsLogDebug", "SpringToolsLogError", "SpringToolsLogInfo"
}


local M

local filter_order = { "error", "warn", "info", "debug", "trace" }

-- Lazy-init custom toggleable pattern (config may not be set at module load)
local custom_inited = false
local function ensure_custom_init()
  if custom_inited then return end
  custom_inited = true
  local cp = config.options.log and config.options.log.custom
  if cp and cp.pattern and cp.hl and cp.key then
    M._custom_key = cp.key
    M._custom_pattern = cp.pattern
    M.filter[cp.key] = true
    filter_order[#filter_order + 1] = cp.key
  end
end

local function get_log_patterns()
  ensure_custom_init()
  local all = {}
  -- Custom toggleable pattern checked FIRST (plain matching)
  local cp = config.options.log and config.options.log.custom
  if cp and cp.pattern and cp.hl then
    all[#all + 1] = { pattern = cp.pattern, hl = cp.hl, is_custom = true, plain = true }
  end
  -- Then extra patterns from config (plain matching)
  local custom = config.options.log and config.options.log.levels or {}
  for _, p in ipairs(custom) do all[#all + 1] = { pattern = p.pattern, hl = p.hl, plain = true } end
  -- Then built-in patterns (Lua pattern matching)
  for _, p in ipairs(builtin_patterns) do all[#all + 1] = p end
  -- Dynamic docker compose service patterns (plain matching, configurable)
  local svc_colors = config.options.log and config.options.log.service_colors or {}
  for i, svc in ipairs(M._detected_services or {}) do
    local hl = svc_colors[i] or service_hl_colors[(i - 1) % #service_hl_colors + 1]
    all[#all + 1] = { pattern = svc, hl = hl, plain = true }
  end
  return all
end

M = {}

M.buf = nil
M.win = nil
M.ns = vim.api.nvim_create_namespace("spring_tools_output")
M.title = "Output"
M._stored_logs = {}
M._suppress_open = false

M.filter = {
  error = true,
  warn = true,
  info = true,
  debug = true,
  trace = true,
}

local function buf_is_valid()
  return M.buf and vim.api.nvim_buf_is_valid(M.buf)
end

local function win_is_valid()
  return M.win and vim.api.nvim_win_is_valid(M.win)
end

local function line_level(line)
  for _, pat in ipairs(get_log_patterns()) do
    if line:find(pat.pattern, 1, true) then
      if pat.is_custom then return M._custom_key end
      local name = pat.hl:match("Log(%a+)$")
      if name then return name:lower() end
    end
  end
  return nil
end

M._service_filters = {}
M._detected_services = {}

local function detect_services()
  local seen = {}
  M._detected_services = {}
  for _, line in ipairs(M._stored_logs) do
    local svc = line:match("^%s-([a-zA-Z][%w-]+)%-%d+%s+|")
    if svc and not seen[svc] then
      seen[svc] = true
      M._detected_services[#M._detected_services + 1] = svc
      if M._service_filters[svc] == nil then
        M._service_filters[svc] = true
      end
    end
  end
  table.sort(M._detected_services)
end

local function line_service(line)
  local svc = line:match("^%s-([a-zA-Z][%w-]+)%-%d+%s+|")
  return svc
end

local function line_passes_filter(line)
  local level = line_level(line)
  if not level then return true end
  return M.filter[level] ~= false
end

local function is_at_bottom()
  if not win_is_valid() then return true end
  local line_count = vim.api.nvim_buf_line_count(M.buf)
  local cursor = vim.api.nvim_win_get_cursor(M.win)
  return cursor[1] >= line_count
end

local function scroll_to_bottom()
  if not win_is_valid() then return end
  pcall(function()
    local line_count = vim.api.nvim_buf_line_count(M.buf)
    vim.api.nvim_win_call(M.win, function()
      vim.api.nvim_win_set_cursor(0, { line_count, 0 })
    end)
  end)
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
  if #M._stored_logs > 0 then
    M._render_from_logs()
  else
    M.show({ "Output panel ready" })
  end
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

function M.toggle()
  if win_is_valid() then
    M.close()
  else
    M.open()
  end
end

local function strip_ansi(str)
  return str:gsub("\27%[[%d;]*[ABCDEFGHJKSTfminsuhl]", ""):gsub("\r", "")
end

function M.show(lines, title, opts)
  if not buf_is_valid() then
    if M._suppress_open then return end
    M.open()
  end
  if not buf_is_valid() then return end

  M.title = title or "Output"
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(M.buf, M.ns, 0, -1)

  local display = { " " .. M.title, " " .. string.rep("─", 60) }
  for _, l in ipairs(lines) do
    table.insert(display, " " .. strip_ansi(tostring(l)))
  end

  if opts and opts.footer then
    table.insert(display, " " .. string.rep("─", 60))
    for _, fl in ipairs(vim.split(M._footer_text(), "\n")) do
      table.insert(display, "  " .. fl)
    end
  end

  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, display)
  vim.bo[M.buf].modifiable = false
  M.highlight_logs()
  scroll_to_bottom()
end

function M.store_logs(all_logs)
  M._stored_logs = vim.tbl_map(strip_ansi, all_logs)
end

function M.append(line)
  if not buf_is_valid() then return end
  local was_at_bottom = is_at_bottom()
  vim.bo[M.buf].modifiable = true
  local lines = vim.api.nvim_buf_get_lines(M.buf, 0, -1, false)
  table.insert(lines, " " .. strip_ansi(tostring(line)))
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.bo[M.buf].modifiable = false
  M.highlight_logs()
  if was_at_bottom then
    scroll_to_bottom()
  end
end

function M.update_from_logs(all_logs, title)
  M._stored_logs = vim.tbl_map(strip_ansi, all_logs)
  M._pending_title = title or M._pending_title
  if not M._render_scheduled then
    M._render_scheduled = true
    vim.defer_fn(function()
      M._render_scheduled = false
      M._render_from_logs(M._pending_title)
      M._pending_title = nil
    end, 30)
  end
end

function M._render_from_logs(title)
  if not buf_is_valid() then
    if M._suppress_open then return end
    M.open()
  end
  if not buf_is_valid() then return end

  M.title = title or M.title or "Output"
  detect_services()
  M.setup_keymaps()
  local filtered = {}
  for _, l in ipairs(M._stored_logs) do
    if line_passes_filter(l) then
      local svc = line_service(l)
      if svc then
        if M._service_filters[svc] ~= false then
          table.insert(filtered, l)
        end
      else
        table.insert(filtered, l)
      end
    end
  end

  local start = math.max(1, #filtered - 50)
  local recent = {}
  for i = start, #filtered do
    table.insert(recent, filtered[i])
  end

  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(M.buf, M.ns, 0, -1)

  local display = { " " .. M.title, " " .. string.rep("─", 60) }
  for _, l in ipairs(recent) do
    table.insert(display, " " .. strip_ansi(tostring(l)))
  end
  table.insert(display, " " .. string.rep("─", 60))
  local footer_lines = vim.split(M._footer_text(), "\n")
  for _, fl in ipairs(footer_lines) do
    table.insert(display, "  " .. fl)
  end

  if M.win and vim.api.nvim_win_is_valid(M.win) then
    local pad = vim.api.nvim_win_get_height(M.win) - #display
    if pad > 0 then
      for _ = 1, pad do
        table.insert(display, 1, "")
      end
    end
  end

  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, display)
  vim.bo[M.buf].modifiable = false
  M.highlight_logs()
  scroll_to_bottom()
end

function M._footer_text()
  ensure_custom_init()
  local parts = {}
  for _, name in ipairs(filter_order) do
    if M.filter[name] then
      table.insert(parts, name:sub(1, 1):upper())
    else
      table.insert(parts, "·")
    end
  end
  local keys = "e/w/i/d/t toggle"
  if M._custom_key then keys = keys .. " · " .. M._custom_key .. " custom" end
  local result = "Filter: [" .. table.concat(parts, " ") .. "]  (" .. keys .. " · c copy output)"
  if #M._detected_services > 0 then
    local svc_parts = {}
    for i, svc in ipairs(M._detected_services) do
      if M._service_filters[svc] ~= false then
        table.insert(svc_parts, i .. ":" .. svc)
      else
        table.insert(svc_parts, "·:" .. svc)
      end
    end
    result = result .. "\n  Services: " .. table.concat(svc_parts, " ")
  end
  return result
end

function M.toggle_level(name)
  if M.filter[name] ~= nil then
    M.filter[name] = not M.filter[name]
  end
  if #M._stored_logs > 0 then
    M._render_from_logs()
  end
end

function M.refresh()
  if #M._stored_logs > 0 then
    M._render_from_logs()
  end
end

function M.toggle_service(index)
  local svc = M._detected_services[index]
  if svc then
    M._service_filters[svc] = not (M._service_filters[svc] ~= false)
    if #M._stored_logs > 0 then
      M._render_from_logs()
    end
  end
end

function M.clear()
  if not buf_is_valid() then return end
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, { " " .. M.title, " " .. string.rep("─", 60) })
  vim.bo[M.buf].modifiable = false
  M._stored_logs = {}
end

function M.highlight_logs()
  if not buf_is_valid() then return end
  vim.api.nvim_buf_clear_namespace(M.buf, M.ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(M.buf, 0, -1, false)
  for line_idx, line in ipairs(lines) do
    for _, lp in ipairs(get_log_patterns()) do
      local s, e = lp.plain and line:find(lp.pattern, 1, true) or line:find(lp.pattern)
      if s then
        vim.api.nvim_buf_set_extmark(M.buf, M.ns, line_idx - 1, s - 1, {
          end_col = e,
          hl_group = lp.hl,
          priority = lp.is_custom and 200 or (lp.hl:find("Log") and 150 or 100),
        })
      end
    end
  end
end

function M.setup_keymaps()
  ensure_custom_init()
  if not buf_is_valid() then return end
  local km = config.options.output.keymaps
  components.set_keymap(M.buf, km.close, function() M.close() end)
  if km.close_alt then
    components.set_keymap(M.buf, km.close_alt, function() M.close() end)
  end
  components.set_keymap(M.buf, km.copy, function()
    local lines = vim.api.nvim_buf_get_lines(M.buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    vim.fn.setreg("+", text)
    utils.notify("Output copied to clipboard")
  end, { desc = "Copy all output to clipboard" })
  components.set_keymap(M.buf, km.filter_error, function() M.toggle_level("error") end, { desc = "Toggle ERROR filter" })
  components.set_keymap(M.buf, km.filter_warn, function() M.toggle_level("warn") end, { desc = "Toggle WARN filter" })
  components.set_keymap(M.buf, km.filter_info, function() M.toggle_level("info") end, { desc = "Toggle INFO filter" })
  components.set_keymap(M.buf, km.filter_debug, function() M.toggle_level("debug") end, { desc = "Toggle DEBUG filter" })
  components.set_keymap(M.buf, km.filter_trace, function() M.toggle_level("trace") end, { desc = "Toggle TRACE filter" })
  if M._custom_key then
    local cp = config.options.log and config.options.log.custom
    local desc = cp and cp.pattern and ("Toggle '" .. cp.pattern .. "' filter") or "Toggle custom filter"
    components.set_keymap(M.buf, M._custom_key, function() M.toggle_level(M._custom_key) end, { desc = desc })
  end
  -- Number keys toggle service filters
  for i = 1, #M._detected_services do
    local svc = M._detected_services[i]
    components.set_keymap(M.buf, tostring(i), function() M.toggle_service(i) end, { desc = "Toggle " .. svc .. " logs" })
  end
end

return M
