local beans_mod = require("spring-tools.beans")
local project = require("spring-tools.project")
local sidebar = require("spring-tools.ui.sidebar")
local sections = require("spring-tools.ui.sections").new("beans")

local M = {}

M.title = "Beans"

M.items = {}

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

local type_order = { "controllers", "services", "repositories", "components", "configurations", "beans" }
local type_labels = {
  controllers = "Controllers", services = "Services", repositories = "Repositories",
  components = "Components", configurations = "Configurations", beans = "Beans",
}

local function build_bean_items_from(grouped, section_prefix, indent)
  indent = indent or 0
  local pad = string.rep("  ", indent)
  local items = {}
  for _, t in ipairs(type_order) do
    local sub = {}
    if t == "configurations" then
      for _, bean in ipairs(grouped[t]) do
        table.insert(sub, { type = "bean", bean = bean, indent = indent + 1 })
        for _, b in ipairs(grouped.beans or {}) do
          if b.parent == bean.name then
            table.insert(sub, { type = "bean_method", bean = b, indent = indent + 1 })
          end
        end
      end
    else
      for _, bean in ipairs(grouped[t]) do
        if t == "beans" and bean.parent then
          -- skip parented beans (shown under their @Configuration parent)
        else
          table.insert(sub, { type = "bean", bean = bean, indent = indent + 1 })
        end
      end
    end
    if #sub > 0 then
      local sk = (section_prefix or "") .. t
      local is_collapsed = sections:is_collapsed(sk)
      items[#items + 1] = { type = "header", section_key = sk, label = type_labels[t], collapsed = is_collapsed, indent = indent }
      if not is_collapsed then
        for _, item in ipairs(sub) do
          table.insert(items, item)
        end
      end
    end
  end
  return items
end

local function scan_project(proj_root)
  beans_mod.build_index(proj_root)
  return beans_mod.group_by_type()
end

function M.header()
  local count = 0
  if project.is_multi_project() then
    for _, data in pairs(M._project_data or {}) do
      for _, t in ipairs(type_order) do
        count = count + #(data.grouped[t] or {})
      end
    end
  else
    count = beans_mod.beans and #beans_mod.beans or 0
  end
  return { { "Spring Beans (" .. count .. ")", "SpringToolsHeader" } }
end

function M:load_items()
  local multi = project.is_multi_project()

  if not multi then
    if not beans_mod.index_built and #beans_mod.beans == 0 then
      M.items = { { type = "loading", label = "Indexing beans..." } }
      vim.defer_fn(function()
        beans_mod.build_index(scan_dir())
        sidebar.refresh()
      end, 1)
      return
    end
    local grouped = beans_mod.group_by_type()
    M.items = {}
    local items = build_bean_items_from(grouped, "", 0)
    for _, item in ipairs(items) do
      table.insert(M.items, item)
    end
  else
    local projs = project.get_workspace_projects()
    M._project_data = {}
    M.items = {}

    for _, proj in ipairs(projs) do
      local grouped = scan_project(proj.root)
      M._project_data[proj.root] = {
        name = proj.name,
        grouped = grouped,
        bean_count = #beans_mod.beans,
      }
    end

    for _, proj in ipairs(projs) do
      local data = M._project_data[proj.root]
      M.items[#M.items + 1] = { type = "project_header", label = data.name, project_root = proj.root }
      local items = build_bean_items_from(data.grouped, "beans:" .. proj.root .. ":", 1)
      for _, item in ipairs(items) do
        table.insert(M.items, item)
      end
    end
  end
end

function M:render_item(item, selected)
  if item.type == "loading" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsDim"
    return { { "  " .. item.label, hl } }
  end
  if item.type == "project_header" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsAccent"
    return { { "  \u{25be} " .. item.label, hl } }
  end
  if item.type == "header" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local pad = string.rep("  ", item.indent or 0)
    local hl = selected and "SpringToolsSelected" or "SpringToolsBeanHeader"
    return { { pad .. icon .. " " .. item.label, hl } }
  end
  if item.type == "bean_method" then
    local pad = string.rep("  ", item.indent or 3)
    local hl = selected and "SpringToolsSelected" or "SpringToolsBeanMethod"
    return { { pad .. "@" .. item.bean.name .. "()", hl } }
  end
  local pad = string.rep("  ", item.indent or 2)
  local hl = selected and "SpringToolsSelected" or "SpringToolsBeanName"
  return { { pad .. item.bean.name, hl } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "project_header" then return end
  if item.type == "header" then
    sections:toggle(item.section_key)
    sidebar.refresh()
    return
  end
  sidebar.open_in_main(item.bean.file, item.bean.line)
end

return M
