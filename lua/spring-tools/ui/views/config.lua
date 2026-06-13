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

  local file_groups = {}
  for _, prop in ipairs(config_mod.properties) do
    local src = prop.source or "application.properties"
    if not file_groups[src] then file_groups[src] = {} end
    table.insert(file_groups[src], prop)
  end

  local ordered_sources = {}
  for src, _ in pairs(file_groups) do
    table.insert(ordered_sources, src)
  end
  table.sort(ordered_sources)
  for i, src in ipairs(ordered_sources) do
    if src == "application.properties" then
      table.remove(ordered_sources, i)
      table.insert(ordered_sources, 1, src)
      break
    end
  end

  M.items = {}
  for _, src in ipairs(ordered_sources) do
    local props = file_groups[src]
    table.sort(props, function(a, b) return a.key < b.key end)

    local is_file_collapsed = sections:is_collapsed("file:" .. src)
    local file_label = src .. " (" .. #props .. " props)"
    table.insert(M.items, { type = "file_section", key = "file:" .. src, label = file_label, collapsed = is_file_collapsed })

    if not is_file_collapsed then
      local groups = {}
      for _, prop in ipairs(props) do
        local top = get_top_key(prop.key)
        if not groups[top] then groups[top] = {} end
        table.insert(groups[top], prop)
      end

      local ordered_tops = {}
      for top, _ in pairs(groups) do table.insert(ordered_tops, top) end
      table.sort(ordered_tops)

      for _, top in ipairs(ordered_tops) do
        local section_key = "file:" .. src .. "/" .. top
        local is_collapsed = sections:is_collapsed(section_key)
        table.insert(M.items, { type = "section", key = section_key, label = top .. ": (" .. #groups[top] .. " props)", collapsed = is_collapsed })
        if not is_collapsed then
          for _, prop in ipairs(groups[top]) do
            table.insert(M.items, { type = "prop", prop = prop, expanded = false })
          end
        end
      end
    end
  end
end

function M:render_item(item, selected)
  if item.type == "file_section" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local hl = selected and "SpringToolsSelected" or "SpringToolsConfigFile"
    return { { "  " .. icon .. " " .. item.label, hl } }
  end
  if item.type == "section" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local hl = selected and "SpringToolsSelected" or "SpringToolsConfigSection"
    return { { "    " .. icon .. " " .. item.label, hl } }
  end
  local sub_key = item.prop.key:sub(#get_top_key(item.prop.key) + 2)
  local value = item.prop.value
  local sidebar_width = require("spring-tools.config").options.sidebar.width
  local max_val = sidebar_width - 8 - #sub_key - 5
  if max_val < 10 then max_val = 10 end
  if not item.expanded and #value > max_val then
    value = value:sub(1, max_val - 3) .. "..."
  end
  local icon = item.expanded and "\u{25be}" or "\u{25b8}"
  if selected then
    return { { "        " .. icon .. " " .. sub_key .. " = " .. value, "SpringToolsSelected" } }
  end
  return { {
    segments = {
      { "        " .. icon .. " ", nil },
      { sub_key, "SpringToolsConfigKey" },
      { " = ", nil },
      { value, "SpringToolsConfigValue" },
    },
  } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "file_section" or item.type == "section" then
    sections:toggle(item.key)
    sidebar.refresh()
    return
  end
  item.expanded = not item.expanded
  sidebar.refresh()
end

return M