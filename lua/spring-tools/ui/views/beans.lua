local beans_mod = require("spring-tools.beans")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")

local M = {}

M.title = "Beans"

M.items = {}

function M.header()
  beans_mod.build_index()
  return { { "Spring Beans (" .. #beans_mod.beans .. ")", "SpringToolsHeader" } }
end

function M:load_items()
  beans_mod.build_index()
  local grouped = beans_mod.group_by_type()
  local type_order = { "controllers", "services", "repositories", "components", "configurations", "beans" }
  local type_labels = { controllers = "Controllers", services = "Services", repositories = "Repositories", components = "Components", configurations = "Configurations", beans = "Beans" }

  M.items = {}
  for _, t in ipairs(type_order) do
    if #grouped[t] > 0 then
      table.insert(M.items, { type = "header", label = type_labels[t] })
      for _, bean in ipairs(grouped[t]) do
        table.insert(M.items, { type = "bean", bean = bean })
      end
    end
  end
end

function M:render_item(item, selected)
  if item.type == "header" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsAccent"
    return { { "\u{25b8} " .. item.label, hl } }
  end
  local hl = selected and "SpringToolsSelected" or nil
  return { { "  " .. item.bean.name, hl } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "header" then
    local next = idx + 1
    while next <= #M.items do
      if M.items[next].type == "bean" then
        sidebar.selected = next
        sidebar.refresh()
        M:on_activate(next)
        return
      end
      next = next + 1
    end
    return
  end
  vim.cmd("edit " .. item.bean.file)
  vim.api.nvim_win_set_cursor(0, { item.bean.line, 0 })
  vim.cmd("normal! zz")
end

return M
