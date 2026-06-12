# spring-tools.nvim

IntelliJ-like Spring Boot development features inside Neovim. Lightweight, composable, idiomatic.

## Features

- **Spring Boot Dashboard** (`:SpringBoot`) — detect, start, stop, restart apps, view logs
- **Bean Explorer** (`:SpringBeans`) — scan and navigate @Component, @Service, @Repository, @Controller, @Bean
- **REST Endpoint Explorer** (`:SpringEndpoints`) — discover routes, copy curl, open in browser
- **Java Test Runner** (`:SpringTest`) — run JUnit tests, parse results, jump to failures
- **Configuration Explorer** (`:SpringConfig`) — browse application.properties / YAML, search keys

## Installation

### lazy.nvim

```lua
{
  "spring-tools.nvim",
  dev = true,
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("spring-tools").setup()
  end,
}
```

### packer.nvim

```lua
use {
  'spring-tools.nvim',
  requires = {
    'nvim-telescope/telescope.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('spring-tools').setup()
  end,
}
```

## Configuration

```lua
require("spring-tools").setup({
  java_command = "java",
  terminal = "float",             -- "float" or "buffer"
  auto_refresh = true,            -- re-index on file save
  keymaps = {
    enable = true,
    boot = "<leader>sb",          -- Spring Boot Dashboard
    beans = "<leader>be",         -- Bean Explorer
    endpoints = "<leader>se",     -- Endpoint Explorer
    tests = "<leader>st",         -- Test Runner
    config = "<leader>sc",        -- Config Explorer
  },
  telescope = {
    enable = true,                -- use Telescope picker (falls back to vim.ui.select)
  },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:SpringBoot` | Open Spring Boot Dashboard |
| `:SpringBeans` | Open Spring Bean Explorer |
| `:SpringEndpoints` | Open REST Endpoint Explorer |
| `:SpringTest` | Open Java Test Runner |
| `:SpringConfig` | Open Configuration Explorer |
| `:SpringRefresh` | Clear all caches and re-index |
| `:SpringTestClass` | Run current test class |
| `:SpringTestMethod` | Run current test method |
| `:SpringConfigSearch <query>` | Search config properties |

## ASCII Mockups

### Spring Boot Dashboard

```
╭─────────────────────────────────────╮
│      Spring Boot Applications       │
│                                     │
│  ✓ user-service                     │
│     port: 8081                      │
│     profile: dev                    │
│     status: running                 │
│                                     │
│  ○ payment-service                  │
│     status: stopped                 │
│                                     │
│  r-refresh  s-start  t-stop  l-logs │
╰─────────────────────────────────────╯
```

### Bean Explorer

```
╭─────────────────────────────────────╮
│         Spring Beans                │
│                                     │
│  Controllers                        │
│  ├── UserController                 │
│  Services                           │
│  ├── UserService                    │
│  Repositories                       │
│  └── UserRepository                 │
╰─────────────────────────────────────╯
```

## Modules

```
lua/spring-tools/
├── init.lua          -- Entry point, calls setup()
├── config.lua        -- User config with defaults
├── commands.lua      -- :Spring* commands and keymaps
├── utils.lua         -- Cache, project helpers, picker
├── project.lua       -- Maven/Gradle project detection
├── boot.lua          -- Spring Boot Dashboard
├── beans.lua         -- Bean scanner and explorer
├── endpoints.lua     -- REST endpoint discovery
├── tests.lua         -- JUnit test runner
├── config_explorer.lua -- properties/YAML parser
└── ui/
    └── init.lua      -- Floating window helpers
```

## Caching

Indexes are stored in `~/.local/share/nvim/spring-tools/spring-tools.json`. Invalidated when Java or build files change. Use `:SpringRefresh` to force re-index.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No projects detected | Ensure you're in a dir with pom.xml / build.gradle |
| Commands not found | Install Maven/Gradle or use the wrapper script |
| Telescope picker not showing | Install telescope.nvim or check `telescope.enable = true` |
| Tests not running | Ensure Maven/Gradle is on PATH |

## Testing

```bash
# With plenary.nvim installed
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua'}" -c "q"
```

## Requirements

- Neovim 0.10+
- Telescope.nvim (recommended, optional)
- plenary.nvim (for tests)
- Maven or Gradle (for running apps/tests)

## Limitations

- Parsing uses regex heuristics, not a full Java AST — complex nested annotations may not be detected
- Only single-module projects supported; multi-module Maven/Gradle projects require manual `cd`
- Windows support limited — `find` command is used for file discovery
- JDTLS integration is optional and currently limited to LSP-based jump-to-definition enhancements (not yet implemented)

## License

MIT
