# spring-tools.nvim

IntelliJ-like Spring Boot development features inside Neovim. Sidebar UI, live log streaming, configurable backends.

## Features

- **Sidebar UI** — persistent left sidebar with tabbed views (Dashboard, Beans, Endpoints, Tests, Config)
- **Output Panel** — bottom panel for live log streaming during build/run
- **Spring Boot Dashboard** — detect, start, stop, restart apps with action picker
- **Bean Explorer** — scan and navigate @Component, @Service, @Repository, @Controller, @Configuration, @Bean (with nesting), all sections collapsible
- **REST Endpoint Explorer** — discover routes grouped by HTTP method, sections collapsible, copy curl, open in browser
- **Java Test Runner** — discover and run JUnit tests
- **Configuration Explorer** — browse application.properties / YAML
- **Process Manager** — unbuffered stdout/stderr, port extraction, exit code tracking
- **Backend System** — extensible backend registry (`spring_boot`, `docker`), priority-based selection
- **Project Cache** — persistent project list at `~/.local/share/nvim/spring-tools/projects.json`

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
  auto_refresh = true,       -- re-index on file save
  icons = {
    running = "\u{f144}",
    stopped = "\u{f04d}",
    failed = "\u{f071}",
    active = "\u{f00c}",
  },
  sidebar = {
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
    },
  },
  highlights = {
    -- Override any highlight group. Can use attributes or link.
    -- SpringToolsNormal = { link = "Normal" },
    -- SpringToolsSelected = { bg = "#334455" },
  },
  telescope = {
    enable = true,
  },
})
```

## Usage

| Command | Description |
|---------|-------------|
| `:SpringTools` | Open sidebar (defaults to Dashboard) |
| `:SpringBoot` | Open sidebar on Dashboard |
| `:SpringBeans` | Open sidebar on Beans |
| `:SpringEndpoints` | Open sidebar on Endpoints |
| `:SpringTest` | Open sidebar on Tests |
| `:SpringConfig` | Open sidebar on Config |
| `:SpringRefresh` | Clear caches and re-index |
| `:SpringTestClass` | Run current test class |
| `:SpringTestMethod` | Run current test method |
| `:SpringConfigSearch <query>` | Search config properties |

### Sidebar Navigation (default keymaps)

| Key | Action |
|-----|--------|
| `j` / `k` | Move selection up/down |
| `h` / `l` | Previous/next tab |
| `1`–`5` | Jump to tab |
| `<CR>` | Activate (start/stop/open) |
| `d` | Remove project from cache |
| `R` | Refresh current view |
| `q` | Close sidebar |
| `?` | Show help floating window |

## Highlights

All highlights are theme-derived via `nvim_get_hl` at startup:

| Group | Derives from | Description |
|-------|-------------|-------------|
| `SpringToolsNormal` | `Normal` | Default text |
| `SpringToolsSelected` | `Visual` | Selected line |
| `SpringToolsAccent` | `Special` | POST method keyword on endpoint lines |
| `SpringToolsMethodHeader` | Inherits `SpringToolsAccent` by default | Endpoint method section headers (GET, POST) |
| `SpringToolsBeanHeader` | Inherits `SpringToolsAccent` by default | Bean type section headers (Controllers, Services) |
| `SpringToolsRunning` | `DiagnosticOk` | Running status |
| `SpringToolsGet` | Inherits `SpringToolsRunning` | GET keyword on endpoint lines |
| `SpringToolsPost` | Inherits `SpringToolsRunning` | POST keyword on endpoint lines |
| `SpringToolsPut` | Inherits `SpringToolsRunning` | PUT keyword on endpoint lines |
| `SpringToolsPatch` | Inherits `SpringToolsRunning` | PATCH keyword on endpoint lines |
| `SpringToolsDelete` | Inherits `SpringToolsRunning` | DELETE keyword on endpoint lines |
| `SpringToolsError` | `ErrorMsg` | Failed status |
| `SpringToolsKey` | `Special` |  |
| `SpringToolsDim` | `Comment` | Stopped, inactive tab |

Override any group in `setup({ highlights = { SpringToolsMethodHeader = { fg = "#ff0000" } } })`.

## Modules

```
lua/spring-tools/
├── init.lua               -- Entry point
├── config.lua             -- User config with defaults
├── commands.lua           -- :Spring* commands and keymaps
├── utils.lua              -- Cache, file helpers, picker
├── project.lua            -- Project detection, active project, persistent cache
├── boot.lua               -- Thin wrapper for sidebar commands
├── beans.lua              -- Bean scanner (class annotations + @Bean methods)
├── endpoints.lua          -- REST endpoint discovery
├── tests.lua              -- JUnit test discovery and runner
├── config_explorer.lua    -- properties/YAML parser
├── backends/
│   ├── init.lua           -- Backend registry
│   ├── spring_boot.lua    -- Maven/Gradle backend
│   └── docker.lua         -- Docker backend
├── core/
│   ├── init.lua
│   ├── backend.lua        -- BaseBackend, ProcessManager with unbuffered I/O
│   └── state.lua          -- Pub/sub state, shared project list
└── ui/
    ├── init.lua           -- Legacy helpers (float windows, background jobs)
    ├── sidebar.lua        -- Sidebar manager, tab bar, keymaps, help window
    ├── output.lua         -- Bottom output panel
    ├── components.lua     -- Theme-derived highlight setup
    ├── sections.lua       -- Reusable collapsible sections (used by beans, endpoints)
    └── views/
        ├── init.lua       -- View registry (tab order)
        ├── dashboard.lua  -- Project dashboard with start/stop/restart
        ├── beans.lua      -- Bean browser with type grouping + nesting
        ├── endpoints.lua  -- Endpoint browser with method grouping
        ├── tests.lua      -- Test explorer with class/method listing
        └── config.lua     -- Config property browser
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No projects detected | Cache has old data — press `R` in sidebar or run `:SpringRefresh` |
| Compile errors in output | Check the "Root cause" section at the top of the output panel |
| Port conflict | `fuser -k 9090/tcp` to kill existing process, then restart |
| Telescope not showing | Check `telescope.enable = true` in config |
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

- Java parsing uses regex heuristics, not a full AST — complex nested annotations may not be detected
- Windows support limited — `find` command is used for file discovery
- Multi-module projects not fully supported

## License

MIT
