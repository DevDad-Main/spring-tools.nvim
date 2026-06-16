local tests_mod = require("spring-tools.tests")
local project = require("spring-tools.project")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")
local sections = require("spring-tools.ui.sections").new("tests")

local M = {}

M.title = "Tests"

M.items = {}
M._test_classes = nil

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

function M.header()
  local count = 0
  for _, item in ipairs(M.items) do
    if item.type == "class" then count = count + 1 end
  end
  return { { "Test Explorer (" .. count .. " classes)", "SpringToolsHeader" } }
end

function M:load_items()
  if #M.items == 0 and not M._test_classes then
    M.items = { { type = "loading", label = "Indexing tests..." } }
    vim.defer_fn(function()
      M._test_classes = tests_mod.find_test_methods(scan_dir())
      sidebar.refresh()
    end, 1)
    return
  end
  M.items = {}
  table.insert(M.items, { type = "all", label = "Run all tests" })
  for _, test in ipairs(M._test_classes) do
    local is_collapsed = sections:is_collapsed(test.class)
    M.items[#M.items + 1] = { type = "class", test = test, label = test.class, section_key = test.class, collapsed = is_collapsed }
    if not is_collapsed then
      for _, method in ipairs(test.methods) do
        M.items[#M.items + 1] = { type = "method", test = test, method = method, label = method.name }
      end
    end
  end
end

function M:render_item(item, selected)
  if item.type == "loading" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsDim"
    return { { "  " .. item.label, hl } }
  end
  if item.type == "all" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsTestRunAll"
    return { { "  " .. "\u{25b6}" .. " " .. item.label, hl } }
  end
  if item.type == "class" then
    local cr = tests_mod.class_results and tests_mod.class_results[item.test.class]
    local icon
    if cr then
      icon = cr.failed > 0 and "\u{2717}" or "\u{2713}"
    else
      icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    end
    local hl = selected and "SpringToolsSelected" or "SpringToolsTestClass"
    return { { "  " .. icon .. " " .. item.label, hl } }
  end
  local hl = selected and "SpringToolsSelected" or "SpringToolsTestMethod"
  local mr = tests_mod.method_results
  local status_icon = (mr and mr[item.test.class] and mr[item.test.class][item.method.name]) and (mr[item.test.class][item.method.name] == "failed" and "\u{2717}" or "\u{2713}") or "\u{22a1}"
  return { { "      " .. status_icon .. " " .. item.label, hl } }
end

function M:run_test(cmd)
  local ui = require("spring-tools.ui")
  local output_lines = {}
  output.show({ "Running tests..." }, "Test Output")
  ui.start_background_job(cmd, nil, {
    on_stdout = function(data)
      if data then
        for _, l in ipairs(data) do output.append(l) end
        vim.schedule(function()
          if output.buf and vim.api.nvim_buf_is_valid(output.buf) then
            local lc = vim.api.nvim_buf_line_count(output.buf)
            if lc > 0 then
              pcall(vim.api.nvim_win_set_cursor, output.win, {lc, 0})
            end
          end
        end)
      end
    end,
    on_stderr = function(data)
      if data then for _, l in ipairs(data) do output.append(l) end end
    end,
    on_exit = function(exit_code, all_data)
      tests_mod.handle_test_results(all_data, exit_code)
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

  if item.type == "class" then
    sections:toggle(item.section_key)
    sidebar.refresh()
    return
  end

  local cmd
  if item.type == "all" then
    cmd = be:get_build_command(proj)
    if cmd then table.insert(cmd, "test") end
  elseif item.type == "method" then
    cmd = be:get_test_command(proj, item.test.full_class, item.method.name)
  end
  if cmd then M:run_test(cmd) end
end

return M
