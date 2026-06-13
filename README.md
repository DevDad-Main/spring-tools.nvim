<p align="center">
  <img src="https://img.shields.io/github/stars/DevDad-Main/spring-tools.nvim?style=for-the-badge&logo=github" alt="Stars">
  <img src="https://img.shields.io/github/forks/DevDad-Main/spring-tools.nvim?style=for-the-badge&logo=github" alt="Forks">
  <img src="https://img.shields.io/github/issues/DevDad-Main/spring-tools.nvim?style=for-the-badge&logo=github" alt="Issues">
  <img src="https://img.shields.io/github/license/DevDad-Main/spring-tools.nvim?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/neovim-0.10+-blue?style=for-the-badge&logo=neovim" alt="Neovim">
  <img src="https://img.shields.io/github/last-commit/DevDad-Main/spring-tools.nvim?style=for-the-badge&logo=git" alt="Last Commit">
</p>

<h1 align="center">spring-tools.nvim</h1>

<p align="center">
  IntelliJ-like Spring Boot development features inside Neovim.
  <br>
  Sidebar UI, live log streaming, configurable backends.
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#highlights">Highlights</a> •
  <a href="#troubleshooting">Troubleshooting</a>
</p>

<br>

## Screenshots

> *Screenshots coming soon — recording with [asciinema](https://asciinema.org) for terminal-to-GIF demos.*

<br>

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
  java_command = "java",       -- Java binary path
  auto_refresh = true,         -- re-index on file save
  icons = {
    running = "\u{f144}",      -- playing icon
    stopped = "\u{f04d}",      -- pause icon
    failed = "\u{f071}",       -- warning icon
    active = "\u{f00c}",       -- checkmark icon
  },
  sidebar = {
    width = 48,                -- sidebar width in columns
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
    enable = true,             -- enable Telescope-based pickers
  },
  command_input = {
    position = "center",       -- "top", "center", or "bottom"
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

### Custom Run Command Input

Press `<CR>` on a stopped project, select **Custom...**, and a centered floating window appears. Type your command with Tab-completion (Maven lifecycle phases, plugin goals, `-D` properties, Gradle tasks). The float position is configurable via `command_input.position` (`"top"`, `"center"`, or `"bottom"`). Press `<Esc>` to exit insert mode, then `<Esc>` or `q` to close.

## Highlights

All highlights are theme-derived via `nvim_get_hl` at startup:

| Group | Derives from | Description |
|-------|-------------|-------------|
| `SpringToolsNormal` | `Normal` | Default text |
| `SpringToolsSelected` | `Visual` | Selected line |
| `SpringToolsAccent` | `Special` | ? help window section headers |
| `SpringToolsMethodHeader` | Inherits `SpringToolsAccent` by default | Endpoint method section headers (GET, POST) |
| `SpringToolsBeanHeader` | Inherits `SpringToolsAccent` by default | Bean type section headers (Controllers, Services) |
| `SpringToolsBeanName` | Inherits `Normal` | Individual bean names (UserController, UserService) |
| `SpringToolsBeanMethod` | Inherits `SpringToolsDim` | @Bean method entries (@appName(), @maxConnections()) |
| `SpringToolsRunning` | `DiagnosticOk` | Running status |
| `SpringToolsGet` | Inherits `SpringToolsRunning` | GET keyword on endpoint lines |
| `SpringToolsPost` | Inherits `SpringToolsRunning` | POST keyword on endpoint lines |
| `SpringToolsPut` | Inherits `SpringToolsRunning` | PUT keyword on endpoint lines |
| `SpringToolsPatch` | Inherits `SpringToolsRunning` | PATCH keyword on endpoint lines |
| `SpringToolsDelete` | Inherits `SpringToolsRunning` | DELETE keyword on endpoint lines |
| `SpringToolsTestRunAll` | Inherits `SpringToolsAccent` | Run all tests header |
| `SpringToolsTestClass` | Inherits `SpringToolsAccent` | Test class header |
| `SpringToolsTestMethod` | Inherits `SpringToolsDim` | Test method name |
| `SpringToolsError` | `ErrorMsg` | Failed status |
| `SpringToolsKey` | `Special` |  |
| `SpringToolsValue` | `Normal` |  |
| `SpringToolsConfigSection` | Inherits `SpringToolsAccent` | Config prefix section headers (server:, spring:) |
| `SpringToolsConfigFile` | Inherits `SpringToolsHeader` | Config file section headers (application.properties) |
| `SpringToolsConfigKey` | Inherits `SpringToolsKey` | Config property key name |
| `SpringToolsConfigValue` | Inherits `SpringToolsValue` | Config property value |
| `SpringToolsDashboardProject` | Inherits `Normal` (bold) | Project name in dashboard |
| `SpringToolsDashboardStatus` | Inherits `SpringToolsDim` | Status text (stopped/running/failed) |
| `SpringToolsDashboardBuildType` | Inherits `SpringToolsDim` | Build type (maven/gradle) |
| `SpringToolsDim` | `Comment` | Stopped, inactive tab |

Override any group via `setup()`:

```lua
require("spring-tools").setup({
  highlights = {
    -- General UI
    SpringToolsHeader     = { bold = true },                  -- View titles ("Spring Beans", "REST Endpoints")
    SpringToolsSelected   = { bg = "#334455" },               -- Currently selected line
    SpringToolsAccent     = { link = "@comment" },             -- ? help window headers
    SpringToolsDim        = { fg = "#888888" },                -- Dim/muted text, inactive tabs
    SpringToolsError      = { fg = "#ff0000" },                -- Error/failure status

    -- Endpoints
    SpringToolsMethodHeader = { fg = "#ffaa00" },              -- GET(8), POST(2) section headers
    SpringToolsGet          = { fg = "#00ff00" },              -- GET keyword on endpoint lines
    SpringToolsPost         = { fg = "#00ff00" },              -- POST keyword
    SpringToolsPut          = { fg = "#00ff00" },              -- PUT keyword
    SpringToolsPatch        = { fg = "#00ff00" },              -- PATCH keyword
    SpringToolsDelete       = { fg = "#ff0000" },              -- DELETE keyword

    -- Beans
    SpringToolsBeanHeader   = { fg = "#ffaa00" },              -- Controllers, Services section headers
    SpringToolsBeanName     = { fg = "#aabbcc" },              -- Individual bean names
    SpringToolsBeanMethod   = { link = "Comment" },            -- @appName(), @maxConnections()

    -- Tests
    SpringToolsTestRunAll   = { fg = "#00ff00" },              -- ▶ Run all tests
    SpringToolsTestClass    = { fg = "#ffaa00" },              -- Test class headers
    SpringToolsTestMethod   = { fg = "#888888" },              -- ⊡ testGetUser, ⊡ testCreateUser

    -- Status
    SpringToolsRunning      = { fg = "#00ff00" },              -- Running indicator ●
    SpringToolsStopped      = { fg = "#ff0000" },              -- Stopped indicator ○

    -- Config
    SpringToolsConfigSection = { fg = "#ffaa00" },             -- server:, spring: prefix section headers
    SpringToolsConfigFile     = { fg = "#ffaa00", bold = true }, -- application.properties file headers
    SpringToolsConfigKey     = { fg = "#eebb00" },             -- port, datasource.url property keys
    SpringToolsConfigValue   = { fg = "#aabbcc" },             -- 9090, jdbc:h2:mem:testdb values

    -- Dashboard
    SpringToolsDashboardProject   = { fg = "#ffffff", bold = true }, -- Project name
    SpringToolsDashboardStatus    = { fg = "#888888" },             -- stopped/running/failed
    SpringToolsDashboardBuildType = { fg = "#666666" },             -- maven/gradle
  },
})
```

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

## Roadmap

Ideas for future releases:

- [x] **POM-driven CLI completion** — parses `pom.xml` to discover configured plugins and their goals; Tab-complete `mvn <phase>`, `mvn <plugin>:<goal>`, `mvn -D<property>` in the custom command prompt
- [x] **Configurable float position** — `command_input.position` accepts `"top"`, `"center"`, or `"bottom"`
- [ ] **Gradle build file parsing** — parse `build.gradle`/`build.gradle.kts` for dynamic task discovery (currently uses a static list)
- [ ] **Multi-project workspace** — detect and manage multiple independent Spring Boot projects in the same Neovim session
- [ ] **Custom command history management** — UI to browse, edit, and delete saved custom commands

## License

MIT
