-- Welcome screen shown when Neovim starts without a file: a random piece of ASCII art over
-- the shortcuts to get started. The art is "Neovim" in one of hundreds of figlet fonts, one
-- of cowsay's creatures saying something, or one of the animations below, drawn in the
-- theme's colors in a random style. Tab or Space shows another; typing (i, a, o) starts a
-- new file in its place. The art collections download on first use (see tools.lua).
local M = {}

local ascii_art = require("ascii_art")
local ns = vim.api.nvim_create_namespace("welcome")
local tick_ms = 60

-- Animations, each a function from the tick (one every tick_ms) to the frame's lines.
local animations = {}

-- Stars twinkling over mountains, under the moon.
local mountains = {
  "            /\\                    /\\",
  "     /\\    /  \\        /\\        /  \\     /\\",
  "    /  \\  /    \\      /  \\  /\\  /    \\   /  \\",
  "___/    \\/      \\____/    \\/  \\/      \\_/    \\___",
}
local moon = { [0] = { 36, ".-." }, [1] = { 35, "(   )" }, [2] = { 36, "`-'" } }
-- Stars scattered over the sky (a fixed pseudo-random pattern), clear of the moon.
local sky_width, stars, seed = 50, {}, 7
local function random(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % n
end
while #stars < 20 do
  local row, col = random(5), random(sky_width) + 1
  if not (row <= 3 and col >= 33 and col <= 43) then
    table.insert(stars, { row = row, col = col })
  end
end
table.insert(animations, function(tick)
  local rows = {}
  for r = 0, 4 do
    rows[r] = vim.split(string.rep(" ", sky_width), "")
  end
  for r, piece in pairs(moon) do
    for i, ch in ipairs(vim.fn.split(piece[2], "\\zs")) do
      rows[r][piece[1] + i] = ch
    end
  end
  local glyphs = { "·", "·", "+", "*", "✦", " " }
  for i, star in ipairs(stars) do
    local phase = (math.floor(tick / 4) + i * 5) % 17
    rows[star.row][star.col] = glyphs[phase < #glyphs and phase + 1 or 1]
  end
  local lines = {}
  for r = 0, 4 do
    table.insert(lines, table.concat(rows[r]))
  end
  return vim.list_extend(lines, mountains)
end)

-- A boat on rolling waves.
local boat = { "    |\\", "    | \\", "    |  \\", "  __|___\\_", "  \\______/" }
table.insert(animations, function(tick)
  local width, lines = 50, {}
  local x = 20 + math.floor(3 * math.sin(tick / 25))
  local bob = math.sin(tick / 6) > 0 and 0 or 1
  for _ = 1, bob do
    table.insert(lines, "")
  end
  for _, part in ipairs(boat) do
    table.insert(lines, string.rep(" ", x) .. part)
  end
  for _ = bob, 0 do
    table.insert(lines, "")
  end
  for r = 0, 3 do
    local row = {}
    for c = 0, width - 1 do
      local v = math.sin(c * 0.25 - tick * 0.15 + r * 1.3) + 0.4 * math.sin(c * 0.6 + tick * 0.1)
      row[#row + 1] = v > 0.9 and "~" or v > 0.3 and "-" or v > -0.3 and "." or " "
    end
    table.insert(lines, table.concat(row))
  end
  return lines
end)

-- Digits raining down.
local rain_width, rain_height, drops = 46, 9, {}
for c = 1, rain_width, 2 do
  table.insert(drops, { col = c, speed = 0.25 + ((c * 37) % 10) / 20, offset = (c * 53) % 17 })
end
table.insert(animations, function(tick)
  local rows = {}
  for r = 1, rain_height do
    rows[r] = vim.split(string.rep(" ", rain_width), "")
  end
  for i, drop in ipairs(drops) do
    local head = math.floor(tick * drop.speed + drop.offset) % (rain_height + 6) + 1
    for k = 0, 4 do
      local r = head - k
      if r >= 1 and r <= rain_height then
        rows[r][drop.col] = k == 0 and tostring((i + math.floor(tick / 3)) % 2) or k < 3 and ":" or "."
      end
    end
  end
  return vim.tbl_map(table.concat, rows)
end)

-- A cup of coffee, steaming.
local steam = { { "  (  )  (", "   )  (  )", "  (  )  (" }, { "   )  (  )", "  (  )  (", "   )  (  )" } }
local cup = {
  " .-----------.",
  " |           |__",
  " |           |  |",
  " |           |__|",
  "  \\_________/",
  "   `-------'",
}
table.insert(animations, function(tick)
  local lines = vim.deepcopy(steam[math.floor(tick / 8) % 2 + 1])
  for i, line in ipairs(lines) do
    lines[i] = "  " .. line
  end
  return vim.list_extend(lines, cup)
end)

-- A rocket, engine flickering.
local rocket = {
  "      /\\",
  "     /  \\",
  "    |    |",
  "    | () |",
  "    |    |",
  "   /|    |\\",
  "  /_|____|_\\",
}
local flames = { { "     \\/\\/", "      \\/" }, { "     /\\/\\", "     \\  /" }, { "     |/\\|", "      ||" } }
table.insert(animations, function(tick)
  return vim.list_extend(vim.deepcopy(rocket), flames[math.floor(tick / 3) % #flames + 1])
end)


local key = vim.env.WT_SESSION and "Ctrl " or "⌘ "

local function shortcuts()
  return {
    { "Explorer", key .. "E" },
    { "Find files and text", key .. "P" },
    { "Terminal", key .. "T" },
    { "Split terminal", key .. "\\" },
    { "New tab", key .. "N" },
    { "Switch tabs", key .. "H  " .. key .. "L" },
    { "Source control", key .. "G" },
    { "Close", key .. "W" },
    { "Command palette", ":" },
  }
end

-- What the cowsay creatures say: a tip, or something to start the day.
local sayings = {
  "Moo.",
  "Hello there!",
  "Happy hacking!",
  "What are we building today?",
  "Have you tried turning it off and on again?",
  "It works on my machine.",
  "Ship it!",
  "Coffee first.",
  "Fewer bugs than yesterday.",
  "You look nice today.",
  "Press " .. key .. "P to find any file.",
  "Press " .. key .. "E for the explorer.",
  "Press " .. key .. "T for a terminal.",
  "Press : for every command.",
  "Press " .. key .. "G to see what changed.",
  "Press Tab for another one!",
}

local function width(text)
  return vim.fn.strdisplaywidth(text)
end

local function block_width(lines)
  local w = 0
  for _, line in ipairs(lines) do
    w = math.max(w, width(line))
  end
  return w
end

-- The theme's syntax and diagnostic colors, ordered by hue, for the colorful styles.
local palette = {}
local function hue(rgb)
  local r, g, b = math.floor(rgb / 65536) / 255, math.floor(rgb / 256) % 256 / 255, rgb % 256 / 255
  local max, min = math.max(r, g, b), math.min(r, g, b)
  if max == min then
    return -1
  end
  local h = max == r and (g - b) / (max - min) or max == g and 2 + (b - r) / (max - min) or 4 + (r - g) / (max - min)
  return (h * 60) % 360
end

local function colors()
  local set = vim.api.nvim_set_hl
  set(0, "WelcomeArt", { link = "Comment" })
  set(0, "WelcomeShine", { link = "Normal" })
  set(0, "WelcomeLabel", { link = "Normal" })
  set(0, "WelcomeKey", { link = "Comment" })
  set(0, "WelcomeDim", { link = "Comment" })
  local seen, found = {}, {}
  for _, group in ipairs({
    "Function", "String", "Keyword", "Constant", "Type", "Special", "Identifier",
    "DiagnosticError", "DiagnosticWarn", "DiagnosticInfo", "DiagnosticHint", "DiagnosticOk",
  }) do
    local fg = vim.api.nvim_get_hl(0, { name = group, link = false }).fg
    if fg and not seen[fg] and hue(fg) >= 0 then
      seen[fg] = true
      table.insert(found, fg)
    end
  end
  table.sort(found, function(a, b)
    return hue(a) < hue(b)
  end)
  palette = {}
  for i, fg in ipairs(found) do
    set(0, "WelcomeColor" .. i, { fg = fg })
    palette[i] = "WelcomeColor" .. i
  end
end

-- A random piece of art that fits, as { lines, width, height, frame? }, or nil.
local function pick(max_width, max_height)
  for _ = 1, 30 do
    local roll, lines, frame = math.random(), nil, nil
    if roll < 0.4 then
      lines = ascii_art.figlet("Neovim", max_width)
      lines = lines and #lines >= 3 and lines or nil
    elseif roll < 0.75 then
      lines = ascii_art.cow(sayings[math.random(#sayings)])
    else
      frame = animations[math.random(#animations)]
      lines = frame(0)
    end
    if lines and #lines <= max_height and block_width(lines) <= max_width then
      return { lines = lines, frame = frame, width = block_width(lines), height = #lines }
    end
  end
end

-- How a piece is colored: dim with a light sweeping across, one theme color, a gradient of
-- colors from top to bottom, or moving rainbow stripes.
local styles = { "plain", "plain", "solid", "gradient", "rainbow" }

-- Highlights for one line of art, as { start_byte, end_byte, group, priority }.
local function art_highlights(line, row, art, tick)
  if line == "" then
    return {}
  end
  local style = #palette > 0 and art.style or "plain"
  if style == "solid" then
    return { { 0, #line, art.color, 100 } }
  elseif style == "gradient" then
    local span = math.min(#palette, art.height)
    local index = (art.offset + math.floor((row - 1) * span / art.height)) % #palette + 1
    return { { 0, #line, palette[index], 100 } }
  elseif style == "rainbow" then
    -- Diagonal stripes three columns wide, drifting sideways; runs of one color are merged.
    local hls, byte, col = {}, 0, 0
    for _, ch in ipairs(vim.fn.split(line, "\\zs")) do
      local group = palette[math.floor((col + row + art.offset - tick / 2) / 3) % #palette + 1]
      local last = hls[#hls]
      if last and last[3] == group then
        last[2] = byte + #ch
      else
        table.insert(hls, { byte, byte + #ch, group, 100 })
      end
      byte, col = byte + #ch, col + 1
    end
    return hls
  end
  return { { 0, #line, "WelcomeArt", 100 } }
end

-- Byte index of the n-th character (0-based) of a line.
local function byte(line, n)
  return vim.str_byteindex(line, "utf-32", math.min(n, vim.fn.strchars(line)), false)
end

local function choose(state, max_width, max_height)
  local art = pick(max_width, max_height)
  if art then
    art.style = styles[math.random(#styles)]
    art.color = palette[math.random(math.max(1, #palette))]
    art.offset = math.random(0, 11)
  end
  state.art, state.tick = art, 0
end

local function draw(state)
  local buf, win = state.buf, vim.fn.bufwinid(state.buf)
  if win == -1 then
    return
  end
  local win_width, win_height = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)
  local items = shortcuts()
  local version = vim.version()
  local footer = string.format("Neovim %d.%d.%d", version.major, version.minor, version.patch)
  local hint = "Tab  another one"

  -- Everything has a fixed place for a given window size, so a new piece of art never moves
  -- the shortcuts: the art gets an area of its own (up to 18 rows, less in a short window,
  -- none in a tiny one), with the art centered in it and well clear of the shortcuts.
  local gap = 6
  local below = gap + #items * 2 - 1 + 5
  local area = math.min(18, win_height - below - 2)
  area = area >= 4 and area or 0
  local max_width = win_width - 4
  if area > 0 and (not state.art or state.art.height > area or state.art.width > max_width) then
    choose(state, max_width, area)
  end
  local art = area > 0 and state.art or nil

  local lines, highlights = {}, {}
  local function add(text, left, hls)
    local pad = string.rep(" ", math.max(0, left or 0))
    table.insert(lines, pad .. text)
    for _, hl in ipairs(hls or {}) do
      table.insert(highlights, { #lines - 1, #pad + hl[1], #pad + hl[2], hl[3], hl[4] })
    end
  end
  -- Centered on the whole screen, so opening the explorer beside the welcome screen doesn't
  -- move it; centered in the window when there isn't room for that.
  local win_col = vim.api.nvim_win_get_position(win)[2]
  local function left_of(w)
    local left = math.floor((vim.o.columns - w) / 2) - win_col
    if left < 0 or left + w > win_width then
      left = math.floor((win_width - w) / 2)
    end
    return left
  end
  local function center(text, hls)
    add(text, left_of(width(text)), hls)
  end

  for _ = 1, math.max(0, math.floor((win_height - area - below) / 2)) do
    add("")
  end
  local spare = area - (art and art.height or 0)
  for _ = 1, math.floor(spare / 2) do
    add("")
  end
  if art then
    local art_lines = art.frame and art.frame(state.tick) or art.lines
    local left = left_of(art.width)
    -- The art is revealed left to right; then a light sweeps across plain pieces now and then.
    local reveal = state.tick * 4
    local revealed = reveal >= art.width + art.height
    local sweep = (state.tick - 30) % 80 * 2 - 10
    for r, line in ipairs(art_lines) do
      local shown = revealed and line or vim.fn.strcharpart(line, 0, math.max(0, reveal - r))
      local hls = art_highlights(shown, r, art, state.tick)
      if revealed and art.style == "plain" and not art.frame then
        local from = math.max(0, sweep - r)
        table.insert(hls, { byte(shown, from), byte(shown, math.max(from, sweep - r + 8)), "WelcomeShine", 110 })
      end
      add(shown, left, hls)
    end
  end
  for _ = 1, spare - math.floor(spare / 2) + gap do
    add("")
  end

  local label_width, key_width = 0, 0
  for _, item in ipairs(items) do
    label_width, key_width = math.max(label_width, width(item[1])), math.max(key_width, width(item[2]))
  end
  local list_width = label_width + 8 + key_width
  local left = left_of(list_width)
  for i, item in ipairs(items) do
    if i > 1 then
      add("")
    end
    local gap = string.rep(" ", list_width - width(item[1]) - width(item[2]))
    local text = item[1] .. gap .. item[2]
    add(text, left, { { 0, #item[1], "WelcomeLabel" }, { #item[1] + #gap, #text, "WelcomeKey" } })
  end
  add("")
  add("")
  center(hint, { { 0, 3, "WelcomeKey" }, { 3, #hint, "WelcomeDim" } })
  add("")
  center(footer, { { 0, #footer, "WelcomeDim" } })

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    if hl[3] > hl[2] then
      vim.api.nvim_buf_set_extmark(buf, ns, hl[1], hl[2], { end_col = hl[3], hl_group = hl[4], priority = hl[5] })
    end
  end
  -- The cursor rests on the hint, out of the way.
  vim.api.nvim_win_set_cursor(win, { #lines - 2, #lines[#lines - 2] - #hint })
end

function M.open(win)
  win = win or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "welcome"
  vim.api.nvim_win_set_buf(win, buf)
  for option, value in pairs({
    number = false,
    relativenumber = false,
    statuscolumn = "",
    cursorline = false,
    wrap = false,
    list = false,
    fillchars = "eob: ",
  }) do
    vim.api.nvim_set_option_value(option, value, { scope = "local", win = win })
  end

  math.randomseed(vim.uv.hrtime())
  local state = { buf = buf, tick = 0 }
  local timer = vim.uv.new_timer()
  timer:start(0, tick_ms, vim.schedule_wrap(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      return timer:stop()
    end
    state.tick = state.tick + 1
    draw(state)
  end))
  -- Art downloaded while the screen is up joins the mix from the next piece on.
  require("tools").ensure_art(ascii_art.refresh)

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true })
  end
  for _, lhs in ipairs({ "<Tab>", "<Space>", "<CR>", "<LeftMouse>" }) do
    map(lhs, function()
      state.art = nil
      draw(state)
    end)
  end
  for _, lhs in ipairs({ "i", "a", "o", "I", "A", "O" }) do
    map(lhs, function()
      vim.cmd.enew()
      vim.cmd.startinsert()
    end)
  end

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
    end,
  })
  -- Whatever replaces the welcome screen in this window gets the usual window options back.
  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      local w = vim.fn.bufwinid(buf)
      if w ~= -1 then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(w) then
            for _, option in ipairs({ "wrap", "list", "fillchars" }) do
              vim.api.nvim_set_option_value(option, vim.go[option], { scope = "local", win = w })
            end
          end
        end)
      end
    end,
  })
  draw(state)
end

-- Show the welcome screen when Neovim starts with nothing to open.
function M.setup()
  colors()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if vim.fn.argc() == 0 and vim.api.nvim_buf_get_name(buf) == "" and vim.bo[buf].buftype == ""
        and not vim.bo[buf].modified and vim.api.nvim_buf_line_count(buf) == 1
        and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "" then
        M.open()
      end
    end,
  })
end

return M
