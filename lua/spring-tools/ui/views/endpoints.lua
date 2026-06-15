local endpoints_mod = require("spring-tools.endpoints")
local sidebar = require("spring-tools.ui.sidebar")
local utils = require("spring-tools.utils")
local project = require("spring-tools.project")
local sections = require("spring-tools.ui.sections").new("endpoints")
local http = require("spring-tools.http_client")

local M = {}

M.title = "Endpoints"

M.items = {}

local function scan_dir()
  local proj = project.get_active_project()
  return proj and proj.root or vim.fn.getcwd()
end

local method_colors = {
  GET = "SpringToolsGet",
  POST = "SpringToolsPost",
  PUT = "SpringToolsPut",
  PATCH = "SpringToolsPatch",
  DELETE = "SpringToolsDelete",
}

local method_order = { "GET", "POST", "PUT", "DELETE", "PATCH" }

function M.header()
  endpoints_mod.scan_endpoints(scan_dir())
  return { { "REST Endpoints (" .. #endpoints_mod.endpoints .. ")", "SpringToolsHeader" } }
end

function M:load_items()
  endpoints_mod.scan_endpoints(scan_dir())
  table.sort(endpoints_mod.endpoints, function(a, b)
    local oa, ob = method_order[a.method] or 99, method_order[b.method] or 99
    if oa ~= ob then return oa < ob end
    return a.path < b.path
  end)

  local counts = {}
  for _, ep in ipairs(endpoints_mod.endpoints) do
    counts[ep.method] = (counts[ep.method] or 0) + 1
  end

  M.items = {}
  for _, method in ipairs(method_order) do
    if counts[method] and counts[method] > 0 then
      local is_collapsed = sections:is_collapsed(method)
      M.items[#M.items + 1] = { type = "header", method = method, label = method .. "  (" .. counts[method] .. ")", collapsed = is_collapsed }
      if not is_collapsed then
        for _, ep in ipairs(endpoints_mod.endpoints) do
          if ep.method == method then
            M.items[#M.items + 1] = { type = "endpoint", endpoint = ep }
          end
        end
      end
    end
  end
end

function M:render_item(item, selected)
  if item.type == "header" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local hl = selected and "SpringToolsSelected" or "SpringToolsMethodHeader"
    return { { "  " .. icon .. " " .. item.label, hl } }
  end
  local ep = item.endpoint
  local path = ep.path
  if selected then
    return { { "      " .. ep.method .. "  " .. path, "SpringToolsSelected" } }
  end
  return { { segments = {
    { "      " .. ep.method .. "  ", method_colors[ep.method] },
    { path, nil },
  } } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "header" then
    sections:toggle(item.method)
    sidebar.refresh()
    return
  end
  local ep = item.endpoint
  local actions = {
    { label = "Jump to definition", fn = function()
      sidebar.open_in_main(ep.file, ep.line)
    end },
    { label = "Copy curl", fn = function()
      local port = M._get_port()
      local curl = "curl -X " .. ep.method .. " http://localhost:" .. port .. ep.path
      vim.fn.setreg("+", curl)
      utils.notify("Curl copied")
    end },
    { label = "Send request", fn = function()
      M._resolve_and_send(ep)
    end },
    { label = "Open in browser", fn = function()
      local port = M._get_port()
      local url = "http://localhost:" .. port .. ep.path
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

function M._get_port()
  local proj = project.get_active_project()
  if proj then
    local be = project.get_backend_for_project(proj)
    if be and be.get_port then
      local p = be:get_port(proj)
      if p and p ~= "" then return p end
    end
  end
  return "8080"
end

function M:test_endpoint(idx)
  local item = M.items[idx]
  if not item or item.type ~= "endpoint" then return end
  M._resolve_and_send(item.endpoint)
end

function M._resolve_and_send(ep)
  local path = ep.path
  local vars = {}
  for var in path:gmatch("{(%w+)}") do
    vars[#vars + 1] = var
  end

  local function show_input(resolved_path)
    http._show_curl_input(ep, "", function(input)
      http.send(ep, input or "", resolved_path)
    end, resolved_path)
  end

  if #vars > 0 then
    local function ask_var(i)
      if i > #vars then
        show_input(path)
        return
      end
      local var = vars[i]
      http._show_prompt("{" .. var .. "} value", function(value)
        if not value or value == "" then return end
        path = path:gsub("{" .. var .. "}", value, 1)
        ask_var(i + 1)
      end)
    end
    ask_var(1)
  else
    show_input(path)
  end
end

return M
