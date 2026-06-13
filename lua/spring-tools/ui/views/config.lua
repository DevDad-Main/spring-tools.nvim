local config_mod = require("spring-tools.config_explorer")
local project = require("spring-tools.project")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")
local sections = require("spring-tools.ui.sections").new("config")

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

local function get_top_key(key)
  local top = key:match("^([%w%-_]+)%.")
  return top or key
end

function M:load_items()
  config_mod.build_index(scan_dir())
  table.sort(config_mod.properties, function(a, b)
    if a.key == b.key then return false end
    local a_top = get_top_key(a.key)
    local b_top = get_top_key(b.key)
    if a_top ~= b_top then return a_top < b_top end
    return a.key < b.key
  end)

  local groups = {}
  for _, prop in ipairs(config_mod.properties) do
    local top = get_top_key(prop.key)
    if not groups[top] then groups[top] = {} end
    table.insert(groups[top], prop)
  end

  local ordered_tops = {}
  for top, _ in pairs(groups) do table.insert(ordered_tops, top) end
  table.sort(ordered_tops)

  M.items = {}
  for _, top in ipairs(ordered_tops) do
    local is_collapsed = sections:is_collapsed(top)
    table.insert(M.items, { type = "section", key = top, label = top .. ": (" .. #groups[top] .. " props)", collapsed = is_collapsed })
    if not is_collapsed then
      for _, prop in ipairs(groups[top]) do
        local sub_key = prop.key:sub(#top + 2)
        table.insert(M.items, { type = "prop", prop = prop, label = "    " .. sub_key .. " = " .. prop.value })
      end
    end
  end
end

function M:render_item(item, selected)
  if item.type == "section" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local hl = selected and "SpringToolsSelected" or "SpringToolsConfigSection"
    return { { "  " .. icon .. " " .. item.label, hl } }
  end
  local sub_key = item.prop.key:sub(#get_top_key(item.prop.key) + 2)
  local value = item.prop.value
  if #value > 40 then value = value:sub(1, 37) .. "..." end
  if selected then
    return { { "      " .. sub_key .. " = " .. value, "SpringToolsSelected" } }
  end
  return { {
    segments = {
      { "      " .. sub_key, "SpringToolsConfigKey" },
      { " = ", nil },
      { value, "SpringToolsConfigValue" },
    },
  } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "section" then
    sections:toggle(item.key)
    sidebar.refresh()
    return
  end
  if item.prop and item.prop.file then
    sidebar.open_in_main(item.prop.file)
  end
end

return M
