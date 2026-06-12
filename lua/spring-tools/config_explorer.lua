local ui = require("spring-tools.ui")
local utils = require("spring-tools.utils")
local config = require("spring-tools.config")

local M = {}

M.properties = {}
M.config_files = {}

function M.find_config_files(project_root)
  local config_dirs = {
    project_root .. "/src/main/resources",
    project_root .. "/src/main/resources/config",
    project_root .. "/config",
    project_root,
  }

  local files = {}
  for _, dir in ipairs(config_dirs) do
    if vim.fn.isdirectory(dir) == 1 then
      local patterns = { "application%.properties", "application.*%.properties", "application.*%.yml", "application.*%.yaml", "bootstrap.*%.properties", "bootstrap.*%.yml" }
      for _, pat in ipairs(patterns) do
        local handle = io.popen("find " .. utils.escape_shell_arg(dir) .. " -maxdepth 1 -name '" .. pat .. "' 2>/dev/null")
        if handle then
          for f in handle:lines() do
            table.insert(files, f)
          end
          handle:close()
        end
      end
    end
  end

  M.config_files = files
  return files
end

function M.parse_properties(content, source)
  local props = {}
  for raw_line in content:gmatch("([^\n]+)") do
    local line = raw_line:gsub("#.*", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and line:find("=") then
      local key, value = line:match("([^=]+)=%s*(.*)")
      if key then
        key = key:gsub("^%s+", ""):gsub("%s+$", "")
        value = value:gsub("^%s+", ""):gsub("%s+$", "")
        table.insert(props, {
          key = key,
          value = value,
          source = source,
          raw_line = raw_line,
        })
      end
    end
  end
  return props
end

function M.parse_yaml(content, file_path)
  local props = {}
  local stack = {}
  local source = vim.fn.fnamemodify(file_path, ":t")

  for line in content:gmatch("([^\n]+)") do
    local indent = #line:match("^(%s*)")
    local stripped = line:gsub("^%s+", "")
    local key = stripped:match("([%w%.%-_]+):")
    local value = stripped:match(":%s*(.*)")

    if key then
      while #stack > 0 and stack[#stack].indent >= indent do
        table.remove(stack)
      end

      table.insert(stack, { key = key, indent = indent, value = value })

      local full_key = ""
      for i, s in ipairs(stack) do
        if i > 1 then full_key = full_key .. "." end
        full_key = full_key .. s.key
      end

      if value and value ~= "" then
        table.insert(props, {
          key = full_key,
          value = value,
          source = source,
          file = file_path,
        })
      end
    end
  end

  return props
end

function M.build_index(project_root)
  project_root = project_root or utils.find_project_root(vim.fn.getcwd())
  if not project_root then return {} end

  M.properties = {}
  local cache_key = "config_index:" .. project_root

  if utils.cache.data and utils.cache.data[cache_key] then
    local cached = utils.cache.data[cache_key]
    local valid = true
    for _, entry in ipairs(cached) do
      if entry.file and utils.file_modified_since(entry.file, entry.mtime or 0) then
        valid = false
        break
      end
    end
    if valid then
      M.properties = cached
      return M.properties
    end
  end

  local files = M.find_config_files(project_root)
  for _, f in ipairs(files) do
    local handle = io.open(f, "r")
    if handle then
      local content = handle:read("*a")
      handle:close()
      local mtime = vim.fn.getftime(f)
      local extracted

      if f:match("%.yml$") or f:match("%.yaml$") then
        extracted = M.parse_yaml(content, f)
      else
        extracted = M.parse_properties(content, vim.fn.fnamemodify(f, ":t"))
      end

      for _, prop in ipairs(extracted) do
        prop.file = f
        prop.mtime = mtime
        table.insert(M.properties, prop)
      end
    end
  end

  if not utils.cache.data then utils.cache.data = {} end
  utils.cache.data[cache_key] = M.properties
  utils.mark_dirty()
  utils.save_cache()

  return M.properties
end

function M.explore()
  local project_root = utils.find_project_root(vim.fn.getcwd())
  if not project_root then
    utils.notify("No Spring project found", vim.log.levels.WARN)
    return
  end

  M.build_index(project_root)

  if #M.properties == 0 then
    utils.notify("No configuration properties found", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, prop in ipairs(M.properties) do
    table.insert(items, prop)
  end

  table.sort(items, function(a, b)
    return a.key < b.key
  end)

  utils.pick(items, {
    prompt_title = " Spring Config (" .. #M.properties .. ") ",
    entry_maker = function(prop)
      return {
        value = prop,
        display = prop.key .. " = " .. prop.value .. "  (" .. prop.source .. ")",
        ordinal = prop.key,
      }
    end,
  }, function(prop)
    if prop.file then
      vim.cmd("edit " .. prop.file)
      vim.api.nvim_win_set_cursor(0, { prop.line or 1, 0 })
    else
      utils.notify("Config source file unknown", vim.log.levels.WARN)
    end
  end)
end

function M.search_property(query)
  M.build_index()
  local results = {}

  for _, prop in ipairs(M.properties) do
    if prop.key:lower():find(query:lower(), 1, true) or
       (prop.value:lower():find(query:lower(), 1, true)) then
      table.insert(results, prop)
    end
  end

  if #results == 0 then
    utils.notify("No matching properties found for: " .. query, vim.log.levels.INFO)
    return
  end

  local items = results
  utils.pick(items, {
    prompt_title = " Search Results (" .. #results .. ") ",
    entry_maker = function(prop)
      return {
        value = prop,
        display = prop.key .. " = " .. prop.value .. "  (" .. prop.source .. ")",
        ordinal = prop.key,
      }
    end,
  }, function(prop)
    if prop.file then
      vim.cmd("edit " .. prop.file)
      vim.api.nvim_win_set_cursor(0, { prop.line or 1, 0 })
    end
  end)
end

return M
