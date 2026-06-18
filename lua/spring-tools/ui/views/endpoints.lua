local endpoints_mod = require("spring-tools.endpoints")
local actuator_mod = require("spring-tools.actuator")
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
  local total = 0
  if project.is_multi_project() then
    local n = 0
    for _, data in pairs(M._project_data or {}) do
      total = total + #data.rest
      n = n + 1
    end
    for _, g in ipairs(actuator_mod.endpoints) do
      total = total + #g.endpoints * n
    end
  else
    total = (endpoints_mod.endpoints and #endpoints_mod.endpoints or 0)
    for _, g in ipairs(actuator_mod.endpoints) do
      total = total + #g.endpoints
    end
  end
  return { { "Endpoints (" .. total .. ")", "SpringToolsHeader" } }
end

local function build_single_items()
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
  local rest_collapsed = sections:is_collapsed("rest")
  M.items[#M.items + 1] = { type = "section_header", section_key = "rest", label = "REST Endpoints  (" .. (#endpoints_mod.endpoints) .. ")", collapsed = rest_collapsed }
  if not rest_collapsed then
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

  local act_collapsed = sections:is_collapsed("actuator")
  M.items[#M.items + 1] = { type = "section_header", section_key = "actuator", label = "Actuator Endpoints  (" .. #actuator_mod.endpoints .. ")", collapsed = act_collapsed }
  if not act_collapsed then
    for _, g in ipairs(actuator_mod.endpoints) do
      local is_collapsed = sections:is_collapsed(g.group)
      M.items[#M.items + 1] = { type = "header", group = g.group, label = g.group .. "  (" .. #g.endpoints .. ")", collapsed = is_collapsed }
      if not is_collapsed then
        for _, ep in ipairs(g.endpoints) do
          M.items[#M.items + 1] = { type = "actuator_endpoint", path = ep.path, method = ep.method, description = ep.description, group = g.group }
        end
      end
    end
  end
end

local function build_multi_items(projs)
  M._project_data = {}
  M.items = {}

  -- Pre-scan all projects
  for _, proj in ipairs(projs) do
    if not M._project_data[proj.root] then
      if proj.is_virtual then
        M._project_data[proj.root] = { name = proj.name, rest = {} }
      else
        endpoints_mod.scan_endpoints(proj.root)
        local rest = vim.deepcopy(endpoints_mod.endpoints)
        table.sort(rest, function(a, b)
          local oa, ob = method_order[a.method] or 99, method_order[b.method] or 99
          if oa ~= ob then return oa < ob end
          return a.path < b.path
        end)
        M._project_data[proj.root] = { name = proj.name, rest = rest }
      end
    end
  end

  local function render_proj_tree(proj_list, indent)
    indent = indent or 0
    for _, proj in ipairs(proj_list) do
      local data = M._project_data[proj.root]
      if data then
      local psk = "proj:" .. proj.root
      local proj_collapsed = sections:is_collapsed(psk)
      M.items[#M.items + 1] = { type = "project_header", label = data.name, project_root = proj.root, section_key = psk, collapsed = proj_collapsed, _indent = indent }
      if not proj_collapsed then
        if #data.rest > 0 then
          local rest_collapsed = sections:is_collapsed("rest:" .. proj.root)
          M.items[#M.items + 1] = { type = "section_header", section_key = "rest:" .. proj.root, label = "REST Endpoints  (" .. #data.rest .. ")", collapsed = rest_collapsed }
          if not rest_collapsed then
            local counts = {}
            for _, ep in ipairs(data.rest) do counts[ep.method] = (counts[ep.method] or 0) + 1 end
            for _, method in ipairs(method_order) do
              if counts[method] and counts[method] > 0 then
                local is_collapsed = sections:is_collapsed(method .. ":" .. proj.root)
                M.items[#M.items + 1] = { type = "header", method = method, label = method .. "  (" .. counts[method] .. ")", collapsed = is_collapsed, section_key = method .. ":" .. proj.root }
                if not is_collapsed then
                  for _, ep in ipairs(data.rest) do
                    if ep.method == method then
                      M.items[#M.items + 1] = { type = "endpoint", endpoint = ep, method = ep.method, path = ep.path, project_root = proj.root }
                    end
                  end
                end
              end
            end
          end
        end

        if #data.rest > 0 then
          local act_collapsed = sections:is_collapsed("actuator:" .. proj.root)
          M.items[#M.items + 1] = { type = "section_header", section_key = "actuator:" .. proj.root, label = "Actuator Endpoints  (" .. #actuator_mod.endpoints .. ")", collapsed = act_collapsed }
          if not act_collapsed then
            for _, g in ipairs(actuator_mod.endpoints) do
              local is_collapsed = sections:is_collapsed(g.group .. ":" .. proj.root)
              M.items[#M.items + 1] = { type = "header", group = g.group, label = g.group .. "  (" .. #g.endpoints .. ")", collapsed = is_collapsed, section_key = g.group .. ":" .. proj.root }
              if not is_collapsed then
                for _, ep in ipairs(g.endpoints) do
                  M.items[#M.items + 1] = { type = "actuator_endpoint", path = ep.path, method = ep.method, description = ep.description, group = g.group, project_root = proj.root }
                end
              end
            end
          end
        end

        if proj.children and #proj.children > 0 then
          render_proj_tree(proj.children, indent + 1)
        end
      end
      end
    end
  end

  -- Always rebuild parent-child tree from path prefix (ignore detect_projects)
  for _, proj in ipairs(projs) do
    proj.children = {}
  end
  local is_child = {}
  for _, proj in ipairs(projs) do
    for _, parent in ipairs(projs) do
      if proj.root ~= parent.root
        and proj.root:sub(1, #parent.root) == parent.root
        and proj.root:sub(#parent.root + 1, #parent.root + 1) == "/" then
        parent.children[#parent.children + 1] = proj
        is_child[proj.root] = true
        break
      end
    end
  end
  local top_level = {}
  for _, proj in ipairs(projs) do
    if not is_child[proj.root] then table.insert(top_level, proj) end
    if #proj.children == 0 then proj.children = nil end
  end
  render_proj_tree(top_level)
end

function M:load_items()
  local projs = project.get_workspace_projects()
  local multi = project.is_multi_project()

  if not multi then
    if #endpoints_mod.endpoints == 0 then
      M.items = { { type = "loading", label = "Indexing endpoints..." } }
      vim.defer_fn(function()
        endpoints_mod.scan_endpoints(scan_dir())
        sidebar.refresh()
      end, 1)
      return
    end
    build_single_items()
  else
    build_multi_items(projs)
  end
end

function M:render_item(item, selected)
  if item.type == "loading" then
    local hl = selected and "SpringToolsSelected" or "SpringToolsDim"
    return { { "  " .. item.label, hl } }
  end
  if item.type == "project_header" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local pad = item._indent and string.rep("  ", item._indent) or ""
    local hl = selected and "SpringToolsSelected" or "SpringToolsSectionHeader"
    return { { pad .. icon .. " " .. item.label, hl } }
  end
  if item.type == "section_header" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local pfx = project.is_multi_project() and "    " or "  "
    local hl = selected and "SpringToolsSelected" or "SpringToolsSectionHeader"
    return { { pfx .. icon .. " " .. item.label, hl } }
  end
  if item.type == "header" then
    local icon = item.collapsed and "\u{25b8}" or "\u{25be}"
    local pfx = project.is_multi_project() and "      " or "    "
    local hl = selected and "SpringToolsSelected" or "SpringToolsMethodHeader"
    return { { pfx .. icon .. " " .. item.label, hl } }
  end
  local method = item.method
  local path = item.endpoint and item.endpoint.path or item.path
  if selected then
    local pfx = project.is_multi_project() and "          " or "        "
    return { { pfx .. method .. "  " .. path, "SpringToolsSelected" } }
  end
  local pfx = project.is_multi_project() and "          " or "        "
  return { { segments = {
    { pfx .. method .. "  ", method_colors[method] or "SpringToolsDim" },
    { path, nil },
  } } }
end

function M:on_activate(idx)
  local item = M.items[idx]
  if not item then return end
  if item.type == "project_header" then
    sections:toggle(item.section_key)
    sidebar.refresh()
    return
  end
  if item.type == "section_header" then
    sections:toggle(item.section_key)
    sidebar.refresh()
    return
  end
  if item.type == "header" then
    sections:toggle(item.section_key or item.method or item.group)
    sidebar.refresh()
    return
  end
  if item.type == "endpoint" then
    local ep = item.endpoint
    local actions = {
      { label = "Jump to definition", fn = function()
        sidebar.open_in_main(ep.file, ep.line)
      end },
      { label = "Copy curl", fn = function()
        local port = M._get_port(item.project_root)
        local curl = "curl -X " .. ep.method .. " http://localhost:" .. port .. ep.path
        vim.fn.setreg("+", curl)
        utils.notify("Curl copied")
      end },
      { label = "Send request", fn = function()
        M._resolve_and_send(item)
      end },
      { label = "Open in browser", fn = function()
        local port = M._get_port(item.project_root)
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
  elseif item.type == "actuator_endpoint" then
    local actions = {
      { label = "Send request", fn = function()
        M._resolve_and_send(item)
      end },
      { label = "Copy curl", fn = function()
        local port = M._get_port(item.project_root)
        local curl = "curl -X " .. item.method .. " http://localhost:" .. port .. item.path
        vim.fn.setreg("+", curl)
        utils.notify("Curl copied")
      end },
      { label = "Open in browser", fn = function()
        local port = M._get_port(item.project_root)
        local url = "http://localhost:" .. port .. item.path
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
      prompt = item.method .. " " .. item.path .. ":",
    }, function(choice)
      if choice and map[choice] then map[choice]() end
    end)
  end
end

function M._get_port(project_root)
  if project_root then
    for _, proj in ipairs(project.get_workspace_projects()) do
      if proj.root == project_root then
        local be = project.get_backend_for_project(proj)
        if be and be.get_port then
          local p = be:get_port(proj)
          if p and p ~= "" then return p end
        end
      end
    end
  else
    local proj = project.get_active_project()
    if proj then
      local be = project.get_backend_for_project(proj)
      if be and be.get_port then
        local p = be:get_port(proj)
        if p and p ~= "" then return p end
      end
    end
  end
  return "8080"
end

function M:test_endpoint(idx)
  local item = M.items[idx]
  if not item or (item.type ~= "endpoint" and item.type ~= "actuator_endpoint") then return end
  M._resolve_and_send(item)
end

function M._resolve_and_send(ep)
  local path = ep.path
  local vars = {}
  for var in path:gmatch("{([^}]+)}") do
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

function M:fold_all(open)
  if open then
    sections._expand_all = true
    sidebar.refresh()
    vim.defer_fn(function() sections._expand_all = false end, 50)
  else
    sections:collapse_all()
    sidebar.refresh()
  end
end

return M
