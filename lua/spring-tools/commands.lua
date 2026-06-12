local config = require("spring-tools.config")
local utils = require("spring-tools.utils")

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("SpringBoot", function()
    require("spring-tools.boot").dashboard()
  end, { desc = "Open Spring Boot Dashboard" })

  vim.api.nvim_create_user_command("SpringBeans", function()
    require("spring-tools.beans").explore()
  end, { desc = "Open Spring Bean Explorer" })

  vim.api.nvim_create_user_command("SpringEndpoints", function()
    require("spring-tools.endpoints").explore()
  end, { desc = "Open REST Endpoint Explorer" })

  vim.api.nvim_create_user_command("SpringTest", function()
    require("spring-tools.tests").test_explorer()
  end, { desc = "Open Java Test Runner" })

  vim.api.nvim_create_user_command("SpringConfig", function()
    require("spring-tools.config_explorer").explore()
  end, { desc = "Open Spring Configuration Explorer" })

  vim.api.nvim_create_user_command("SpringRefresh", function()
    require("spring-tools.utils").invalidate_cache()
    require("spring-tools.beans").index_built = false
    require("spring-tools.endpoints").endpoints = {}
    require("spring-tools.config_explorer").properties = {}
    utils.notify("Cache cleared and indexes reset")
  end, { desc = "Refresh all Spring Tools indexes" })

  vim.api.nvim_create_user_command("SpringTestClass", function()
    require("spring-tools.tests").run_current_class()
  end, { desc = "Run current test class" })

  vim.api.nvim_create_user_command("SpringTestMethod", function()
    require("spring-tools.tests").run_current_method()
  end, { desc = "Run current test method" })

  vim.api.nvim_create_user_command("SpringConfigSearch", function(opts)
    local query = opts.args
    if query == "" then
      utils.notify("Usage: SpringConfigSearch <query>", vim.log.levels.WARN)
      return
    end
    require("spring-tools.config_explorer").search_property(query)
  end, { nargs = 1, desc = "Search configuration properties" })
end

function M.setup_keymaps()
  if not config.options.keymaps.enable then return end

  local km = config.options.keymaps

  if km.boot and km.boot ~= "" then
    vim.keymap.set("n", km.boot, function()
      require("spring-tools.boot").dashboard()
    end, { desc = "Spring Boot Dashboard" })
  end

  if km.beans and km.beans ~= "" then
    vim.keymap.set("n", km.beans, function()
      require("spring-tools.beans").explore()
    end, { desc = "Spring Bean Explorer" })
  end

  if km.endpoints and km.endpoints ~= "" then
    vim.keymap.set("n", km.endpoints, function()
      require("spring-tools.endpoints").explore()
    end, { desc = "Spring Endpoint Explorer" })
  end

  if km.tests and km.tests ~= "" then
    vim.keymap.set("n", km.tests, function()
      require("spring-tools.tests").test_explorer()
    end, { desc = "Spring Test Runner" })
  end

  if km.config and km.config ~= "" then
    vim.keymap.set("n", km.config, function()
      require("spring-tools.config_explorer").explore()
    end, { desc = "Spring Config Explorer" })
  end
end

function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup("SpringTools", { clear = true })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = { "*.java", "pom.xml", "build.gradle", "build.gradle.kts" },
    callback = function()
      if require("spring-tools.config").options.auto_refresh then
        require("spring-tools.utils").mark_dirty()
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      require("spring-tools.utils").save_cache()
    end,
  })
end

return M
