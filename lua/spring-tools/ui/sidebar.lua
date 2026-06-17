local config = require("spring-tools.config")
local state = require("spring-tools.core.state")

local M = {}

M.buf = nil
M.win = nil
M.view = "dashboard"
M.items = {}
M.selected = 1
M.views = {}
M.ns = vim.api.nvim_create_namespace("spring_tools_sidebar")

M.tab_order = { "dashboard", "beans", "endpoints", "tests", "config" }
M.tab_labels = {
  dashboard = "Dash",
  beans = "Beans",
  endpoints = "Endp",
  tests = "Tests",
  config = "Config",
}

local function buf_is_valid()
  return M.buf and vim.api.nvim_buf_is_valid(M.buf)
end

local function win_is_valid()
  return M.win and vim.api.nvim_win_is_valid(M.win)
end

function M.get_tab_index()
  for i, name in ipairs(M.tab_order) do
    if name == M.view then return i end
  end
  return 1
end

function M.render_tabs()
  local segments = {}
  for i, name in ipairs(M.tab_order) do
    if not M.views[name] then goto continue end
    local label = M.tab_labels[name] or name
    local is_active = name == M.view
    local icon = is_active and "\u{25cf}" or "\u{25cb}"
    local hl = is_active and "SpringToolsSelected" or "SpringToolsDim"
    local text = (i == 1 and " " or "") .. icon .. " " .. label .. (i < #M.tab_order and " " or "")
    table.insert(segments, { text, hl })
    ::continue::
  end
  return { segments = segments }
end

function M.register_view(name, view)
  M.views[name] = view
end

function M.get_view()
  return M.views[M.view]
end

function M.switch_view(name)
  if not M.views[name] then return end
  M.view = name
  M.selected = 1
  M.refresh()
end

function M.open()
  if win_is_valid() then
    vim.api.nvim_set_current_win(M.win)
    return
  end

  local pos = config.options.sidebar.position
  if pos == "left" then
    vim.cmd("topleft vsplit")
  else
    local rightmost = nil
    local right = 0
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local _, col = unpack(vim.api.nvim_win_get_position(w))
      if col > right then right = col; rightmost = w end
    end
    if rightmost then vim.api.nvim_set_current_win(rightmost) end
    vim.cmd("botright vsplit")
  end

  M.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(M.win, config.options.sidebar.width)
  vim.wo[M.win].winfixwidth = true

  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.win, M.buf)
  vim.bo[M.buf].buftype = "nofile"
  vim.bo[M.buf].modifiable = false
  vim.bo[M.buf].filetype = "springtools"

  M.setup_keymaps()
  M.refresh()
end

function M.close()
  if win_is_valid() then
    pcall(vim.api.nvim_win_close, M.win, true)
  end
  if buf_is_valid() then
    pcall(vim.api.nvim_buf_delete, M.buf, { force = true })
  end
  M.win = nil
  M.buf = nil
end

function M.refresh()
  local view = M.get_view()
  if view and view.load_items then view:load_items() end
  M.items = (view and view.items) or {}
  for i, item in ipairs(M.items) do
    if item.is_active then M.selected = i; break end
  end
  if M.selected > #M.items then M.selected = #M.items end
  if M.selected < 1 then M.selected = #M.items > 0 and 1 or 0 end
  M.render()
  M.setup_keymaps()
end

function M.render()
  if not buf_is_valid() then return end
  local view = M.get_view()
  if not view then return end

  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(M.buf, M.ns, 0, -1)

  local lines = {}
  -- Tabs
  table.insert(lines, M.render_tabs())
  -- View header
  local sep_len = config.options.sidebar.width - 2
  local header = view.header and view:header() or { { " " .. view.title, "" } }
  for _, l in ipairs(header) do
    table.insert(lines, M.render_line(l))
  end

  for idx, item in ipairs(M.items) do
    local is_sel = idx == M.selected
    local rendered = view:render_item(item, is_sel, idx)
    for _, l in ipairs(rendered) do
      table.insert(lines, M.render_line(l, is_sel))
    end
  end

  -- Build flat text lines
  local lines_flat = {}
  for _, l in ipairs(lines) do
    if l.segments then
      local text = ""
      for _, seg in ipairs(l.segments) do
        text = text .. seg[1]
      end
      table.insert(lines_flat, text)
    else
      table.insert(lines_flat, l.text)
    end
  end

  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines_flat)
  vim.bo[M.buf].modifiable = false

  -- Apply highlights
  for idx, l in ipairs(lines) do
    if l.segments then
      local col = 0
      for _, seg in ipairs(l.segments) do
        if seg[2] then
          vim.api.nvim_buf_set_extmark(M.buf, M.ns, idx - 1, col, {
            end_col = col + #seg[1],
            hl_group = seg[2],
            priority = 100,
          })
        end
        col = col + #seg[1]
      end
    elseif l.hl then
      vim.api.nvim_buf_add_highlight(M.buf, M.ns, l.hl, idx - 1, 0, -1)
    end
  end
end

function M.render_line(l, selected)
  if type(l) == "string" then
    return { text = " " .. l, hl = nil }
  end
  if l.segments then
    return l
  end
  if type(l) == "table" then
    local text, hl = unpack(l)
    if selected and (hl == "" or hl == nil) then hl = "SpringToolsSelected" end
    return { text = " " .. text, hl = hl }
  end
  return { text = "", hl = nil }
end

function M.setup_keymaps()
  if not buf_is_valid() then return end
  local km = config.options.sidebar.keymaps

  local function bmap(key, rhs)
    vim.api.nvim_buf_set_keymap(M.buf, "n", key, rhs, {
      silent = true,
      nowait = true,
      noremap = true,
    })
  end

  bmap(km.move_down, [[:lua require('spring-tools.ui.sidebar').move_down()<CR>]])
  if km.move_down_alt then
    bmap(km.move_down_alt, [[:lua require('spring-tools.ui.sidebar').move_down()<CR>]])
  end
  bmap(km.move_up, [[:lua require('spring-tools.ui.sidebar').move_up()<CR>]])
  if km.move_up_alt then
    bmap(km.move_up_alt, [[:lua require('spring-tools.ui.sidebar').move_up()<CR>]])
  end
  bmap(km.activate, [[:lua require('spring-tools.ui.sidebar').activate()<CR>]])
  bmap(km.close, [[:lua require('spring-tools.ui.sidebar').close()<CR>]])
  bmap(km.refresh, [[:lua require('spring-tools.ui.sidebar').refresh()<CR>]])
  bmap(km.remove, [[:lua require('spring-tools.ui.sidebar').remove_item()<CR>]])
  bmap(km.switch_dashboard, [[:lua require('spring-tools.ui.sidebar').switch_view('dashboard')<CR>]])
  bmap(km.switch_beans, [[:lua require('spring-tools.ui.sidebar').switch_view('beans')<CR>]])
  bmap(km.switch_endpoints, [[:lua require('spring-tools.ui.sidebar').switch_view('endpoints')<CR>]])
  bmap(km.switch_tests, [[:lua require('spring-tools.ui.sidebar').switch_view('tests')<CR>]])
  bmap(km.switch_config, [[:lua require('spring-tools.ui.sidebar').switch_view('config')<CR>]])
  if km.tab_next then
    bmap(km.tab_next, [[:lua require('spring-tools.ui.sidebar').tab_next()<CR>]])
  end
  if km.tab_prev then
    bmap(km.tab_prev, [[:lua require('spring-tools.ui.sidebar').tab_prev()<CR>]])
  end
  if km.show_help then
    bmap(km.show_help, [[:lua require('spring-tools.ui.sidebar').show_help()<CR>]])
  end
  bmap(km.preview, [[:lua require('spring-tools.ui.sidebar').preview_value()<CR>]])
  if km.search then
    bmap(km.search, [[:lua require('spring-tools.search').open()<CR>]])
  end
  if km.toggle_output then
    bmap(km.toggle_output, [[:lua require('spring-tools.ui.output').toggle()<CR>]])
  end
  bmap("D", [[:lua require('spring-tools.config_diff').open()<CR>]])
  bmap("t", [[:lua require('spring-tools.ui.sidebar').test_endpoint()<CR>]])
  bmap("c", [[:lua require('spring-tools.ui.sidebar').collapse_parent()<CR>]])
  bmap("O", [[:lua require('spring-tools.ui.sidebar').expand_child()<CR>]])
  bmap("<", [[:lua require('spring-tools.ui.sidebar').jump_fold('prev')<CR>]])
  bmap(">", [[:lua require('spring-tools.ui.sidebar').jump_fold('next')<CR>]])
end

function M.show_help()
  if M.help_win and vim.api.nvim_win_is_valid(M.help_win) then
    pcall(vim.api.nvim_win_close, M.help_win, true)
    M.help_win = nil
    return
  end

  local lines = {
    { "", "" },
    { "  Navigation", "SpringToolsAccent" },
    { "    j/k     Move selection", "" },
    { "    h/l     Switch tabs", "" },
    { "    1-5     Jump to tab", "" },
    { "", "" },
    { "  Actions", "SpringToolsAccent" },
    { "    Enter   Open nested action menu", "" },
    { "    o       Toggle output panel", "" },
    { "    /       Search all artifacts", "" },
    { "    p       Preview value (config)", "" },
    { "    d       Remove from cache", "" },
    { "    D       Config diff viewer", "" },
    { "    t       Test endpoint (curl)", "" },
    { "    c       Collapse nearest parent fold", "" },
    { "    O       Expand nearest child fold", "" },
    { "    </>     Jump to prev/next foldable header", "" },
    { "    R       Refresh current tab", "" },
    { "    q       Close sidebar", "" },
    { "", "" },
    { "  Auto-refresh on save (BufWritePost)", "SpringToolsDim" },
    { "    auto_refresh = true  (enabled by default)", "SpringToolsDim" },
    { "", "" },
    { "  Global", "SpringToolsAccent" },
    { "    :SpringSearch  Unified fuzzy search", "" },
    { "", "" },
    { "  Custom Run", "SpringToolsAccent" },
    { "    Enter on stopped -> picker", "" },
    { "    Tab       Trigger / cycle completions", "" },
    { "    Ctrl+j/k  Navigate completions", "" },
    { "    Enter     Submit command", "" },
    { "    Esc / q   Close", "" },
    { "", "" },
    { "  ? / q / Esc  Close this window", "SpringToolsDim" },
    { "", "" },
  }

  local width = 46
  local height = #lines + 2
  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.floor((vim.o.columns - width) / 2)

  M.help_buf = vim.api.nvim_create_buf(false, true)
  M.help_win = vim.api.nvim_open_win(M.help_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "single",
    title = " Keybindings ",
    title_pos = "center",
  })

  vim.bo[M.help_buf].buftype = "nofile"
  vim.bo[M.help_buf].modifiable = true

  local flat = {}
  for _, l in ipairs(lines) do table.insert(flat, l[1]) end
  vim.api.nvim_buf_set_lines(M.help_buf, 0, -1, false, flat)

  local ns = vim.api.nvim_create_namespace("spring_tools_help")
  for i, l in ipairs(lines) do
    if l[2] and l[2] ~= "" then
      vim.api.nvim_buf_add_highlight(M.help_buf, ns, l[2], i - 1, 0, -1)
    end
  end

  vim.bo[M.help_buf].modifiable = false
  vim.bo[M.help_buf].filetype = "springtools-help"

  vim.keymap.set("n", "?", function() M.show_help() end, { buffer = M.help_buf, silent = true, nowait = true })
  vim.keymap.set("n", "q", function() M.show_help() end, { buffer = M.help_buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", function() M.show_help() end, { buffer = M.help_buf, silent = true, nowait = true })
end

function M.tab_next()
  local idx = M.get_tab_index()
  local next = idx < #M.tab_order and (idx + 1) or 1
  M.switch_view(M.tab_order[next])
end

function M.tab_prev()
  local idx = M.get_tab_index()
  local prev = idx > 1 and (idx - 1) or #M.tab_order
  M.switch_view(M.tab_order[prev])
end

function M.activate()
  local view = M.get_view()
  if view and view.on_activate then view:on_activate(M.selected) end
end

function M.remove_item()
  local view = M.get_view()
  if view and view.on_remove then view:on_remove(M.selected) end
end

function M.preview_value()
  local view = M.get_view()
  if view and view.toggle_preview then view:toggle_preview(M.selected) end
end

function M.test_endpoint()
  local view = M.get_view()
  if view and view.test_endpoint then view:test_endpoint(M.selected) end
end

function M.collapse_parent()
  for i = M.selected - 1, 1, -1 do
    local item = M.items[i]
    if item and (item.type == "project_header" or item.type == "parent_header" or item.type == "header" or item.type == "section_header") and item.section_key then
      if not item.collapsed then
        local view = M.get_view()
        if view and view.on_activate then
          M.selected = i
          view:on_activate(i)
        end
        return
      end
    end
  end
end

function M.expand_child()
  for i = M.selected + 1, #M.items, 1 do
    local item = M.items[i]
    if item and (item.type == "project_header" or item.type == "parent_header" or item.type == "header" or item.type == "section_header") and item.section_key then
      if item.collapsed then
        local view = M.get_view()
        if view and view.on_activate then
          M.selected = i
          view:on_activate(i)
        end
        return
      end
    end
  end
end

function M.jump_fold(dir)
  local step = dir == "next" and 1 or -1
  local start = M.selected + step
  local i = start
  while i >= 1 and i <= #M.items do
    local item = M.items[i]
    if item and (item.type == "project_header" or item.type == "parent_header" or item.type == "header" or item.type == "section_header") then
      M.selected = i
      M.render()
      return
    end
    i = i + step
  end
end

function M.move_down()
  if M.selected < #M.items then
    M.selected = M.selected + 1
    M.render()
  end
end

function M.move_up()
  if M.selected > 1 then
    M.selected = M.selected - 1
    M.render()
  end
end

function M.get_selected()
  if #M.items == 0 then return nil end
  return M.items[M.selected]
end

function M.open_in_main(file, line)
  if not file then return end
  if not win_is_valid() then
    vim.cmd("edit " .. file)
    if line then vim.api.nvim_win_set_cursor(0, { line, 0 }); vim.cmd("normal! zz") end
    return
  end

  local target_win = nil
  local sidebar_row = nil
  pcall(function() sidebar_row = select(1, vim.api.nvim_win_get_position(M.win)) end)

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= M.win and vim.api.nvim_win_is_valid(win) then
      local ok, pos = pcall(vim.api.nvim_win_get_position, win)
      if ok and sidebar_row and pos[1] == sidebar_row then
        target_win = win
        break
      end
    end
  end

  if not target_win then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= M.win and vim.api.nvim_win_is_valid(win) then
        target_win = win
        break
      end
    end
  end

  if target_win then
    vim.api.nvim_set_current_win(target_win)
    vim.cmd("edit " .. file)
    if line then
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      vim.cmd("normal! zz")
    end
  else
    vim.api.nvim_set_current_win(M.win)
    vim.cmd("vsplit")
    vim.cmd("edit " .. file)
    if line then
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      vim.cmd("normal! zz")
    end
  end
end

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("SpringToolsSidebar", { clear = true }),
  callback = function()
    if win_is_valid() then
  vim.api.nvim_win_set_width(M.win, config.options.sidebar.width)
    end
  end,
})

return M
