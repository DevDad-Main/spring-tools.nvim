local M = {}

M.defaults = {
  java_command = "java",
  terminal = "float",
  cache_dir = vim.fn.stdpath("cache") .. "/spring-tools",
  keymaps = {
    enable = true,
    boot = "<leader>sb",
    beans = "<leader>be",
    endpoints = "<leader>se",
    tests = "<leader>st",
    config = "<leader>sc",
  },
  telescope = {
    enable = true,
  },
  jdtls = {
    enable = false,
  },
  auto_refresh = true,
  log_level = vim.log.levels.INFO,
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("keep", opts, vim.deepcopy(M.defaults))
  vim.fn.mkdir(M.options.cache_dir, "p")
end

return M
