local beans_mod = require("spring-tools.beans")
local project = require("spring-tools.project")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")

local M = {}

M.title = "Beans"

M.items = {}

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

function M.header()
  beans_mod.build_index(scan_dir())
  return { { "Spring Beans (" .. #beans_mod.beans .. ")", "SpringToolsHeader" } }
end

function M:load_items()
  beans_mod.build_index(scan_dir())
  local grouped = beans_mod.group_by_type()
  local type_order = { "controllers", "services", "repositories", "components", "configurations", "beans" }
  local type_labels = { controllers = "Controllers", services = "Services", repositories = "Repositories", components = "Components", configurations = "Configurations", beans = "Beans" }

  M.items = {}
  for _, t in ipairs(type_order) do
    if #grouped[t] > 0 then
      table.insert(M.items, { type = "header", label = type_labels[t] })
      if t == "configurations" then
        for _, bean in ipairs(grouped[t]) do
          table.insert(M.items, { type = "bean", bean = bean })
          for _, b in ipairs(grouped.beans or {}) do
            if b.parent == bean.name then
              table.insert(M.items, { type = "bean_method", bean = b })
            end
          end
        end
      else
        for _, bean in ipairs(grouped[t]) do
          if t == "beans" and bean.parent then goto skip_bean end
          table.insert(M.items, { type = "bean", bean = bean })
          ::skip_bean::
        end
      end
    end
  end
end

function M:render_item(item, selected)
  if item.type == "header" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsAccent"
    return { { "  \u{25b8} " .. item.label, hl } }
  end
  if item.type == "bean_method" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsDim"
    return { { "        @" .. item.bean.name .. "()", hl } }
  end
  local hl = selected and "SpringToolsSelected" or nil
  return { { "      " .. item.bean.name, hl } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "header" then
    local next = idx + 1
    while next <= #M.items do
      local nt = M.items[next].type
      if nt == "bean" or nt == "bean_method" then
        sidebar.selected = next
        sidebar.refresh()
        M:on_activate(next)
        return
      end
      next = next + 1
    end
    return
  end
  sidebar.open_in_main(item.bean.file, item.bean.line)
end

return M
