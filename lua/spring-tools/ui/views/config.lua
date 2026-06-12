local config_mod = require("spring-tools.config_explorer")
local project = require("spring-tools.project")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")

local M = {}

M.title = "Config"

M.items = {}

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

function M.header()
  config_mod.build_index(scan_dir())
  return { { "Config (" .. #config_mod.properties .. " props)", "SpringToolsHeader" } }
end

function M:load_items()
  config_mod.build_index(scan_dir())
  table.sort(config_mod.properties, function(a, b) return a.key < b.key end)
  M.items = {}
  for _, prop in ipairs(config_mod.properties) do
    table.insert(M.items, { type = "prop", prop = prop, label = prop.key .. " = " .. prop.value })
  end
end

function M:render_item(item, selected)
  local max_len = 44
  local label = item.label
  if #label > max_len then label = label:sub(1, max_len - 3) .. "..." end
  local hl = selected and "SpringToolsSelected" or nil
  return { { label, hl } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.prop and item.prop.file then
    sidebar.open_in_main(item.prop.file)
  end
end

return M
