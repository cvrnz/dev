vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/MunifTanjim/nui.nvim",
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = "v3.x" },
  "https://github.com/nvim-telescope/telescope.nvim",
  -- Themes
  { src = "https://github.com/navarasu/onedark.nvim" },
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
  { src = "https://github.com/folke/tokyonight.nvim" },
  { src = "https://github.com/rose-pine/neovim", name = "rose-pine" },
  { src = "https://github.com/rebelot/kanagawa.nvim" },
  { src = "https://github.com/ellisonleao/gruvbox.nvim" },
  { src = "https://github.com/EdenEast/nightfox.nvim" },
  { src = "https://github.com/sainnhe/everforest" },
})

require("tools").ensure_ripgrep()
require("welcome").setup()

-- Theme: the last one picked with :Themes, remembered across sessions. Dark themes only;
-- themes that come in both flavors (gruvbox, everforest, ...) follow 'background'.
vim.o.background = "dark"
local light_themes = {
  ["catppuccin-latte"] = true,
  ["tokyonight-day"] = true,
  ["rose-pine-dawn"] = true,
  ["kanagawa-lotus"] = true,
  dayfox = true,
  dawnfox = true,
}
local theme_file = vim.fn.stdpath("data") .. "/theme"
local saved = vim.fn.filereadable(theme_file) == 1 and vim.fn.readfile(theme_file)[1]
if light_themes[saved] or not (saved and pcall(vim.cmd.colorscheme, saved)) then
  vim.cmd.colorscheme("onedark")
end
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function(args)
    vim.fn.writefile({ args.match }, theme_file)
  end,
})

-- Live-previews each theme as you move through the list; Esc restores the previous one.
-- The picker lists themes via getcompletion(), so filter the light ones out while it builds.
vim.api.nvim_create_user_command("Themes", function()
  local getcompletion = vim.fn.getcompletion
  vim.fn.getcompletion = function(...)
    return vim.tbl_filter(function(name)
      return not light_themes[name]
    end, getcompletion(...))
  end
  pcall(require("telescope.builtin").colorscheme, { enable_preview = true, ignore_builtins = true })
  vim.fn.getcompletion = getcompletion
end, { desc = "Pick a theme" })

-- Windows that aren't content: the explorer sidebar and the padding that centers a file.
local function is_chrome(win)
  local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
  return ft == "neo-tree" or ft == "padding"
end

-- The tab's focused window, or a content window if the focused one is the explorer or padding.
local function content_win(tab)
  local win = vim.api.nvim_tabpage_get_win(tab)
  -- Floating windows (the command palette, pickers) aren't what the tab shows either.
  if is_chrome(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if not is_chrome(w) and vim.api.nvim_win_get_config(w).relative == "" then
        return w
      end
    end
  end
  return win
end

-- An unnamed, unchanged buffer with nothing in it, like the one Cmd+N opens.
local function is_empty(buf)
  if vim.bo[buf].filetype == "welcome" then
    return true
  end
  return vim.api.nvim_buf_get_name(buf) == ""
    and vim.bo[buf].buftype == ""
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_line_count(buf) == 1
    and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

-- Open a file in the tab's window if it's empty, otherwise in a new tab, optionally at a line.
local function open_file(path, line, col)
  local win = content_win(0)
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype ~= "neo-tree" and is_empty(buf) then
    vim.api.nvim_set_current_win(win)
    vim.cmd.edit(vim.fn.fnameescape(path))
  else
    vim.cmd.tabedit(vim.fn.fnameescape(path))
  end
  if line then
    vim.api.nvim_win_set_cursor(0, { line, col or 0 })
    vim.cmd("normal! zz")
  end
end

require("neo-tree").setup({
  commands = {
    -- Files open through open_file(); folders expand.
    open_in_tab = function(state)
      local node = state.tree:get_node()
      if node.type == "file" then
        open_file(node:get_id())
      else
        require("neo-tree.sources.filesystem.commands").open(state)
      end
    end,
  },
  -- Show hidden files (dotfiles, gitignored ones), except the .git folder itself.
  filesystem = {
    filtered_items = {
      hide_dotfiles = false,
      hide_gitignored = false,
      hide_hidden = false,
      never_show = { ".git", ".DS_Store" },
    },
  },
  window = {
    position = "left",
    mappings = {
      ["<cr>"] = "open_in_tab",
      ["<2-LeftMouse>"] = "open_in_tab",
    },
  },
})

-- Terminals run the shell Neovim was started from, so they get the same prompt.
-- `docker exec` doesn't set $SHELL, and without it Neovim would fall back to sh.
local parent = vim.uv.fs_readlink("/proc/" .. vim.uv.os_getppid() .. "/exe")
if parent and vim.fs.basename(parent):match("^%a*sh$") then
  vim.o.shell = parent
elseif not vim.env.SHELL or vim.env.SHELL == "" then
  vim.o.shell = vim.uv.os_get_passwd().shell
end
vim.env.SHELL = vim.o.shell

-- Shortcuts use Cmd (Ghostty on macOS) or Ctrl (Windows Terminal, which sets WT_SESSION).
-- Cmd shortcuts also work from inside terminals; Ctrl ones don't, so shells keep their Ctrl keys.
local mod = vim.env.WT_SESSION and "C" or "D"
local modes = mod == "D" and { "n", "t" } or { "n" }

local function map(keys, action, desc)
  for _, key in ipairs(keys) do
    vim.keymap.set(modes, "<" .. key:gsub("%%", mod) .. ">", action, { desc = desc })
  end
end

local function terminal(split)
  return function()
    vim.api.nvim_set_current_win(content_win(0))
    vim.cmd(split .. " | terminal")
    vim.cmd("startinsert")
  end
end

-- Close the window and its buffer, like closing an editor in VS Code.
-- Closing a tab's last window closes the tab; closing the very last one quits.
local function close_window()
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype == "neo-tree" then
    vim.cmd("Neotree close")
    return
  end
  if vim.b[buf].source_control then
    vim.cmd(#vim.api.nvim_list_tabpages() > 1 and "tabclose" or "confirm qall")
    return
  end
  if vim.bo[buf].modified then
    local name = vim.fn.expand("%:t")
    local choice = vim.fn.confirm("Save changes to " .. (name ~= "" and name or "Untitled") .. "?", "&Save\n&Don't save\n&Cancel")
    if choice == 1 then
      vim.cmd("write")
    elseif choice == 2 then
      vim.bo[buf].modified = false
    else
      return
    end
  end
  local in_tab, elsewhere = 0, 0
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local is_content = w ~= win and vim.api.nvim_win_get_config(w).relative == "" and not is_chrome(w)
      if is_content then
        if tab == vim.api.nvim_get_current_tabpage() then
          in_tab = in_tab + 1
        else
          elsewhere = elsewhere + 1
        end
      end
    end
  end
  if in_tab + elsewhere == 0 then
    vim.cmd("confirm qall")
    return
  end
  vim.cmd(in_tab == 0 and "tabclose" or "close")
  if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

-- Search modal: file names, or text inside files. Tab switches between the two and keeps
-- what you typed. Both include hidden files, skip .git and respect .gitignore (ripgrep comes from tools.lua).
local function search(kind, query)
  if vim.fn.executable("rg") == 0 then
    local installing = require("tools").installing.rg
    vim.notify(installing and "Search is getting ready (installing ripgrep), try again in a moment"
      or "Search needs ripgrep (rg), which couldn't be installed", installing and vim.log.levels.INFO or vim.log.levels.ERROR)
    return
  end
  local actions, state = require("telescope.actions"), require("telescope.actions.state")
  local opts = {
    default_text = query,
    prompt_title = kind == "files" and "Search files   (Tab: search text)" or "Search text   (Tab: search files)",
    attach_mappings = function(prompt_buf, map)
      actions.select_default:replace(function()
        local entry = state.get_selected_entry()
        actions.close(prompt_buf)
        if entry then
          open_file(entry.path or entry.filename, entry.lnum, entry.col and entry.col - 1)
        end
      end)
      map({ "i", "n" }, "<Tab>", function()
        local text = state.get_current_line()
        actions.close(prompt_buf)
        search(kind == "files" and "text" or "files", text)
      end)
      return true
    end,
  }
  if kind == "files" then
    opts.find_command = { "rg", "--files", "--hidden", "--glob", "!.git" }
    require("telescope.builtin").find_files(opts)
  else
    opts.additional_args = { "--hidden", "--glob", "!.git" }
    require("telescope.builtin").live_grep(opts)
  end
end

local function save()
  if vim.bo.buftype ~= "" then
    return
  end
  if vim.api.nvim_buf_get_name(0) ~= "" then
    vim.cmd("write")
    return
  end
  vim.ui.input({ prompt = "Save as: ", completion = "file" }, function(name)
    if name and name ~= "" then
      vim.cmd.write(vim.fn.fnameescape(name))
    end
  end)
end

-- Highlighting text with the mouse copies it to the system clipboard, and keeps it highlighted.
-- Copying goes over OSC 52, which works through tmux and in Ghostty, Windows Terminal and
-- VS Code. It never reads the clipboard back (that hangs under tmux); the terminal's own
-- paste covers that, so the + register just returns the last copy.
local osc52, copied = require("vim.ui.clipboard.osc52"), { {}, "v" }
local function copy(reg)
  local send = osc52.copy(reg)
  return function(lines, regtype)
    copied = { lines, regtype }
    send(lines)
  end
end
vim.g.clipboard = {
  name = "OSC 52 (copy only)",
  copy = { ["+"] = copy("+"), ["*"] = copy("*") },
  paste = {
    ["+"] = function() return copied end,
    ["*"] = function() return copied end,
  },
}
for _, release in ipairs({ "<LeftRelease>", "<2-LeftRelease>", "<3-LeftRelease>" }) do
  vim.keymap.set("x", release, '"+ygv', { desc = "Copy selection" })
end

map({ "%-w" }, close_window, "Close window")
vim.keymap.set({ "n", "i", "x" }, "<" .. mod .. "-s>", save, { desc = "Save" })
map({ "%-n" }, "<cmd>tabnew<cr>", "New tab")
map({ "%-p" }, function() search("files") end, "Search")
map({ "%-g" }, require("source_control").open, "Source control")
map({ "%-e" }, "<cmd>Neotree toggle left reveal<cr>", "Toggle file explorer")

-- Leaving a tab closes its explorer. It's closed once the new tab is entered, since the
-- layout can't change mid-switch. A tab left with nothing but the explorer keeps it.
vim.api.nvim_create_autocmd("TabLeave", {
  callback = function()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.schedule(function()
      if not vim.api.nvim_tabpage_is_valid(tab) or tab == vim.api.nvim_get_current_tabpage() then
        return
      end
      local wins = vim.api.nvim_tabpage_list_wins(tab)
      for _, win in ipairs(wins) do
        if #wins > 1 and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
          vim.api.nvim_win_close(win, true)
        end
      end
    end)
  end,
})
map({ "%-t" }, terminal("tab split"), "Terminal in new tab")
map({ "%-\\" }, terminal("rightbelow split"), "Terminal in horizontal split")
map({ "%-|", "S-%-\\" }, terminal("rightbelow vsplit"), "Terminal in vertical split")
map({ "%-h" }, "<cmd>tabprevious<cr>", "Previous tab")
map({ "%-l" }, "<cmd>tabnext<cr>", "Next tab")

vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- `:` opens the command palette (see command_palette.lua); visual mode keeps the plain
-- command line, since it needs the '<,'> range.
vim.keymap.set("n", ":", require("command_palette").open, { desc = "Command palette" })

-- A window stays on its buffer: no cycling through buffers within it.
for _, lhs in ipairs({ "]b", "[b", "]B", "[B", "<C-^>", "<C-6>" }) do
  vim.keymap.set("n", lhs, "<Nop>")
end

-- When a tab shows a single file, center it: empty padding windows on both sides keep the
-- text at most max_width columns wide, in the middle of the screen.
-- Files and terminals are padded; splits aren't. Padding can't be focused, and is dropped before :q
-- so quitting works as usual.
local max_width = 120
local centering = false

local function padding_win(win, side)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "padding"
  local pad = vim.api.nvim_open_win(buf, false, { split = side, win = win })
  vim.wo[pad].winfixbuf = true
  vim.wo[pad].fillchars = "eob: ,vert: "
  vim.wo[pad].number = false
  vim.wo[pad].cursorline = false
  return pad
end

local function center_tab()
  if centering then
    return
  end
  centering = true
  local content, pads, explorers, space = {}, {}, {}, vim.o.columns
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      -- floating windows (pickers, prompts) don't take up layout space
    elseif ft == "padding" then
      table.insert(pads, win)
    elseif ft == "neo-tree" then
      table.insert(explorers, win)
      space = space - vim.api.nvim_win_get_width(win) - 1
    else
      table.insert(content, win)
    end
  end
  local win = content[1]
  local spare = space - max_width - 2
  local buftype = win and vim.bo[vim.api.nvim_win_get_buf(win)].buftype
  if #content == 1 and (buftype == "" or buftype == "terminal") and spare >= 2 then
    local col = vim.api.nvim_win_get_position(win)[2]
    local left, right
    for _, pad in ipairs(pads) do
      if vim.api.nvim_win_get_position(pad)[2] < col then
        left = pad
      else
        right = pad
      end
    end
    -- The text stays where it would be with no explorer, centered on the whole screen: the
    -- explorer takes its width out of the left padding. If the explorer is wider than that
    -- padding, the text sits right next to it instead.
    local explorer = vim.o.columns - space
    local left_width = math.floor((vim.o.columns - max_width - 2) / 2) - explorer
    local right_width
    if left_width >= 1 then
      left = left or padding_win(win, "left")
      vim.api.nvim_win_set_width(left, left_width)
      right_width = space - left_width - max_width - 2
    else
      if left then
        vim.api.nvim_win_close(left, true)
      end
      right_width = space - max_width - 1
    end
    right = right or padding_win(win, "right")
    vim.api.nvim_win_set_width(right, right_width)
    vim.api.nvim_win_set_width(win, max_width)
    vim.wo[win].fillchars = "vert: "
    -- The content keeps its width and the padding gives way, so a window opening beside it
    -- (the explorer) never squeezes it, even for a moment. A terminal app like Claude Code
    -- would redraw at the squeezed width and stay cut off once the width came back.
    vim.wo[win].winfixwidth = true
    for _, explorer_win in ipairs(explorers) do
      vim.w[explorer_win].centered_width = vim.api.nvim_win_get_width(explorer_win)
    end
  else
    for _, pad in ipairs(pads) do
      vim.api.nvim_win_close(pad, true)
    end
    for _, w in ipairs(content) do
      if vim.wo[w].fillchars == "vert: " then
        vim.wo[w].fillchars = ""
      end
      vim.wo[w].winfixwidth = false
    end
    -- Share the padding's space out evenly, so splitting a centered page gives equal halves.
    -- Splitting the fixed-width content can take space from the explorer, so it gets its
    -- width back first.
    if #pads > 0 then
      for _, explorer_win in ipairs(explorers) do
        local width = vim.w[explorer_win].centered_width
        if width then
          vim.api.nvim_win_set_width(explorer_win, width)
        end
      end
      vim.cmd("wincmd =")
    end
  end
  centering = false
end

vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "WinNew", "WinClosed", "BufWinEnter", "TabEnter" }, {
  callback = function()
    vim.schedule(center_tab)
  end,
})
vim.api.nvim_create_autocmd("WinEnter", {
  callback = function()
    if vim.bo.filetype == "padding" then
      vim.schedule(function()
        vim.api.nvim_set_current_win(content_win(0))
      end)
    end
  end,
})
vim.api.nvim_create_autocmd("QuitPre", {
  callback = function()
    centering = true
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "padding" then
        vim.api.nvim_win_close(win, true)
      end
    end
    vim.schedule(function()
      centering = false
    end)
  end,
})
-- :restart restores windows from a session; padding windows shouldn't be part of it.
vim.opt.sessionoptions:remove("blank")

-- One blank row between the tab bar and the content: an empty window bar on every window
-- (floating ones aside, and ones with a bar of their own), in the normal background color.
local function spacer()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" and vim.wo[win].winbar == "" then
      vim.wo[win].winbar = " "
    end
  end
end
local function spacer_colors()
  vim.api.nvim_set_hl(0, "WinBar", { link = "Normal" })
  vim.api.nvim_set_hl(0, "WinBarNC", { link = "Normal" })
end
vim.api.nvim_create_autocmd({ "VimEnter", "WinNew", "BufWinEnter", "TabEnter" }, {
  callback = function()
    vim.schedule(spacer)
  end,
})
vim.api.nvim_create_autocmd("ColorScheme", { callback = spacer_colors })
spacer_colors()

-- :ToggleLineNumbers shows or hides line numbers in file windows and source control diffs,
-- now and in windows opened later. The choice is remembered across sessions.
local numbers_file = vim.fn.stdpath("data") .. "/line_numbers"
local show_numbers = vim.fn.filereadable(numbers_file) == 1

local function apply_numbers()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local is_file = vim.bo[buf].buftype == "" and not vim.b[buf].source_control and not is_chrome(win)
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      -- floating windows (pickers, prompts) manage their own columns
    elseif not (is_file or vim.b[buf].source_control_diff) then
      -- e.g. a window that started as an empty file and became a sidebar or terminal
      vim.wo[win].number = false
      vim.wo[win].statuscolumn = ""
    else
      vim.wo[win].number = show_numbers
      -- The cursor's line number is brighter than the rest; the line itself isn't highlighted.
      vim.wo[win].cursorline = true
      vim.wo[win].cursorlineopt = "number"
      -- Right-aligned numbers with two columns of space before the text, drawn in the text's
      -- colors. Diffs start with two blank lines to line up with the sidebar's list, so they
      -- number from the line after those.
      local lnum = vim.b[buf].source_control_diff and "v:lnum > 2 ? v:lnum - 2 : ''" or "v:lnum"
      local gap = "%#Normal#  "
      vim.wo[win].statuscolumn = show_numbers and "%=%{v:virtnum == 0 ? " .. lnum .. " : ''}" .. gap or ""
    end
  end
end

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  callback = function()
    vim.schedule(apply_numbers)
  end,
})
vim.api.nvim_create_user_command("ToggleLineNumbers", function()
  show_numbers = not show_numbers
  if show_numbers then
    vim.fn.writefile({}, numbers_file)
  else
    vim.fn.delete(numbers_file)
  end
  apply_numbers()
end, { desc = "Show or hide line numbers in files and diffs" })

-- Tab label: what the tab's window shows, skipping the explorer sidebar.
local function tab_label(tab)
  local buf = vim.api.nvim_win_get_buf(content_win(tab))
  if vim.b[buf].source_control then
    return "Source Control"
  elseif vim.bo[buf].filetype == "neo-tree" then
    return "Explorer"
  elseif vim.bo[buf].filetype == "welcome" then
    return "Welcome"
  elseif vim.bo[buf].buftype == "terminal" then
    return "Terminal"
  end
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
  return name ~= "" and name or "Untitled"
end

function _G.tabline()
  local current = vim.api.nvim_get_current_tabpage()
  local parts = {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local hl = tab == current and "%#TabLineSel#" or "%#TabLine#"
    table.insert(parts, hl .. "%" .. i .. "T " .. tab_label(tab) .. " ")
  end
  return table.concat(parts) .. "%#TabLineFill#%T"
end

vim.o.tabline = "%!v:lua.tabline()"
vim.o.showtabline = 2

-- One status bar along the bottom, like VS Code's: the mode on the left, details of the
-- active file on the right. Messages and the command line float over it when they appear,
-- instead of taking a row of their own.
vim.o.laststatus = 3
vim.o.showmode = false
vim.o.ruler = false
vim.o.showcmd = false
if pcall(function()
  require("vim._core.ui2").enable({ msg = { target = "msg" } })
end) then
  vim.o.cmdheight = 0
end

local mode_names = {
  n = "NORMAL",
  i = "INSERT",
  v = "VISUAL",
  V = "VISUAL LINE",
  ["\22"] = "VISUAL BLOCK",
  s = "SELECT",
  S = "SELECT LINE",
  ["\19"] = "SELECT BLOCK",
  R = "REPLACE",
  c = "COMMAND",
  t = "TERMINAL",
}

local line_endings = { unix = "LF", dos = "CRLF", mac = "CR" }

-- Language names as VS Code shows them, where capitalizing the filetype isn't enough.
local languages = {
  sh = "Shell Script", bash = "Shell Script", zsh = "Shell Script",
  json = "JSON", jsonc = "JSON with Comments", yaml = "YAML", toml = "TOML",
  html = "HTML", css = "CSS", scss = "SCSS", sql = "SQL", xml = "XML",
  javascript = "JavaScript", javascriptreact = "JavaScript React",
  typescript = "TypeScript", typescriptreact = "TypeScript React",
  cpp = "C++", cs = "C#", objc = "Objective-C", php = "PHP",
  gitcommit = "Git Commit", gitignore = "Ignore", vim = "Vim Script",
  conf = "Properties", text = "Plain Text", [""] = "Plain Text",
}

-- Details of the file in the active window (or, from the explorer, the file beside it).
local function file_details(win, buf)
  local items = {}
  local errors = #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.ERROR })
  local warnings = #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.WARN })
  if errors > 0 then
    table.insert(items, "%#StatusError#✖ " .. errors .. "%#StatusLine#")
  end
  if warnings > 0 then
    table.insert(items, "%#StatusWarn#▲ " .. warnings .. "%#StatusLine#")
  end
  local cursor = vim.api.nvim_win_get_cursor(win)
  local position = "Ln " .. cursor[1] .. ", Col " .. cursor[2] + 1
  local mode = vim.api.nvim_get_mode().mode
  if win == vim.api.nvim_get_current_win() and mode:match("^[vV\22]") then
    local lines = math.abs(vim.fn.line("v") - cursor[1]) + 1
    if mode == "v" and lines == 1 then
      position = position .. " (" .. math.abs(vim.fn.col("v") - cursor[2] - 1) + 1 .. " selected)"
    else
      position = position .. " (" .. lines .. " lines selected)"
    end
  end
  table.insert(items, position)
  local bo = vim.bo[buf]
  table.insert(items, bo.expandtab and "Spaces: " .. vim.fn.shiftwidth() or "Tab Size: " .. bo.tabstop)
  table.insert(items, (bo.fileencoding ~= "" and bo.fileencoding or vim.o.encoding):upper())
  table.insert(items, line_endings[bo.fileformat])
  local ft = bo.filetype
  table.insert(items, languages[ft] or ft:sub(1, 1):upper() .. ft:sub(2))
  return items
end

function _G.statusbar()
  local mode = vim.api.nvim_get_mode().mode
  local left = "  " .. (mode_names[mode:sub(1, 1)] or mode_names.n)
  local win = content_win(0)
  local buf = vim.api.nvim_win_get_buf(win)
  local items
  if vim.b[buf].source_control then
    items = { vim.t.source_control_repo }
  elseif vim.bo[buf].buftype == "terminal" then
    -- The title the program sets, or else the program's name, not the term:// buffer name.
    local title = vim.b[buf].term_title or ""
    if title == "" or title:match("^term://") then
      title = vim.fs.basename((title:match("^term://.-//%d+:(%S+)") or ""))
    end
    items = { title }
  elseif vim.bo[buf].buftype == "" then
    items = vim.api.nvim_win_call(win, function()
      return file_details(win, buf)
    end)
  end
  items = vim.tbl_map(function(item)
    return item:find("%#", 1, true) and item or item:gsub("%%", "%%%%")
  end, items or {})
  return left .. "%=" .. table.concat(items, "    ") .. "  "
end

vim.o.statusline = "%!v:lua.statusbar()"
vim.api.nvim_create_autocmd({ "ModeChanged", "DiagnosticChanged" }, {
  callback = function()
    vim.cmd.redrawstatus()
  end,
})

-- The bar, tabs, line numbers and pickers (the command palette, Cmd+P, :Themes) take the
-- theme's neutral colors: its text, comment and cursor-line colors on its background (plus
-- its error and warning colors for diagnostics), so every theme gets the same quiet look in
-- its own palette.
local function color(group, attr)
  return vim.api.nvim_get_hl(0, { name = group, link = false })[attr]
end
local function first_color(groups)
  for _, group in ipairs(groups) do
    local value = color(group, "fg")
    if value then
      return value
    end
  end
end
local function bar_colors()
  local bg, fg = color("Normal", "bg"), color("Normal", "fg")
  local dim = first_color({ "Comment", "NonText" })
  local raised = color("CursorLine", "bg") or color("StatusLine", "bg")
  local set = vim.api.nvim_set_hl
  set(0, "StatusLine", { fg = dim, bg = bg })
  set(0, "StatusLineNC", { fg = dim, bg = bg })
  set(0, "StatusError", { fg = first_color({ "DiagnosticError", "ErrorMsg" }), bg = bg })
  set(0, "StatusWarn", { fg = first_color({ "DiagnosticWarn", "WarningMsg" }), bg = bg })
  set(0, "TabLineFill", { bg = bg })
  set(0, "TabLine", { fg = dim, bg = bg })
  set(0, "TabLineSel", { fg = fg, bg = raised, bold = true })
  -- Line numbers: dim, with the cursor's line in the text color.
  set(0, "LineNr", { fg = first_color({ "LineNr", "Comment" }), bg = bg })
  set(0, "CursorLineNr", { fg = fg, bg = bg })
  -- Pickers: borders and titles dim, the selected row on the cursor-line shade, matched
  -- characters in bold text color.
  for _, group in ipairs({ "Normal", "PromptNormal", "ResultsNormal", "PreviewNormal" }) do
    set(0, "Telescope" .. group, { fg = fg, bg = bg })
  end
  for _, group in ipairs({
    "Border", "PromptBorder", "ResultsBorder", "PreviewBorder",
    "Title", "PromptTitle", "ResultsTitle", "PreviewTitle",
    "PromptPrefix", "PromptCounter", "SelectionCaret", "MultiIcon",
  }) do
    set(0, "Telescope" .. group, { fg = dim, bg = bg })
  end
  set(0, "TelescopeSelection", { fg = fg, bg = raised })
  set(0, "TelescopeMultiSelection", { fg = fg, bg = raised })
  set(0, "TelescopeMatching", { fg = fg, bold = true })
end
vim.api.nvim_create_autocmd("ColorScheme", { callback = bar_colors })
bar_colors()
