local initializr = require("spring-tools.initializr")
local sidebar = require("spring-tools.ui.sidebar")
local output = require("spring-tools.ui.output")
local utils = require("spring-tools.utils")
local config = require("spring-tools.config")

local M = {}

M.title = "Initialize"

M.items = {}
M._metadata = nil
M._dependencies = nil

function M.header()
  return { { "Spring Initializr", "SpringToolsHeader" } }
end

function M.load_items()
  M.items = {
    { type = "action", action = "generate", label = "Generate new Spring Boot project" }
  }
end

function M.render_item(item, selected, idx)
  if item.type == "action" then
    local icon = selected and "\u{25b6}" or "  "
    return {
      { icon .. " " .. (item.label or item.action), "SpringToolsAction" },
    }
  end
  return { { "", "" } }
end

-- Floating prompt helper — reuses the same pattern as dashboard._show_command_input
local function show_prompt(title, default_text, on_submit)
  local km_input = config.options.command_input.keymaps
  local width = math.min(64, vim.o.columns - 4)
  local row = math.floor((vim.o.lines - 3) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "prompt"
  pcall(vim.fn.prompt_setprompt, buf, "")
  vim.bo[buf].complete = ""

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = 1,
    row = row, col = col, style = "minimal",
    border = "rounded", title = " " .. title .. " ", title_pos = "center",
  })
  vim.wo[win].winfixbuf = true

  -- Set default text in the buffer (not via prompt_setprompt which sets the prompt marker)
  if default_text and default_text ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default_text })
  end

  local closing = false
  local function cleanup()
    if closing then return end
    closing = true
    pcall(vim.api.nvim_win_close, win, true)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end

  -- Submit: get current line text
  local function submit()
    local text = vim.api.nvim_get_current_line()
    cleanup()
    on_submit(text)
  end

  vim.keymap.set("i", "<CR>", submit, { buffer = buf, silent = true })
  vim.keymap.set("n", "<CR>", submit, { buffer = buf, silent = true })
  vim.keymap.set("i", km_input.close, function() cleanup() end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", km_input.close, function() cleanup() end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", km_input.close_alt, function() cleanup() end, { buffer = buf, silent = true, nowait = true })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      if closing then return end
      vim.schedule(function() cleanup() end)
    end,
  })

  vim.api.nvim_set_current_win(win)
  vim.cmd("startinsert!")
  -- Place cursor at end of default text
  local col_pos = #default_text or 0
  vim.api.nvim_win_set_cursor(win, { 1, col_pos })
end

local function show_error(msg)
  vim.schedule(function()
    utils.notify(msg, vim.log.levels.ERROR)
  end)
end

-- Dependency picker using vim.ui.select with search
local function pick_dependencies(dep_groups, on_done)
  local flat = {}
  for _, group in ipairs(dep_groups) do
    for _, dep in ipairs(group.values or {}) do
      table.insert(flat, { id = dep.id, name = dep.name, group = group.name, description = dep.description or "" })
    end
  end
  table.sort(flat, function(a, b) return a.name < b.name end)

  local selected = {}

  local function do_pick()
    local remaining = {}
    local id_set = {}
    for _, s in ipairs(selected) do id_set[s] = true end
    for _, d in ipairs(flat) do
      if not id_set[d.id] then table.insert(remaining, d) end
    end

    if #remaining == 0 then
      on_done(selected)
      return
    end

    local choices = {}
    for _, d in ipairs(remaining) do
      table.insert(choices, {
        value = d,
        display = d.name .. "  (" .. d.group .. ")",
      })
    end
    table.insert(choices, { value = nil, display = "[done selecting]" })

    vim.ui.select(choices, {
      prompt = "Dependencies (" .. #selected .. " selected, pick more or [done])",
      format_item = function(item) return item.display end,
    }, function(choice)
      if not choice or not choice.value then
        on_done(selected)
        return
      end
      selected[#selected + 1] = choice.value.id
      do_pick()
    end)
  end

  do_pick()
end

local function run_wizard(metadata)
  local params = {}

  local function default(key)
    if metadata[key] and metadata[key].default then return metadata[key].default end
    if metadata._defaultValues and metadata._defaultValues[key] then return metadata._defaultValues[key] end
    return ""
  end

  local boot_versions = metadata.bootVersion and metadata.bootVersion.values or {}
  local release_versions, snap_versions = {}, {}
  for _, v in ipairs(boot_versions) do
    if v.id:match("SNAPSHOT") then
      table.insert(snap_versions, v)
    else
      table.insert(release_versions, v)
    end
  end

  -- Step 1: Project type
  local type_items = metadata.type and metadata.type.values or {}
  local project_types = {}
  for _, t in ipairs(type_items) do
    if t.id:match("project$") then table.insert(project_types, t) end
  end
  if #project_types == 0 then project_types = type_items end

  vim.ui.select(project_types, {
    prompt = "Project type",
    format_item = function(item) return item.name or item.id end,
  }, function(type_choice)
    if not type_choice then return end
    params.type = type_choice.id

    -- Step 2: Language
    vim.ui.select(metadata.language and metadata.language.values or {}, {
      prompt = "Language",
      format_item = function(item) return item.name or item.id end,
    }, function(lang_choice)
      if not lang_choice then return end
      params.language = lang_choice.id

      -- Step 3: Version type (release vs snapshot)
      vim.ui.select({
        { id = "release", name = "Release version" },
        { id = "snapshot", name = "Snapshot version" },
      }, {
        prompt = "Version type",
        format_item = function(item) return item.name end,
      }, function(vs)
        if not vs then return end
        local vlist
        if vs.id == "snapshot" then
          vlist = snap_versions
          if #vlist == 0 then
            show_error("No snapshot versions, using releases")
            vlist = release_versions
          end
        else
          vlist = release_versions
        end

        -- Step 3b: Pick version
        vim.ui.select(vlist, {
          prompt = "Spring Boot version",
          format_item = function(item) return item.name or item.id end,
        }, function(ver)
          if not ver then return end
          params.bootVersion = ver.id

          -- Step 4: Group ID
          show_prompt("Group ID", default("groupId"), function(text)
            params.groupId = (text ~= "" and text) or default("groupId") or "com.example"

            -- Step 5: Artifact ID
            show_prompt("Artifact ID", default("artifactId"), function(text)
              params.artifactId = (text ~= "" and text) or default("artifactId") or "demo"

              -- Step 6: Name
              show_prompt("Name", params.artifactId, function(text)
                params.name = (text ~= "" and text) or params.artifactId

                -- Step 7: Description
                show_prompt("Description (optional)", default("description"), function(text)
                  params.description = text or ""

                  -- Step 8: Package name
                  local pkg_default = (params.groupId or "") .. "." .. (params.artifactId or "demo")
                  show_prompt("Package name", default("packageName") or pkg_default, function(text)
                    params.packageName = (text ~= "" and text) or pkg_default

                    -- Step 9: Packaging
                    vim.ui.select(metadata.packaging and metadata.packaging.values or {}, {
                      prompt = "Packaging",
                      format_item = function(item) return item.name or item.id end,
                    }, function(pkg)
                      params.packaging = (pkg and pkg.id) or default("packaging") or "jar"

                      -- Step 10: Java version
                      vim.ui.select(metadata.javaVersion and metadata.javaVersion.values or {}, {
                        prompt = "Java version",
                        format_item = function(item) return item.name or item.id end,
                      }, function(jv)
                        params.javaVersion = (jv and jv.id) or default("javaVersion") or "17"

                        -- Step 11: Configuration file format
                        local config_formats = metadata.configurationFileFormat and metadata.configurationFileFormat.values or {}
                        if #config_formats > 0 then
                          vim.ui.select(config_formats, {
                            prompt = "Configuration format",
                            format_item = function(item) return item.name or item.id end,
                          }, function(cf)
                            params.configurationFileFormat = (cf and cf.id) or default("configurationFileFormat") or "properties"
                            M._pick_deps_and_finish(params, metadata)
                          end)
                        else
                          params.configurationFileFormat = "properties"
                          M._pick_deps_and_finish(params, metadata)
                        end
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end

function M._pick_deps_and_finish(params, metadata)
  -- Step 12: Dependencies (from main metadata hierarchical structure)
  local dep_groups = metadata.dependencies and metadata.dependencies.values or {}
  if #dep_groups > 0 then
    pick_dependencies(dep_groups, function(ids)
      params.dependencies = ids or {}
      M._finish_wizard(params)
    end)
  else
    params.dependencies = {}
    M._finish_wizard(params)
  end
end

function M._finish_wizard(params)
  local default_dir = vim.fn.getcwd() .. "/" .. (params.artifactId or "demo")
  show_prompt("Target directory", default_dir, function(dir)
    if not dir or dir == "" then dir = default_dir end
    dir = vim.fn.expand(dir)
    if dir:sub(1, 1) ~= "/" then dir = vim.fn.getcwd() .. "/" .. dir end

    local function confirm_generate()
      local summary = {
        "  Type:       " .. params.type,
        "  Language:   " .. params.language,
        "  Boot:       " .. params.bootVersion,
        "  Group:      " .. (params.groupId or ""),
        "  Artifact:   " .. (params.artifactId or ""),
        "  Name:       " .. (params.name or ""),
        "  Package:    " .. (params.packageName or ""),
        "  Packaging:  " .. (params.packaging or ""),
        "  Java:       " .. (params.javaVersion or ""),
        "  Config:     " .. (params.configurationFileFormat or "properties"),
        "  Deps:       " .. table.concat(params.dependencies or {}, ", "),
        "  Directory:  " .. dir,
      }

      local width = 64
      local height = #summary + 4
      local row = math.max(0, math.floor((vim.o.lines - height) / 2))
      local col = math.floor((vim.o.columns - width) / 2)

      local confirm_buf = vim.api.nvim_create_buf(false, true)
      local lines = { " Confirm project generation:", " " .. string.rep("\u{2500}", 50) }
      for _, l in ipairs(summary) do lines[#lines + 1] = l end
      lines[#lines + 1] = ""
      lines[#lines + 1] = " Press Enter to confirm, Esc to cancel"
      vim.api.nvim_buf_set_lines(confirm_buf, 0, -1, false, lines)
      vim.bo[confirm_buf].modifiable = false
      vim.bo[confirm_buf].buftype = "nofile"
      vim.bo[confirm_buf].filetype = "springtools-confirm"

      local confirm_win = vim.api.nvim_open_win(confirm_buf, true, {
        relative = "editor", width = width, height = height,
        row = row, col = col, style = "minimal",
        border = "rounded", title = " Generate Project ", title_pos = "center",
      })

      local closing = false
      local function cleanup()
        if closing then return end
        closing = true
        pcall(vim.api.nvim_win_close, confirm_win, true)
        pcall(vim.api.nvim_buf_delete, confirm_buf, { force = true })
      end

      vim.keymap.set("n", "<CR>", function()
        cleanup()
        M._do_generate(params, dir)
      end, { buffer = confirm_buf, silent = true, nowait = true })
      vim.keymap.set("n", "<Esc>", function() cleanup() end, { buffer = confirm_buf, silent = true, nowait = true })
      vim.keymap.set("n", "q", function() cleanup() end, { buffer = confirm_buf, silent = true, nowait = true })
    end

    if vim.fn.isdirectory(dir) == 1 then
      show_prompt("Directory exists. Type 'yes' to use it", "", function(ans)
        if ans:lower() == "yes" or ans:lower() == "y" then
          confirm_generate()
        end
      end)
    else
      confirm_generate()
    end
  end)
end

function M._do_generate(params, dir)
  vim.fn.mkdir(dir, "p")
  if vim.fn.isdirectory(dir) ~= 1 then
    show_error("Could not create directory: " .. dir)
    return
  end

  output.open()
  output.show({ "Generating project...", "", "  Type: " .. params.type, "  Directory: " .. dir }, "Initialize")

  initializr.generate_project(params, dir, function(err)
    vim.schedule(function()
      if err then
        show_error("Generation failed: " .. err)
        return
      end
      output.append("")
      output.append(" Project generated at " .. dir)
      utils.notify("Project generated at " .. dir)
      local project = require("spring-tools.project")
      local state = require("spring-tools.core.state")
      state.set_projects(project.detect_projects(), project.workspace_root)
      sidebar.refresh()
    end)
  end)
end

function M.on_activate(self, idx)
  if not idx or idx ~= 1 then return end
  initializr.fetch_metadata(function(meta, err)
    if err then
      show_error("Failed to fetch metadata: " .. err)
      return
    end
    M._metadata = meta

    vim.schedule(function()
      run_wizard(meta)
    end)
  end)
end

return M
