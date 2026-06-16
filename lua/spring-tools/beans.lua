local utils = require("spring-tools.utils")
local config = require("spring-tools.config")
local jp = require("spring-tools.java_parser")

local M = {}

M.beans = {}
M.index_built = false

function M.build_index(dir)
  dir = dir or vim.fn.getcwd()
  local project_root = utils.find_project_root(dir)
  if not project_root then
    utils.notify("No Spring project root found", vim.log.levels.WARN)
    return {}
  end

  M.beans = {}
  local java_files = utils.find_java_files(project_root)
  local cache_key = "bean_index:" .. project_root

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
      M.beans = cached
      M.index_built = true
      return M.beans
    end
  end

  for _, file in ipairs(java_files) do
    local mtime = vim.fn.getftime(file)
    local parsed = jp.parse_file(file)
    if not parsed then goto continue end

    local beans = jp.find_beans(parsed, file)
    for _, bean in ipairs(beans) do
      table.insert(M.beans, {
        name = bean.name,
        type = bean.type,
        file = file,
        line = bean.line,
        mtime = mtime,
      })
    end

    local bean_methods = jp.find_bean_methods(parsed, file)
    for _, bm in ipairs(bean_methods) do
      table.insert(M.beans, {
        name = bm.name,
        type = "beans",
        parent = bm.parent,
        file = file,
        line = bm.line,
        mtime = mtime,
      })
    end

    parsed:cleanup()
    ::continue::
  end

  if not utils.cache.data then utils.cache.data = {} end
  utils.cache.data[cache_key] = M.beans
  utils.mark_dirty()
  utils.save_cache()

  M.index_built = true
  return M.beans
end

function M.group_by_type()
  local grouped = {
    controllers = {},
    services = {},
    repositories = {},
    components = {},
    configurations = {},
    beans = {},
  }

  for _, bean in ipairs(M.beans) do
    local t = bean.type
    if grouped[t] then
      table.insert(grouped[t], bean)
    else
      table.insert(grouped.components, bean)
    end
  end

  return grouped
end

function M.explore()
  if not M.index_built then
    M.build_index()
  end

  local grouped = M.group_by_type()
  local total = #M.beans

  local type_labels = {
    controllers = "Controllers",
    services = "Services",
    repositories = "Repositories",
    components = "Components",
    configurations = "Configurations",
    beans = "Beans",
  }

  local type_order = { "controllers", "services", "repositories", "components", "configurations", "beans" }

  local items = {}
  for _, t in ipairs(type_order) do
    if #grouped[t] > 0 then
      table.insert(items, { label = type_labels[t], type = "header" })
      for _, bean in ipairs(grouped[t]) do
        table.insert(items, { label = "  " .. bean.name, type = "bean", bean = bean })
      end
    end
  end

  if #items == 0 then
    utils.notify("No Spring beans detected", vim.log.levels.INFO)
    return
  end

  local buf, win
  local function refresh_view()
    M.build_index()
    M.explore()
  end

  local function navigate(item)
    if item.type == "bean" then
      local bean = item.bean
      vim.cmd("edit " .. bean.file)
      vim.api.nvim_win_set_cursor(0, { bean.line, 0 })
      vim.cmd("normal! zz")
    end
  end

  utils.pick(items, {
    prompt_title = " Spring Beans (" .. total .. ") ",
    entry_maker = function(item)
      if item.type == "header" then
        return { value = item, display = item.label, ordinal = item.label }
      else
        return { value = item, display = item.label, ordinal = item.bean.name }
      end
    end,
  }, navigate)
end

function M.jump_to_bean(name)
  for _, bean in ipairs(M.beans) do
    if bean.name == name then
      vim.cmd("edit " .. bean.file)
      vim.api.nvim_win_set_cursor(0, { bean.line, 0 })
      vim.cmd("normal! zz")
      return
    end
  end
  utils.notify("Bean not found: " .. name, vim.log.levels.WARN)
end

return M
