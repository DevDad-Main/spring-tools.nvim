local tests_mod = require("spring-tools.tests")
local project = require("spring-tools.project")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")

local M = {}

M.title = "Tests"

M.items = {}

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

function M.header()
  local classes = tests_mod.find_test_methods(scan_dir())
  return { { "Test Explorer (" .. #classes .. " classes)", "SpringToolsHeader" } }
end

function M:load_items()
  local test_classes = tests_mod.find_test_methods(scan_dir())
  M.items = {}
  table.insert(M.items, { type = "all", label = "Run all tests" })
  for _, test in ipairs(test_classes) do
    table.insert(M.items, { type = "class", test = test, label = test.class })
    for _, method in ipairs(test.methods) do
      table.insert(M.items, { type = "method", test = test, method = method, label = method.name })
    end
  end
end

function M:render_item(item, selected)
  local hl, prefix
  if item.type == "all" then
    hl = selected and "SpringToolsSelected" or "SpringToolsAccent"
    prefix = "\u{25b6} "
  elseif item.type == "class" then
    hl = selected and "SpringToolsSelected" or "SpringToolsAccent"
    prefix = "\u{25b8} "
  else
    hl = selected and "SpringToolsSelected" or nil
    prefix = "  \u{22a1} "
  end
  return { { prefix .. item.label, hl } }
end

function M:run_test(cmd)
  local ui = require("spring-tools.ui")
  local output_lines = {}
  output.show({ "Running tests..." }, "Test Output")
  ui.start_background_job(cmd, nil, {
    on_stdout = function(data)
      if data then
        for _, l in ipairs(data) do output.append(l) end
        vim.schedule(function() vim.api.nvim_win_set_cursor(output.win, {-1, 0}) end)
      end
    end,
    on_stderr = function(data)
      if data then for _, l in ipairs(data) do output.append(l) end end
    end,
  })
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  local proj = project.get_active_project()
  if not proj then utils.notify("No project found", vim.log.levels.WARN) return end
  local be = project.get_backend_for_project(proj)
  if not be then return end

  local cmd
  if item.type == "all" then
    cmd = be:get_build_command(proj)
    if cmd then table.insert(cmd, "test") end
  elseif item.type == "class" then
    cmd = be:get_test_command(proj, item.test.full_class, nil)
  elseif item.type == "method" then
    cmd = be:get_test_command(proj, item.test.full_class, item.method.name)
  end
  if cmd then M:run_test(cmd) end
end

return M
