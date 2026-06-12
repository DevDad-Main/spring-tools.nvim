local config = require("spring-tools.config")
local commands = require("spring-tools.commands")
local utils = require("spring-tools.utils")
local components = require("spring-tools.ui.components")

local M = {}

function M.setup(opts)
  config.setup(opts)
  utils.load_cache()
  utils.cache.data = {}
  components.setup_highlights()
  commands.setup()
  commands.setup_keymaps()
  commands.setup_autocommands()
end

function M.get_config()
  return config.options
end

function M.open()
  commands.open_sidebar("dashboard")
end

M.version = "0.3.0"

return M