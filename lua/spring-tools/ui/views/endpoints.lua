local endpoints_mod = require("spring-tools.endpoints")
local sidebar = require("spring-tools.ui.sidebar")
local utils = require("spring-tools.utils")
local project = require("spring-tools.project")

local M = {}

M.title = "Endpoints"

M.items = {}

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

local method_colors = {
  GET = "SpringToolsRunning",
  POST = "SpringToolsAccent",
  PUT = "SpringToolsKey",
  PATCH = "SpringToolsDim",
  DELETE = "SpringToolsError",
}

function M.header()
  endpoints_mod.scan_endpoints(scan_dir())
  return { { "REST Endpoints (" .. #endpoints_mod.endpoints .. ")", "SpringToolsHeader" } }
end

function M:load_items()
  endpoints_mod.scan_endpoints(scan_dir())
  local order = { GET = 1, POST = 2, PUT = 3, DELETE = 4, PATCH = 5 }
  table.sort(endpoints_mod.endpoints, function(a, b)
    if a.method ~= b.method then return (order[a.method] or 99) < (order[b.method] or 99) end
    return a.path < b.path
  end)

  local grouped = {}
  for _, ep in ipairs(endpoints_mod.endpoints) do
    grouped[ep.method] = grouped[ep.method] or {}
    table.insert(grouped[ep.method], ep)
  end

  M.items = {}
  for _, method in ipairs({ "GET", "POST", "PUT", "DELETE", "PATCH" }) do
    local eps = grouped[method]
    if eps and #eps > 0 then
      table.insert(M.items, { type = "header", label = method .. "  (" .. #eps .. ")" })
      for _, ep in ipairs(eps) do
        table.insert(M.items, { type = "endpoint", endpoint = ep })
      end
    end
  end
end

function M:render_item(item, selected)
  if item.type == "header" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsAccent"
    return { { "  \u{25b8} " .. item.label, hl } }
  end
  local ep = item.endpoint
  if selected then
    return { { "      " .. ep.method .. "  " .. ep.path, "SpringToolsSelected" } }
  end
  local method_hl = method_colors[ep.method] or nil
  return { segments = {
    { "       " .. ep.method .. "  ", method_hl },
    { ep.path, nil },
  } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "header" then
    local next = idx + 1
    while next <= #M.items do
      if M.items[next].type == "endpoint" then
        sidebar.selected = next
        sidebar.refresh()
        M:on_activate(next)
        return
      end
      next = next + 1
    end
    return
  end
  local ep = item.endpoint
  local actions = {
    { label = "Jump to definition", fn = function()
      sidebar.open_in_main(ep.file, ep.line)
    end },
    { label = "Copy curl", fn = function()
      local curl = "curl -X " .. ep.method .. " http://localhost:8080" .. ep.path
      vim.fn.setreg("+", curl)
      utils.notify("Curl copied")
    end },
    { label = "Open in browser", fn = function()
      local url = "http://localhost:8080" .. ep.path
      if vim.fn.has("mac") == 1 then vim.fn.system({ "open", url })
      elseif vim.fn.has("unix") == 1 then vim.fn.system({ "xdg-open", url }) end
    end },
  }
  local sidebar_win = sidebar.win
  if sidebar_win and vim.api.nvim_win_is_valid(sidebar_win) then
    pcall(vim.api.nvim_set_current_win, sidebar_win)
  end
  local labels = vim.tbl_map(function(a) return a.label end, actions)
  local map = {}
  for _, a in ipairs(actions) do map[a.label] = a.fn end
  vim.ui.select(labels, {
    prompt = ep.method .. " " .. ep.path .. ":",
  }, function(choice)
    if choice and map[choice] then map[choice]() end
  end)
end

return M
