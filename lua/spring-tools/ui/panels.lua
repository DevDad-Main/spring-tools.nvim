local ui = require("spring-tools.ui")
local components = require("spring-tools.ui.components")
local state = require("spring-tools.core.state")

local M = {}

M.panels = {}
M.current_panel = nil
M.ns = vim.api.nvim_create_namespace("spring_tools_panels")

local Panel = {}
Panel.__index = Panel

function Panel:new(opts)
  opts = opts or {}
  local o = {
    name = opts.name,
    title = opts.title,
    render_fn = opts.render,
    on_mount = opts.on_mount,
    on_unmount = opts.on_unmount,
    keymaps = opts.keymaps or {},
    buf = nil,
    win = nil,
  }
  setmetatable(o, self)
  return o
end

function Panel:mount(buf, win)
  self.buf = buf
  self.win = win
  if self.on_mount then self:on_mount() end
  self:draw()
end

function Panel:unmount()
  if self.on_unmount then self:on_unmount() end
  self.buf = nil
  self.win = nil
end

function Panel:draw()
  if not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then return end
  if self.render_fn then
    local lines = self.render_fn(self)
    ui.set_lines(self.buf, lines)
    if #lines > 0 then
      components.apply_highlights(self.buf, M.ns, lines)
    end
  end
  self:bind_keymaps()
end

function Panel:bind_keymaps()
  if not self.buf or not vim.api.nvim_buf_is_valid(self.buf) then return end
  for key, action in pairs(self.keymaps) do
    components.set_keymap(self.buf, key, action)
  end
end

function Panel:refresh()
  self:draw()
end

M.Panel = Panel

function M.create_panel(opts)
  return Panel:new(opts)
end

function M.register_panel(panel)
  M.panels[panel.name] = panel
end

function M.get_panel(name)
  return M.panels[name]
end

function M.find_existing_window(name)
  local buf_name = "spring.tools." .. name
  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win_id)
    local bname = vim.api.nvim_buf_get_name(buf)
    if bname:find(buf_name, 1, true) and vim.api.nvim_win_is_valid(win_id) then
      return buf, win_id
    end
  end
  return nil, nil
end

function M.open_panel(name, opts)
  opts = opts or {}
  local panel = M.panels[name]
  if not panel then return end

  local existing_buf, existing_win = M.find_existing_window(name)
  if existing_win and vim.api.nvim_win_is_valid(existing_win) then
    pcall(vim.api.nvim_set_current_win, existing_win)
    panel.buf = existing_buf
    panel.win = existing_win
    panel:refresh()
    M.current_panel = panel
    state.set_active_panel(name)
    return panel
  end

  if M.current_panel and M.current_panel ~= panel then
    if M.current_panel.win and vim.api.nvim_win_is_valid(M.current_panel.win) then
      pcall(vim.api.nvim_win_close, M.current_panel.win, true)
    end
    M.current_panel:unmount()
  end

  local buf, win = ui.create_float_win({
    fullscreen = opts.fullscreen ~= false,
    title = " " .. panel.title .. " ",
    border = "double",
    name = "spring.tools." .. name,
  })

  panel:mount(buf, win)
  M.current_panel = panel
  state.set_active_panel(name)
  M.setup_global_keymaps(buf)
  return panel
end

function M.close_current()
  if M.current_panel then
    if M.current_panel.win and vim.api.nvim_win_is_valid(M.current_panel.win) then
      pcall(vim.api.nvim_win_close, M.current_panel.win, true)
    end
    M.current_panel:unmount()
    M.current_panel = nil
  end
  ui.close_dashboard()
end

function M.refresh_current()
  if M.current_panel then
    M.current_panel:refresh()
  end
end

function M.setup_global_keymaps(buf)
  components.set_keymap(buf, "q", function() M.close_current() end)
  components.set_keymap(buf, "R", function() M.refresh_current() end)
  components.set_keymap(buf, "1", function() M.open_panel("dashboard") end)
  components.set_keymap(buf, "2", function() M.open_panel("beans") end)
  components.set_keymap(buf, "3", function() M.open_panel("endpoints") end)
  components.set_keymap(buf, "4", function() M.open_panel("tests") end)
  components.set_keymap(buf, "5", function() M.open_panel("config") end)
end

return M