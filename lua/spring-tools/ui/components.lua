local M = {}

M.colors = {
  header = "SpringToolsHeader",
  selected = "SpringToolsSelected",
  running = "SpringToolsRunning",
  stopped = "SpringToolsStopped",
  dim = "SpringToolsDim",
  accent = "SpringToolsAccent",
  border = "SpringToolsBorder",
  key = "SpringToolsKey",
  value = "SpringToolsValue",
}

function M.setup_highlights()
  local hl = vim.api.nvim_set_hl
  local get = function(name) return vim.api.nvim_get_hl(0, { name = name }) end
  local config = require("spring-tools.config")
  local overrides = config.options.highlights or {}

  local norm = get("Normal")
  local bg = norm.bg or (vim.o.background == "dark" and "#1e1e2e" or "#fafafa")
  local fg = norm.fg or (vim.o.background == "dark" and "#cdd6f4" or "#1e1e2e")
  local sel = get("Visual")
  local sel_bg = sel.bg or (vim.o.background == "dark" and "#45475a" or "#dce0e8")
  local dim = get("Comment")
  local dim_fg = dim.fg or (vim.o.background == "dark" and "#6c7086" or "#9ca0b0")
  local title = get("Title")
  local title_fg = title.fg or (vim.o.background == "dark" and "#89b4fa" or "#1e66f5")
  local err = get("ErrorMsg")
  local err_fg = err.fg or (vim.o.background == "dark" and "#f38ba8" or "#d20f39")
  local special = get("Special")
  local special_fg = special.fg or (vim.o.background == "dark" and "#f9e2af" or "#df8e1d")
  local ok = get("DiagnosticOk")
  local ok_fg = ok.fg or (vim.o.background == "dark" and "#a6e3a1" or "#40a02b")

  local specs = {
    SpringToolsHeader = { fg = title_fg, bold = true, bg = bg },
    SpringToolsSelected = { fg = fg, bg = sel_bg, bold = true },
    SpringToolsRunning = { fg = ok_fg, bg = bg },
    SpringToolsStopped = { fg = err_fg, bg = bg },
    SpringToolsDim = { fg = dim_fg, bg = bg },
    SpringToolsAccent = { fg = special_fg, bold = true, bg = bg },
    SpringToolsError = { fg = err_fg, bold = true, bg = bg },
    SpringToolsBorder = { fg = title_fg, bg = bg },
    SpringToolsKey = { fg = special_fg, bg = bg },
    SpringToolsValue = { fg = fg, bg = bg },
    SpringToolsSectionHeader = { fg = title_fg, bold = true, bg = bg },
    SpringToolsMethodHeader = { fg = special_fg, bold = true, bg = bg },
    SpringToolsBeanHeader = { fg = special_fg, bold = true, bg = bg },
    SpringToolsTestRunAll = { fg = special_fg, bold = true, bg = bg },
    SpringToolsTestClass = { fg = special_fg, bold = true, bg = bg },
    SpringToolsTestMethod = { fg = dim_fg, bg = bg },
    SpringToolsBeanName = { fg = fg, bg = bg },
    SpringToolsBeanMethod = { fg = dim_fg, bg = bg },
    SpringToolsGet = { fg = ok_fg, bg = bg },
    SpringToolsPost = { fg = ok_fg, bg = bg },
    SpringToolsPut = { fg = ok_fg, bg = bg },
    SpringToolsPatch = { fg = ok_fg, bg = bg },
    SpringToolsDelete = { fg = ok_fg, bg = bg },
    SpringToolsConfigSection = { fg = special_fg, bold = true, bg = bg },
    SpringToolsConfigFile = { fg = title_fg, bold = true, bg = bg },
    SpringToolsParentHeader = { fg = title_fg, bold = true, bg = bg },
    SpringToolsConfigKey = { fg = special_fg, bg = bg },
    SpringToolsConfigValue = { fg = fg, bg = bg },
    SpringToolsDashboardProject = { fg = fg, bold = true, bg = bg },
    SpringToolsDashboardStatus = { fg = dim_fg, bg = bg },
    SpringToolsDashboardBuildType = { fg = dim_fg, bg = bg },
    SpringToolsLogError = { fg = err_fg, bold = true, bg = bg },
    SpringToolsLogWarn = { fg = special_fg, bg = bg },
    SpringToolsLogInfo = { fg = ok_fg, bg = bg },
    SpringToolsLogDebug = { fg = dim_fg, bg = bg },
    SpringToolsLogTrace = { fg = dim_fg, bg = bg },
  }

  for name, spec in pairs(specs) do
    local override = overrides[name]
    if override and override.link then
      hl(0, name, { link = override.link })
    else
      hl(0, name, override and vim.tbl_deep_extend("force", spec, override) or spec)
    end
  end
end

function M.render_header(buf, title, subtitle)
  local lines = {
    { "  " .. title, "SpringToolsHeader" },
  }
  if subtitle then
    table.insert(lines, { "  " .. subtitle, "SpringToolsDim" })
  end
  table.insert(lines, { "  " .. string.rep("─", 60), "SpringToolsDim" })
  return lines
end

function M.render_footer(buf, actions)
  local lines = {}
  table.insert(lines, { "  " .. string.rep("─", 60), "SpringToolsDim" })
  local action_str = ""
  for key, desc in pairs(actions) do
    action_str = action_str .. string.format("  %s%s%s %s  ", "%#SpringToolsKey#", key, "%*", desc)
  end
  table.insert(lines, { action_str, "" })
  return lines
end

function M.render_list(items, selected_idx, render_item)
  local lines = {}
  for i, item in ipairs(items) do
    local is_selected = i == selected_idx
    local item_lines = render_item(item, is_selected, i)
    for _, l in ipairs(item_lines) do
      table.insert(lines, l)
    end
  end
  return lines
end

function M.apply_highlights(buf, ns, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for line_idx, line_data in ipairs(lines) do
    if type(line_data) == "table" then
      local text = line_data[1]
      local hl_group = line_data[2]
      if hl_group then
        vim.api.nvim_buf_set_extmark(buf, ns, line_idx - 1, 0, {
          end_col = #text,
          hl_group = hl_group,
          priority = 100,
        })
      end
    end
  end
end

function M.set_keymap(buf, key, callback, opts)
  opts = vim.tbl_extend("force", { silent = true, nowait = true, expr = false }, opts or {})
  vim.keymap.set("n", key, callback, vim.tbl_extend("force", opts, { buffer = buf, nowait = true }))
end

return M