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
  <a href="#configuration">Configuration</a> •
  <a href="#highlights">Highlights</a> •
  <a href="#troubleshooting">Troubleshooting</a>
</p>

<br>

## Previews

<details><summary>Click to expand screenshots and demos</summary>

![Plugin Demo](previews/plugin_demo.gif)

![Dashboard](previews/plugin_demo_dashboard.gif)

![Beans Explorer](previews/plugin_demo_beans.gif)

![Endpoints Explorer](previews/plugin_demo_endpoints.gif)

![Test Runner](previews/plugin_demo_tests.gif)

![Config Explorer](previews/plugin_demo_config.gif)

![Run All Tests](previews/plugin_demo_tests_run_all.gif)

![Keybindings](previews/spring-tools-keybinds.png)

![Commands Reference](previews/spring-tools-cmds.png)

![Formatted Output](previews/spring-tools-formatted-output.png)

</details>

## Features

- **Sidebar UI** — persistent left sidebar with 5 tabbed views and `?` help float
- **Output Panel** — bottom split (12 rows, 30% height) for live log streaming
- **Dashboard** — project list with ★ active marker, ●/○ status dots, auto-selects CWD project
- **Action Picker** — start, stop, restart, custom run with POM-driven Tab-completion
- **Custom Run Command** — floating input with omnifunc completion (mvn lifecycle phases, plugin goals, `-D` properties, Gradle tasks), position configurable (`top`/`center`/`bottom`), locked against window navigation
- **Dynamic Maven Goal Discovery** — auto-discovers plugin goals from `help:effective-pom` and `help:describe` for any Maven plugin, not just 55+ well-known ones; caches across sessions; auto-invalidates on POM changes
- **Bean Explorer** — collapsible sections by stereotype, nested `@Bean` methods under `@Configuration`
- **Endpoint Explorer** — routes grouped by HTTP method (GET/POST/PUT/PATCH/DELETE), collapsible
- **Test Runner** — discover/run JUnit 5 tests, per-method results from surefire XML
- **Config Explorer** — browse application.properties/YAML, file-grouped, preview values with `p`, Enter jumps to exact line
- **Process Manager** — unbuffered I/O, port extraction, exit code tracking
- **Project Cache** — persistent JSON at `~/.local/share/nvim/spring-tools/projects.json`

<br>

## Installation

<details><summary>lazy.nvim</summary>

```lua
{
  "DevDad-Main/spring-tools.nvim",
  -- Telescope is optional — falls back to vim.ui.select
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("spring-tools").setup()
  end,
}
```

</details>

<details><summary>packer.nvim</summary>

```lua
use {
  'DevDad-Main/spring-tools.nvim',
  -- Telescope is optional — falls back to vim.ui.select
  requires = {
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('spring-tools').setup()
  end,
}
```

</details>

<br>

## Usage

<details><summary>Commands</summary>

| Command | Description |
|---------|-------------|
| `:SpringTools` | Open sidebar (defaults to Dashboard) |
| `:SpringBoot` | Open sidebar on Dashboard |
| `:SpringBeans` | Open sidebar on Beans |
| `:SpringEndpoints` | Open sidebar on Endpoints |
| `:SpringTest` | Open sidebar on Tests |
| `:SpringConfig` | Open sidebar on Config |
| `:SpringRefresh` | Clear caches and re-index |
| `:SpringClearCache` | Clear all caches (project cache + dynamic goals) |
| `:SpringTestClass` | Run current test class |
| `:SpringTestMethod` | Run current test method |
| `:SpringConfigSearch <query>` | Search config properties |

</details>

<details><summary>Sidebar Navigation (default keymaps)</summary>

| Key | Action |
|-----|--------|
| `j` / `k` | Move selection up/down |
| `h` / `l` | Previous/next tab |
| `1`–`5` | Jump to tab |
| `<CR>` | Activate (start/stop/open) |
| `p` | Preview config value (in Config view) |
| `d` | Remove project from cache |
| `R` | Refresh current view |
| `q` | Close sidebar |
| `?` | Toggle help floating window |

</details>

<details><summary>Custom Run Command Input</summary>

Press `<CR>` on a stopped project → select **Custom...** → a floating input window appears.

- **Tab** triggers omnifunc completion (mvn lifecycle phases, plugin goals, `-D` properties, Gradle tasks)
- `<C-j>` / `<C-k>` navigate the completion popup
- **Completion auto-triggers** as you type after word characters
- Position configurable via `command_input.position` (`"top"`, `"center"`, `"bottom"`)

**Window locked** — can't navigate away:
- `<Esc>` exits insert mode (stays in float)
- `<Esc>` or `q` in normal mode closes
- `<C-w/h/j/k/l>`, mouse clicks all blocked

</details>

<br>

## Configuration

<details><summary>Full default config with inline docs</summary>

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
    position = "left",         -- "left" or "right"
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

</details>

<br>

## Highlights

<details><summary>All theme-derived highlight groups</summary>

All highlights derive from your active colorscheme via `nvim_get_hl` at startup:

| Group | Derives from | Description |
|-------|-------------|-------------|
| `SpringToolsNormal` | `Normal` | Default text |
| `SpringToolsSelected` | `Visual` | Selected line |
| `SpringToolsAccent` | `Special` | ? help window section headers |
| `SpringToolsMethodHeader` | Inherits `SpringToolsAccent` | Endpoint method section headers (GET, POST) |
| `SpringToolsBeanHeader` | Inherits `SpringToolsAccent` | Bean type section headers (Controllers, Services) |
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
| `SpringToolsKey` | `Special` | Keys in config/key-value views |
| `SpringToolsValue` | `Normal` | Values in config/key-value views |
| `SpringToolsConfigSection` | Inherits `SpringToolsAccent` | Config prefix section headers (server:, spring:) |
| `SpringToolsConfigFile` | Inherits `SpringToolsHeader` | Config file section headers (application.properties) |
| `SpringToolsConfigKey` | Inherits `SpringToolsKey` | Config property key name |
| `SpringToolsConfigValue` | Inherits `SpringToolsValue` | Config property value |
| `SpringToolsDashboardProject` | Inherits `Normal` (bold) | Project name in dashboard |
| `SpringToolsDashboardStatus` | Inherits `SpringToolsDim` | Status text (stopped/running/failed) |
| `SpringToolsDashboardBuildType` | Inherits `SpringToolsDim` | Build type (maven/gradle) |
| `SpringToolsLogError` | `ErrorMsg` | Log ERROR, FATAL, SEVERE levels |
| `SpringToolsLogWarn` | `Special` | Log WARN, WARNING levels |
| `SpringToolsLogInfo` | `DiagnosticOk` | Log INFO level |
| `SpringToolsLogDebug` | `Comment` | Log DEBUG level |
| `SpringToolsLogTrace` | `Comment` | Log TRACE level |
| `SpringToolsDim` | `Comment` | Stopped, inactive tab |

</details>

<details><summary>Override examples</summary>

```lua
require("spring-tools").setup({
  highlights = {
    -- General UI
    SpringToolsHeader     = { bold = true },                  -- View titles ("Spring Beans", "REST Endpoints")
    SpringToolsSelected   = { bg = "#334455" },               -- Currently selected line
    SpringToolsAccent     = { link = "@comment" },            -- ? help window headers
    SpringToolsDim        = { fg = "#888888" },               -- Dim/muted text, inactive tabs
    SpringToolsError      = { fg = "#ff0000" },               -- Error/failure status

    -- Endpoints
    SpringToolsMethodHeader = { fg = "#ffaa00" },             -- GET(8), POST(2) section headers
    SpringToolsGet          = { fg = "#00ff00" },             -- GET keyword on endpoint lines
    SpringToolsPost         = { fg = "#00ff00" },             -- POST keyword
    SpringToolsPut          = { fg = "#00ff00" },             -- PUT keyword
    SpringToolsPatch        = { fg = "#00ff00" },             -- PATCH keyword
    SpringToolsDelete       = { fg = "#ff0000" },             -- DELETE keyword

    -- Beans
    SpringToolsBeanHeader   = { fg = "#ffaa00" },             -- Controllers, Services section headers
    SpringToolsBeanName     = { fg = "#aabbcc" },             -- Individual bean names
    SpringToolsBeanMethod   = { link = "Comment" },           -- @appName(), @maxConnections()

    -- Tests
    SpringToolsTestRunAll   = { fg = "#00ff00" },             -- ▶ Run all tests
    SpringToolsTestClass    = { fg = "#ffaa00" },             -- Test class headers
    SpringToolsTestMethod   = { fg = "#888888" },             -- ⊡ testGetUser, ⊡ testCreateUser

    -- Status
    SpringToolsRunning      = { fg = "#00ff00" },             -- Running indicator ●
    SpringToolsStopped      = { fg = "#ff0000" },             -- Stopped indicator ○

    -- Config
    SpringToolsConfigSection = { fg = "#ffaa00" },            -- server:, spring: prefix section headers
    SpringToolsConfigFile     = { fg = "#ffaa00", bold = true }, -- application.properties file headers
    SpringToolsConfigKey     = { fg = "#eebb00" },            -- port, datasource.url property keys
    SpringToolsConfigValue   = { fg = "#aabbcc" },            -- 9090, jdbc:h2:mem:testdb values

    -- Dashboard
    SpringToolsDashboardProject   = { fg = "#ffffff", bold = true }, -- Project name
    SpringToolsDashboardStatus    = { fg = "#888888" },             -- stopped/running/failed
    SpringToolsDashboardBuildType = { fg = "#666666" },             -- maven/gradle

    -- Log output
    SpringToolsLogError   = { fg = "#ff0000", bold = true },        -- ERROR, FATAL, SEVERE
    SpringToolsLogWarn    = { fg = "#ffaa00" },                     -- WARN, WARNING
    SpringToolsLogInfo    = { fg = "#00ff00" },                     -- INFO
    SpringToolsLogDebug   = { fg = "#888888" },                     -- DEBUG
    SpringToolsLogTrace   = { fg = "#555555" },                     -- TRACE
  },
})
```

</details>

<br>

## Similar Projects

A few other plugins also aim to improve the Spring Boot experience in Neovim. Here's how they compare:

| Plugin | Approach | What it does well |
|--------|----------|-------------------|
| [`JavaHello/spring-boot.nvim`](https://github.com/JavaHello/spring-boot.nvim) | LSP integration (STS4) | Config completion, bean finding via workspace symbols, code actions — all through the language server |
| [`elmcgill/springboot-nvim`](https://github.com/elmcgill/springboot-nvim) | Compile & run helpers | Incremental compiling on save, quick bootRun, Java file templates |
| [`jkeresman01/spring-initializr.nvim`](https://github.com/jkeresman01/spring-initializr.nvim) | Project scaffolding | Spring Initializr UI to generate new projects from within Neovim |

I was already using `spring-boot.nvim` for LSP-based config hints and found it useful, but I wanted a more visual sidebar — something closer to what IntelliJ's Spring Boot panel provides. That's what led me to build this plugin: a dedicated UI with tabbed views for projects, beans, endpoints, tests, and config, all sitting alongside the editor in Neovim's own window layout.

<br>

## Architecture

<details><summary>Module tree</summary>

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
├── mvn_completion.lua     — POM parser with dynamic goal discovery via effective-pom and help:describe
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
    ├── sidebar.lua        -- Sidebar manager, tab bar, keymaps, help window, auto-select active
    ├── output.lua         -- Bottom output panel
    ├── components.lua     -- Theme-derived highlight setup
    ├── sections.lua       -- Reusable collapsible sections module
    └── views/
        ├── init.lua       -- View registry (tab order)
        ├── dashboard.lua  -- Project dashboard with action picker, custom command float
        ├── beans.lua      -- Bean browser with type grouping + @Bean nesting
        ├── endpoints.lua  -- Endpoint browser with HTTP method grouping
        ├── tests.lua      -- Test explorer with class/method listing, surefire XML parsing
        └── config.lua     -- Config property browser, value preview, line jump
```

</details>

<details><summary>Key implementation details</summary>

- **`render()` vs `refresh()`** — j/k uses lightweight `render()` (no re-scan), tab-switch/Enter/R uses full `refresh()` (re-scan + render)
- **`p` keymap** — global in sidebar, dispatches to view's `toggle_preview` for config value preview
- **Custom command float** — `buftype = "prompt"` buffer with `omnifunc`, `TextChangedI` auto-trigger, `<C-j>`/`<C-k>` popup nav, `winfixbuf`, `BufLeave` fail-safe
- **Maven completion** — POM parser for `<plugin>` blocks, dynamic discovery via `help:effective-pom` + `help:describe` for unknown plugins, 55+ well-known plugins, 76 default goals, 26 lifecycle phases, 31 `-D` properties, 45 Gradle tasks, per-project cached with POM mtime invalidation
- **Segments-based rendering** — dashboard items use separate highlight groups per element (project name, status text, build type tag)
- **Expanded props persistence** — config view's `M.expanded_props` survives `load_items()` rebuild
- **Dashboard auto-select** — sidebar `refresh()` searches for `is_active` and jumps `M.selected` to the CWD-matching project

</details>

<br>

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

A sample Spring Boot test app is available at `tests/TestApp/`:
- Full MVC: models, repositories, services, controllers
- All HTTP methods (GET, POST, PUT, PATCH, DELETE)
- `@Configuration` with `@Bean` methods, `@Component` runners
- 5 test classes (11 methods), 30+ config properties with dev profile

## Requirements

- Neovim 0.10+
- Telescope.nvim (optional — enhances pickers, falls back to `vim.ui.select`)
- plenary.nvim (optional — only needed for running tests)
- Maven or Gradle (for running apps/tests)

## Limitations

- Java parsing uses regex heuristics, not a full AST — complex nested annotations may not be detected
- Windows support limited — `find` command is used for file discovery
- Multi-module projects not fully supported

## Roadmap

- [x] **POM-driven CLI completion** — parses `pom.xml` for configured plugin goals, Tab-complete in custom command prompt; enhanced with dynamic discovery via `help:effective-pom` + `help:describe`
- [x] **Persistent goal cache with POM invalidation** — discovered goals survive Neovim restarts; cache auto-invalidates when `pom.xml` changes
- [x] **Configurable float position** — `command_input.position` accepts `"top"`, `"center"`, or `"bottom"`
- [x] **Float window lock** — no accidental navigation away (`<C-w/h/j/k/l>` blocked, `BufLeave` fail-safe)
- [x] **Auto-select active project** — jumps cursor to CWD-matching project on sidebar refresh
- [ ] **Gradle build file parsing** — parse `build.gradle`/`build.gradle.kts` for dynamic task discovery
- [ ] **Multi-project workspace** — detect and manage multiple independent Spring Boot projects
- [ ] **Custom command history management** — UI to browse, edit, and delete saved custom commands

## License

MIT
