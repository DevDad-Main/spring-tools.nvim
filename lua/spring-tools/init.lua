local config = require("spring-tools.config")
local commands = require("spring-tools.commands")
local utils = require("spring-tools.utils")

local M = {}

function M.setup(opts)
  config.setup(opts)

  utils.load_cache()

  commands.setup()
  commands.setup_keymaps()
  commands.setup_autocommands()
end

function M.get_config()
  return config.options
end

M.version = "0.1.0"

return M
