local utils = require("spring-tools.utils")
local config = require("spring-tools.config")

local M = {}

M.beans = {}
M.index_built = false

local bean_annotations = {
  "Component",
  "Service",
  "Repository",
  "Controller",
  "RestController",
  "Configuration",
  "Bean",
}

local category_map = {
  Component = "components",
  Service = "services",
  Repository = "repositories",
  Controller = "controllers",
  RestController = "controllers",
  Configuration = "configurations",
  Bean = "beans",
}

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
    if valid then
      M.beans = cached
      M.index_built = true
      return M.beans
    end
  end

  for _, file in ipairs(java_files) do
    local f = io.open(file, "r")
    if not f then goto continue end
    local content = f:read("*a")
    f:close()

    local mtime = vim.fn.getftime(file)
    local lines = vim.split(content, "\n", { plain = true })

    local class_name = nil
    local class_line = nil
    local class_type = nil

    for i, line in ipairs(lines) do
      local stripped = line:gsub("%s+", "")

      for _, annotation in ipairs(bean_annotations) do
        local pattern = "@" .. annotation
        if stripped:find(pattern, 1, true) then
          class_type = category_map[annotation]

          if annotation == "Bean" then
            local method_match = line:match("public%s+%w+%s+(%w+)%s*%(")
            if method_match then
              table.insert(M.beans, {
                name = method_match,
                type = "bean",
                file = file,
                line = i,
                mtime = mtime,
              })
            end
          else
            for j = i, math.min(i + 5, #lines) do
              local class_match = lines[j]:match("(class|interface)%s+(%w+)")
              if class_match then
                class_name = class_match
                break
              end
            end
          end
          break
        end
      end

      if class_name and class_type then
        table.insert(M.beans, {
          name = class_name,
          type = class_type,
          file = file,
          line = i,
          mtime = mtime,
        })
        class_name = nil
        class_type = nil
      end
    end

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
