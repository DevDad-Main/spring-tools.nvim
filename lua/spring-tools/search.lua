local beans_mod = require("spring-tools.beans")
local endpoints_mod = require("spring-tools.endpoints")
local tests_mod = require("spring-tools.tests")
local config_mod = require("spring-tools.config_explorer")
local project = require("spring-tools.project")
local sidebar = require("spring-tools.ui.sidebar")
local utils = require("spring-tools.utils")
local config = require("spring-tools.config")

local M = {}

M.icons = {
  bean = "",
  bean_method = "",
  endpoint = "",
  test_class = "",
  test_method = "",
  config = "",
}

local function get_icon(key)
  local cfg = config.options.search and config.options.search.icons
  if cfg and cfg[key] then return cfg[key] end
  return M.icons[key]
end

local type_labels = {
  bean = "Bean",
  bean_method = "@Bean",
  endpoint = "Endpoint",
  test_class = "Test Class",
  test_method = "Test Method",
  config = "Config",
}

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

function M.collect()
  local roots = {}
  if project.is_multi_project() then
    for _, proj in ipairs(project.get_workspace_projects()) do
      if not proj.is_virtual then
        roots[#roots + 1] = { root = proj.root, name = proj.name }
      end
    end
  else
    local proj = project.get_active_project()
    local root = proj and proj.root or vim.fn.getcwd()
    roots[#roots + 1] = { root = root, name = vim.fn.fnamemodify(root, ":t") }
  end
  local entries = {}

  for _, proj_info in ipairs(roots) do
    local root = proj_info.root
    local prefix = (#roots > 1) and ("[" .. proj_info.name .. "] ") or ""

    -- Beans
    local ok, result = pcall(beans_mod.build_index, root)
    if ok and beans_mod.beans then
    local seen_beans = {}
    for _, bean in ipairs(beans_mod.beans) do
      if not bean.parent then
        entries[#entries + 1] = {
          type = "bean",
          icon = get_icon("bean"),
          label = prefix .. bean.name,
          detail = bean.type:sub(1, 1):upper() .. bean.type:sub(2),
          file = bean.file,
          line = bean.line,
        }
        seen_beans[bean.name] = true
      end
    end
    for _, bean in ipairs(beans_mod.beans) do
      if bean.parent then
        entries[#entries + 1] = {
          type = "bean_method",
          icon = get_icon("bean_method"),
          label = prefix .. bean.name .. "()",
          detail = bean.parent,
          file = bean.file,
          line = bean.line,
        }
      end
    end
  end

  -- Endpoints
  ok, _ = pcall(endpoints_mod.scan_endpoints, root)
  if ok and endpoints_mod.endpoints then
    for _, ep in ipairs(endpoints_mod.endpoints) do
      entries[#entries + 1] = {
        type = "endpoint",
        icon = get_icon("endpoint"),
        label = prefix .. ep.method .. " " .. ep.path,
        detail = ep.method_name,
        file = ep.file,
        line = ep.line,
      }
    end
  end

  -- Tests
  local test_ok, test_classes = pcall(tests_mod.find_test_methods, root)
  if test_ok and type(test_classes) == "table" then
    for _, test in ipairs(test_classes) do
      entries[#entries + 1] = {
        type = "test_class",
        icon = get_icon("test_class"),
          label = prefix .. test.class,
        detail = test.full_class,
        file = test.file,
        line = test.methods and test.methods[1] and test.methods[1].line or 1,
      }
      if test.methods then
        for _, method in ipairs(test.methods) do
          entries[#entries + 1] = {
            type = "test_method",
            icon = get_icon("test_method"),
            label = prefix .. method.name .. "()",
            detail = test.class,
            file = test.file,
            line = method.line,
          }
        end
      end
    end
  end

  -- Config properties
  ok, _ = pcall(config_mod.build_index, root)
  if ok and config_mod.properties then
    for _, prop in ipairs(config_mod.properties) do
      local source = prop.source or ""
      entries[#entries + 1] = {
        type = "config",
        icon = get_icon("config"),
        label = prefix .. prop.key,
        detail = (prop.value or "(empty)") .. " — " .. (prop.source or "application.properties"),
        file = prop.file,
        line = prop.line,
      }
    end
  end

  end

  return entries
end

function M.open()
  local entries = M.collect()
  if #entries == 0 then
    utils.notify("Nothing to search -- no Spring Boot project detected", vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, entry in ipairs(entries) do
    local tag = type_labels[entry.type] or entry.type
    local detail = entry.detail and ("  " .. entry.detail) or ""
    items[#items + 1] = {
      display = string.format("%s  %-40s %-11s%s", entry.icon, entry.label, tag, detail),
      entry = entry,
    }
  end

  if utils.has_telescope() and config.options.telescope.enable then
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values

    pickers.new({}, {
      prompt_title = "Spring Search (" .. #items .. " results)",
      finder = finders.new_table({
        results = items,
        entry_maker = function(item)
          return {
            value = item.entry,
            display = item.display,
            ordinal = item.entry.label .. " " .. (item.entry.detail or ""),
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            local e = selection.value
            if e.file then
              vim.schedule(function()
                sidebar.open_in_main(e.file, e.line)
                utils.notify(string.format("%s -- %s:%d", e.label, vim.fn.fnamemodify(e.file, ":t"), e.line))
              end)
            else
              utils.notify("No file location for " .. e.label, vim.log.levels.WARN)
            end
          end
        end)
        return true
      end,
    }):find()
    return
  end

  -- vim.ui.select fallback
  vim.ui.select(items, {
    prompt = "Spring Search (" .. #items .. " results)",
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then return end
    local e = choice.entry
    if e.file then
      sidebar.open_in_main(e.file, e.line)
      utils.notify(string.format("%s -- %s:%d", e.label, vim.fn.fnamemodify(e.file, ":t"), e.line))
    else
      utils.notify("No file location for " .. e.label, vim.log.levels.WARN)
    end
  end)
end

return M
