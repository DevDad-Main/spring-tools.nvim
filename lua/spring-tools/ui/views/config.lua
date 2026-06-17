local config_mod = require("spring-tools.config_explorer")
local project = require("spring-tools.project")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")
local sections = require("spring-tools.ui.sections").new("config")

local M = {}

M.title = "Config"

M.items = {}
M.expanded_props = {}

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

function M.header()
  local count = 0
  if project.is_multi_project() and M._project_data then
    for _, data in pairs(M._project_data) do
      count = count + #data.properties
    end
  else
    config_mod.build_index(scan_dir())
    count = #config_mod.properties
  end
  return { { "Config (" .. count .. " props)", "SpringToolsHeader" } }
end

local function get_top_key(key)
  local top = key:match("^([%w%-_]+)%.")
  return top or key
end

local function build_items_for_properties(props, source_prefix)
  local items = {}
  local file_groups = {}
  for _, prop in ipairs(props) do
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

  for _, src in ipairs(ordered_sources) do
    local sprops = file_groups[src]
    table.sort(sprops, function(a, b) return a.key < b.key end)

    local file_key = (source_prefix or "") .. "file:" .. src
    local is_file_collapsed = sections:is_collapsed(file_key)
    local file_label = src .. " (" .. #sprops .. " props)"
    table.insert(items, { type = "file_section", key = file_key, label = file_label, collapsed = is_file_collapsed })

    if not is_file_collapsed then
      local groups = {}
      for _, prop in ipairs(sprops) do
        local top = get_top_key(prop.key)
        if not groups[top] then groups[top] = {} end
        table.insert(groups[top], prop)
      end

      local ordered_tops = {}
      for top, _ in pairs(groups) do table.insert(ordered_tops, top) end
      table.sort(ordered_tops)

      for _, top in ipairs(ordered_tops) do
        local section_key = (source_prefix or "") .. "file:" .. src .. "/" .. top
        local is_collapsed = sections:is_collapsed(section_key)
        table.insert(items, { type = "section", key = section_key, label = top .. ": (" .. #groups[top] .. " props)", collapsed = is_collapsed })
        if not is_collapsed then
          for _, prop in ipairs(groups[top]) do
            table.insert(items, { type = "prop", prop = prop, expanded = M.expanded_props[prop.key] or false })
          end
        end
      end
    end
  end
  return items
end

function M:load_items()
  local multi = project.is_multi_project()

  M.items = {}

  if not multi then
    config_mod.build_index(scan_dir())
    local items = build_items_for_properties(config_mod.properties)
    for _, item in ipairs(items) do
      table.insert(M.items, item)
    end
  else
    local projs = project.get_workspace_projects()
    M._project_data = {}

    for _, proj in ipairs(projs) do
      if not M._project_data[proj.root] then
        config_mod.build_index(proj.root)
        M._project_data[proj.root] = { name = proj.name, properties = vim.deepcopy(config_mod.properties) }
      end
    end

    local function render_proj_tree(proj_list, indent)
      indent = indent or 0
      for _, proj in ipairs(proj_list) do
        local data = M._project_data[proj.root]
        if not data then
          config_mod.build_index(proj.root)
          data = { name = proj.name, properties = vim.deepcopy(config_mod.properties) }
          M._project_data[proj.root] = data
        end
        local psk = "proj:" .. proj.root
        local proj_collapsed = sections:is_collapsed(psk)
        M.items[#M.items + 1] = { type = "project_header", label = data.name, project_root = proj.root, section_key = psk, collapsed = proj_collapsed }
        if not proj_collapsed then
          local prefix = proj.root .. ":"
          local items = build_items_for_properties(data.properties, prefix)
          for _, item in ipairs(items) do
            table.insert(M.items, item)
          end
        end
        if proj.children and #proj.children > 0 then
          render_proj_tree(proj.children, indent + 1)
        end
      end
    end

    local top_level = {}
    for _, proj in ipairs(projs) do
      if proj.is_top_level == nil or proj.is_top_level then table.insert(top_level, proj) end
    end
    render_proj_tree(top_level)
  end
end

function M:render_item(item, selected)
  local multi = project.is_multi_project()
  if item.type == "project_header" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local pad = item._indent and string.rep("  ", item._indent) or ""
    local hl = selected and "SpringToolsSelected" or "SpringToolsSectionHeader"
    return { { pad .. icon .. " " .. item.label, hl } }
  end
  if item.type == "file_section" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local pfx = multi and "    " or "  "
    local hl = selected and "SpringToolsSelected" or "SpringToolsConfigFile"
    return { { pfx .. icon .. " " .. item.label, hl } }
  end
  if item.type == "section" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local pfx = multi and "      " or "    "
    local hl = selected and "SpringToolsSelected" or "SpringToolsConfigSection"
    return { { pfx .. icon .. " " .. item.label, hl } }
  end
  local sub_key = item.prop.key:sub(#get_top_key(item.prop.key) + 2)
  local value = item.prop.value
  local key_pfx = multi and "          " or "        "
  local val_pfx = multi and "            " or "          "
  if item.expanded then
    if selected then
      return {
        { key_pfx .. sub_key .. " =", "SpringToolsSelected" },
        { val_pfx .. value, "SpringToolsSelected" },
      }
    end
    return {
      { segments = {
        { key_pfx .. sub_key, "SpringToolsConfigKey" },
        { " =", nil },
      } },
      { segments = {
        { val_pfx, nil },
        { value, "SpringToolsConfigValue" },
      } },
    }
  end
  local sidebar_width = require("spring-tools.config").options.sidebar.width
  local indent = multi and 12 or 8
  local full = sub_key .. " = " .. value
  local max = sidebar_width - indent - 1
  if #full > max then
    local overflow = #full - max
    local keep = math.max(3, #value - overflow - 3)
    value = value:sub(1, keep) .. "..."
  end
  if selected then
    return { { key_pfx .. sub_key .. " = " .. value, "SpringToolsSelected" } }
  end
  return { {
    segments = {
      { key_pfx .. sub_key, "SpringToolsConfigKey" },
      { " = ", nil },
      { value, "SpringToolsConfigValue" },
    },
  } }
end

function M:toggle_preview(idx)
  local item = M.items[idx]
  if not item or item.type ~= "prop" then return end
  item.expanded = not item.expanded
  M.expanded_props[item.prop.key] = item.expanded
  sidebar.refresh()
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "project_header" then
    sections:toggle(item.section_key)
    sidebar.refresh()
    return
  end
  if item.type == "file_section" or item.type == "section" then
    sections:toggle(item.key)
    sidebar.refresh()
    return
  end
  if item.prop and item.prop.file then
    sidebar.open_in_main(item.prop.file, item.prop.line)
  end
end

return M
