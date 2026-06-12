local utils = require("spring-tools.utils")
local config = require("spring-tools.config")

local M = {}

M.endpoints = {}

local http_methods = {
  "GetMapping",
  "PostMapping",
  "PutMapping",
  "DeleteMapping",
  "PatchMapping",
  "RequestMapping",
}

local method_map = {
  GetMapping = "GET",
  PostMapping = "POST",
  PutMapping = "PUT",
  DeleteMapping = "DELETE",
  PatchMapping = "PATCH",
  RequestMapping = nil,
}

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
  local default_method = method_map[mapping_type]
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
    utils.notify("No Spring project root found", vim.log.levels.WARN)
    return {}
  end

  M.endpoints = {}
  local java_files = utils.find_java_files(project_root)
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

  for _, file in ipairs(java_files) do
    local f = io.open(file, "r")
    if not f then goto continue end
    local content = f:read("*a")
    f:close()

    local mtime = vim.fn.getftime(file)
    local lines = vim.split(content, "\n", { plain = true })

    local class_mapping = ""
    local in_controller = false

    for i, line in ipairs(lines) do
      local stripped = line:gsub("%s+", "")

      if stripped:find("@RestController") or stripped:find("@Controller") then
        in_controller = true
        class_mapping = ""
      end

      local class_request = false
      if stripped:find("@RequestMapping") and in_controller then
        class_mapping = M.extract_path(line)
        class_request = true
      end

      for _, method in ipairs(http_methods) do
        if stripped:find("@" .. method) then
          if method == "RequestMapping" and class_request then
            goto continue_method
          end
          local method_path = M.extract_path(line)
          local http_method = M.determine_method(method, line)
          local full_path = class_mapping .. method_path
          if full_path == "" then full_path = "/" end

          local method_name = nil
          for j = i, math.min(i + 5, #lines) do
            local func_match = lines[j]:match("public%s+%w+%s+(%w+)%s*%(")
            if func_match then
              method_name = func_match
              break
            end
          end

          table.insert(M.endpoints, {
            method = http_method,
            path = full_path,
            file = file,
            line = i,
            method_name = method_name,
            mtime = mtime,
          })
        end
        ::continue_method::
      end
    end

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
