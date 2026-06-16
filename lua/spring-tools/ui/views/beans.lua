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

function M.header()
  local count = beans_mod.beans and #beans_mod.beans or 0
  return { { "Spring Beans (" .. count .. ")", "SpringToolsHeader" } }
end

function M:load_items()
  beans_mod.build_index(scan_dir())
  local grouped = beans_mod.group_by_type()

  M.items = {}
  for _, t in ipairs(type_order) do
    local items = {}
    if t == "configurations" then
      for _, bean in ipairs(grouped[t]) do
        table.insert(items, { type = "bean", bean = bean })
        for _, b in ipairs(grouped.beans or {}) do
          if b.parent == bean.name then
            table.insert(items, { type = "bean_method", bean = b })
          end
        end
      end
    else
      for _, bean in ipairs(grouped[t]) do
        if t == "beans" and bean.parent then
          -- skip parented beans (shown under their @Configuration parent)
        else
          table.insert(items, { type = "bean", bean = bean })
        end
      end
    end
    if #items > 0 then
      local is_collapsed = sections:is_collapsed(t)
      M.items[#M.items + 1] = { type = "header", section_key = t, label = type_labels[t], collapsed = is_collapsed }
      if not is_collapsed then
        for _, item in ipairs(items) do
          table.insert(M.items, item)
        end
      end
    end
  end
end

function M:render_item(item, selected)
  if item.type == "header" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local hl = selected and "SpringToolsSelected" or "SpringToolsBeanHeader"
    return { { "  " .. icon .. " " .. item.label, hl } }
  end
  if item.type == "bean_method" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsBeanMethod"
    return { { "        @" .. item.bean.name .. "()", hl } }
  end
  local hl = selected and "SpringToolsSelected" or "SpringToolsBeanName"
  return { { "      " .. item.bean.name, hl } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "header" then
    sections:toggle(item.section_key)
    sidebar.refresh()
    return
  end
  sidebar.open_in_main(item.bean.file, item.bean.line)
end

return M
