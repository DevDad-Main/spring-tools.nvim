local M = {}

M.defaults = {
  java_command = "java",
  terminal = "float",
  cache_dir = vim.fn.stdpath("cache") .. "/spring-tools",
  icons = {
    running = "\u{f144}",
    stopped = "\u{f04d}",
    failed = "\u{f071}",
    active = "\u{f00c}",
  },
  sidebar = {
    position = "left",
    width = 48,
    keymaps = {
      move_down = "j",
      move_up = "k",
      move_down_alt = "<Down>",
      move_up_alt = "<Up>",
      activate = "<CR>",
      close = "q",
      refresh = "R",
      remove = "d",
      switch_dashboard = "1",
      switch_beans = "2",
      switch_endpoints = "3",
      switch_tests = "4",
      switch_config = "5",
      tab_next = "l",
      tab_prev = "h",
      show_help = "?",
      search = "/",
      preview = "p",
      toggle_output = "o",
    },
  },
  keymaps = {
    enable = true,
    boot = "<leader>sb",
    beans = "<leader>be",
    endpoints = "<leader>se",
    tests = "<leader>st",
    config = "<leader>sc",
    search = "<leader>ss",
  },
  telescope = {
    enable = true,
  },
  output = {
    keymaps = {
      close = "q",
      close_alt = "<Esc>",
      copy = "c",
      filter_error = "e",
      filter_warn = "w",
      filter_info = "i",
      filter_debug = "d",
      filter_trace = "t",
    },
  },
  diff = {
    highlights = {
      changed = "SpringToolsLogWarn",
      same = "SpringToolsRunning",
      left_only = "SpringToolsError",
      right_only = "SpringToolsError",
    },
  },
  jdtls = {
    enable = false,
  },
  command_input = {
    position = "center",  -- "top", "center", or "bottom"
  },
  search = {
    icons = {
      bean = "",              -- bean class
      bean_method = "",       -- @Bean method
      endpoint = "",          -- REST endpoint
      test_class = "",        -- test class
      test_method = "",       -- test method
      config = "",            -- config property
    },
  },
  auto_refresh = true,
  auto_restart = {
    enable = true,       -- master switch (off = disabled for all projects)
    delay = 500,         -- debounce delay in ms
    cooldown = 3000,     -- minimum ms between restarts
    clean = false,       -- run "mvn clean" / "gradle clean" before restart
    skip_tests = true,   -- ignore saves in src/test/** directories
  },
  log_level = vim.log.levels.INFO,
  highlights = {},
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend("keep", opts, vim.deepcopy(M.defaults))
  vim.fn.mkdir(M.options.cache_dir, "p")
end

return M
