local M = {}

M.projects = {}
M.workspace_root = nil
M.selected_project = 1
M.active_panel = "dashboard"

M.callbacks = {}

function M.subscribe(event, callback)
  M.callbacks[event] = M.callbacks[event] or {}
  table.insert(M.callbacks[event], callback)
end

function M.emit(event, ...)
  for _, cb in ipairs(M.callbacks[event] or {}) do
    pcall(cb, ...)
  end
end

function M.set_projects(projects, workspace_root)
  M.projects = projects
  M.workspace_root = workspace_root
  if M.selected_project > #projects then
    M.selected_project = #projects > 0 and 1 or 0
  end
  M.emit("projects_changed", projects, workspace_root)
end

function M.get_projects()
  return M.projects
end

function M.get_workspace_root()
  return M.workspace_root
end

function M.get_selected_project()
  if #M.projects == 0 then return nil end
  return M.projects[M.selected_project]
end

function M.select_project(idx)
  if idx >= 1 and idx <= #M.projects then
    M.selected_project = idx
    M.emit("project_selected", M.projects[idx])
  end
end

function M.set_active_panel(panel)
  M.active_panel = panel
  M.emit("panel_changed", panel)
end

function M.get_active_panel()
  return M.active_panel
end

function M.reset()
  M.projects = {}
  M.workspace_root = nil
  M.selected_project = 1
  M.active_panel = "dashboard"
end

return M
