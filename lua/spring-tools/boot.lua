local utils = require("spring-tools.utils")
local commands = require("spring-tools.commands")

local M = {}

function M.dashboard()
  commands.open_sidebar("dashboard")
end

function M.refresh_dashboard()
  local sidebar = require("spring-tools.ui.sidebar")
  sidebar.refresh()
end

return M