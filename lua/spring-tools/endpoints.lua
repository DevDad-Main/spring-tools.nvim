local utils = require("spring-tools.utils")
local config = require("spring-tools.config")
local jp = require("spring-tools.java_parser")

local M = {}

M.endpoints = {}

function M.extract_path(annotation_line)
  local path = annotation_line:match("%((.*)%)")
  if not path then return "" end

  path = path:gsub('"', ""):gsub("'", "")
  path = path:match("^%s*(.-)%s*$")

  local parts = vim.split(path, ",")
  for _, part in ipairs(parts) do
    part = part:gsub("^%s*(.-)%s*$", "%1")
    if not part:match("=") then
      return part
    end
    local val = part:match("value%s*=%s*(.*)")
    if val then
      return val:gsub('"', ""):gsub("'", "")
    end
  end
  return ""
end

function M.determine_method(mapping_type, annotation_line)
  local default_method = jp.http_methods[mapping_type]
  if mapping_type == "RequestMapping" then
    local method_str = annotation_line:match("method%s*=%s*RequestMethod%.(%w+)")
    if not method_str then
      method_str = annotation_line:match("method%s*=%s*(%w+)")
    end
    if method_str then
      return method_str
    end
    return "GET"
  end
  return default_method
end

function M.scan_endpoints(dir)
  dir = dir or vim.fn.getcwd()
  local project_root = utils.find_project_root(dir)
  if not project_root then
    return {}
  end

  M.endpoints = {}
  local cache_key = "endpoint_index:" .. project_root

  if utils.cache.data and utils.cache.data[cache_key] then
    local cached = utils.cache.data[cache_key]
    local valid = true
    for _, entry in ipairs(cached) do
      if utils.file_modified_since(entry.file, entry.mtime) then
        valid = false
        break
      end
    end
    if valid and #cached > 0 then
      M.endpoints = cached
      return M.endpoints
    end
  end

  local java_files = utils.find_java_files(project_root)
  for _, file in ipairs(java_files) do
    local mtime = vim.fn.getftime(file)
    local parsed = jp.parse_file(file)
    if not parsed then goto continue end

    local endpoints = jp.find_endpoints(parsed, file)
    for _, ep in ipairs(endpoints) do
      ep.mtime = mtime
      table.insert(M.endpoints, ep)
    end

    parsed:cleanup()
    ::continue::
  end

  if not utils.cache.data then utils.cache.data = {} end
  utils.cache.data[cache_key] = M.endpoints
  utils.mark_dirty()
  utils.save_cache()

  return M.endpoints
end

function M.explore()
  M.scan_endpoints()

  if #M.endpoints == 0 then
    utils.notify("No REST endpoints detected", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, ep in ipairs(M.endpoints) do
    table.insert(items, ep)
  end

  table.sort(items, function(a, b)
    if a.method ~= b.method then
      local order = { GET = 1, POST = 2, PUT = 3, DELETE = 4, PATCH = 5 }
      return (order[a.method] or 99) < (order[b.method] or 99)
    end
    return a.path < b.path
  end)

  utils.pick(items, {
    prompt_title = " REST Endpoints (" .. #M.endpoints .. ") ",
    entry_maker = function(ep)
      return {
        value = ep,
        display = ep.method .. " " .. ep.path .. "  (" .. vim.fn.fnamemodify(ep.file, ":t") .. ")",
        ordinal = ep.method .. " " .. ep.path,
      }
    end,
  }, function(ep)
    local actions = {
      { label = "Jump to definition", ep = ep },
      { label = "Copy curl command", ep = ep },
      { label = "Open in browser", ep = ep },
    }
    utils.pick(actions, { prompt_title = " Endpoint: " .. ep.method .. " " .. ep.path }, function(action)
      if action.label == "Jump to definition" then
        vim.cmd("edit " .. ep.file)
        vim.api.nvim_win_set_cursor(0, { ep.line, 0 })
        vim.cmd("normal! zz")
      elseif action.label == "Copy curl command" then
        M.copy_curl(ep)
      elseif action.label == "Open in browser" then
        M.open_in_browser(ep)
      end
    end)
  end)
end

function M.copy_curl(ep)
  local port = "8080"
  local url = "http://localhost:" .. port .. ep.path
  local curl_cmd = "curl -X " .. ep.method .. " " .. url
  vim.fn.setreg("+", curl_cmd)
  utils.notify("Curl command copied to clipboard: " .. curl_cmd)
end

function M.open_in_browser(ep)
  local port = "8080"
  local url = "http://localhost:" .. port .. ep.path
  if vim.fn.has("mac") == 1 then
    vim.fn.system({ "open", url })
  elseif vim.fn.has("unix") == 1 then
    vim.fn.system({ "xdg-open", url })
  else
    utils.notify("Open in browser not supported on this OS", vim.log.levels.WARN)
  end
  utils.notify("Opening: " .. url)
end

return M
