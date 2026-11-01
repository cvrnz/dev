-- Floating explorer, like a Telescope picker: the folder tree (neo-tree) on the left and a
-- preview of what's under the cursor on the right. Clicking or moving through the tree
-- updates the preview; Enter or a double click opens the file. It closes on Esc, Cmd/Ctrl+E,
-- or when focus leaves it (clicking outside).
-- The preview only reads the file into a scratch buffer, so passing over files doesn't load
-- them as real buffers (no language servers starting, nothing left in the buffer list).
local M = {}

local preview = { win = nil, buf = nil, path = nil }
local tree_win

local max_lines = 1000
local max_bytes = 1024 * 1024

-- One box of 80% of the screen, centered; the tree takes a third of it, at least 30 columns.
-- Sizes are inside the borders, positions are of the border's top-left corner.
local function layout()
  local columns, lines = vim.o.columns, vim.o.lines
  local width = math.min(columns - 2, math.max(60, math.floor(columns * 0.8)))
  local height = math.max(6, math.floor(lines * 0.8) - 2)
  local tree_width = math.max(30, math.floor(width / 3)) - 2
  local row = math.max(0, math.floor((lines - height - 2) / 2) - 1)
  local col = math.floor((columns - width) / 2)
  return {
    tree = { row = row, col = col, width = tree_width, height = height },
    preview = { row = row, col = col + tree_width + 2, width = width - tree_width - 4, height = height },
  }
end

-- For neo-tree's window.popup options.
function M.popup_size()
  local tree = layout().tree
  return { width = tree.width, height = tree.height }
end

function M.popup_position()
  local tree = layout().tree
  return { row = tree.row, col = tree.col }
end

local function is_open()
  return tree_win and vim.api.nvim_win_is_valid(tree_win)
end

local function close_preview()
  if preview.win and vim.api.nvim_win_is_valid(preview.win) then
    vim.api.nvim_win_close(preview.win, true)
  end
  if preview.buf and vim.api.nvim_buf_is_valid(preview.buf) then
    vim.api.nvim_buf_delete(preview.buf, { force = true })
  end
  preview = { win = nil, buf = nil, path = nil }
end

function M.close()
  close_preview()
  if is_open() then
    vim.api.nvim_win_close(tree_win, true)
  end
  tree_win = nil
end

local function show(lines, title, path)
  local buf = preview.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  pcall(vim.treesitter.stop, buf)
  vim.bo[buf].syntax = ""
  -- Highlighting without setting 'filetype', so no ftplugins or language servers attach.
  local ft = path and vim.filetype.match({ filename = path, contents = lines })
  if ft then
    local lang = vim.treesitter.language.get_lang(ft) or ft
    if not pcall(vim.treesitter.start, buf, lang) then
      vim.bo[buf].syntax = ft
    end
  end
  vim.api.nvim_win_set_config(preview.win, { title = " " .. title .. " ", title_pos = "center" })
  vim.api.nvim_win_set_cursor(preview.win, { 1, 0 })
end

local function message(text, title)
  show({ "", "  " .. text }, title)
  vim.api.nvim_buf_set_extmark(preview.buf, vim.api.nvim_create_namespace("explorer"), 1, 0, {
    end_col = #text + 2,
    hl_group = "Comment",
  })
end

local function preview_directory(path, name)
  local dirs, files = {}, {}
  for entry, kind in vim.fs.dir(path) do
    if entry ~= ".git" and entry ~= ".DS_Store" then
      table.insert(kind == "directory" and dirs or files, entry)
    end
  end
  table.sort(dirs)
  table.sort(files)
  if #dirs + #files == 0 then
    return message("Empty folder", name)
  end
  local lines = {}
  for _, dir in ipairs(dirs) do
    table.insert(lines, dir .. "/")
  end
  vim.list_extend(lines, files)
  show(lines, name)
  local ns = vim.api.nvim_create_namespace("explorer")
  for i = 1, #dirs do
    vim.api.nvim_buf_set_extmark(preview.buf, ns, i - 1, 0, { end_col = #lines[i], hl_group = "Directory" })
  end
end

local function preview_file(path, name)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return message("Can't read this file", name)
  elseif stat.size > max_bytes then
    return message("Too large to preview", name)
  end
  local ok, lines = pcall(vim.fn.readfile, path, "", max_lines)
  if not ok then
    return message("Can't read this file", name)
  end
  for i, line in ipairs(lines) do
    -- readfile turns NUL bytes into newlines.
    if line:find("\n", 1, true) then
      return message("Binary file", name)
    end
    lines[i] = line:gsub("\r$", "")
  end
  if #lines == 0 then
    return message("Empty file", name)
  end
  show(lines, name, path)
end

local function update()
  if not (is_open() and preview.win and vim.api.nvim_win_is_valid(preview.win)) then
    return
  end
  local state = require("neo-tree.sources.manager").get_state_for_window(tree_win)
  local ok, node = pcall(function()
    return state.tree:get_node()
  end)
  local path = ok and node and node.path
  if not path or path == preview.path then
    return
  end
  preview.path = path
  local name = vim.fn.fnamemodify(path, ":t")
  if node.type == "directory" then
    preview_directory(path, name)
  else
    preview_file(path, name)
  end
end

local function place()
  if not is_open() then
    return
  end
  local spot = layout()
  local popup = require("neo-tree.ui.renderer").get_nui_popup(tree_win)
  if popup then
    popup:update_layout({
      relative = "editor",
      position = { row = spot.tree.row, col = spot.tree.col },
      size = { width = spot.tree.width, height = spot.tree.height },
    })
  end
  if preview.win and vim.api.nvim_win_is_valid(preview.win) then
    local p = spot.preview
    vim.api.nvim_win_set_config(preview.win, { relative = "editor", row = p.row, col = p.col, width = p.width, height = p.height })
  end
end

-- Called when neo-tree opens a floating window: adds the preview beside it.
function M.attach(win)
  close_preview()
  tree_win = win
  vim.api.nvim_win_set_config(win, { title = " Explorer ", title_pos = "center" })
  local tree_buf = vim.api.nvim_win_get_buf(win)
  local p = layout().preview
  preview.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[preview.buf].bufhidden = "wipe"
  preview.win = vim.api.nvim_open_win(preview.buf, false, {
    relative = "editor",
    row = p.row,
    col = p.col,
    width = p.width,
    height = p.height,
    border = "rounded",
    focusable = false,
    style = "minimal",
    zindex = 40,
  })
  vim.wo[preview.win].winhighlight = "Normal:NeoTreeFloatNormal,FloatBorder:NeoTreeFloatBorder"
  vim.wo[preview.win].wrap = false

  local group = vim.api.nvim_create_augroup("explorer_float", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", { group = group, buffer = tree_buf, callback = update })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(win),
    callback = function()
      vim.api.nvim_del_augroup_by_id(group)
      vim.schedule(M.close)
    end,
  })
  -- Focus moving anywhere else closes it, except to neo-tree's own prompts (new file, rename, ...).
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local ft = vim.bo.filetype
      if vim.api.nvim_get_current_win() ~= tree_win and ft ~= "neo-tree-popup" and ft ~= "neo-tree" then
        vim.schedule(M.close)
      end
    end,
  })
  -- neo-tree moves its float on resize too (relative to the wrong window), after this runs.
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    -- After neo-tree's own (debounced by 100ms) resize handling, which would misplace the tree.
    callback = function()
      vim.defer_fn(place, 250)
      vim.defer_fn(place, 200)
    end,
  })
  vim.schedule(update)
end

-- Scroll the preview by half its height (positive is down).
function M.scroll(direction)
  if preview.win and vim.api.nvim_win_is_valid(preview.win) then
    local keys = vim.keycode(direction > 0 and "<C-d>" or "<C-u>")
    vim.api.nvim_win_call(preview.win, function()
      vim.cmd("normal! " .. keys)
    end)
  end
end

function M.toggle()
  if is_open() then
    M.close()
    return
  end
  require("neo-tree.command").execute({ source = "filesystem", position = "float", reveal = true })
end

return M
