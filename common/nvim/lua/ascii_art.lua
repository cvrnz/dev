-- ASCII art from the collections tools.ensure_art() downloads: cowsay's creatures (with a
-- speech bubble) and figlet fonts (to draw text in hundreds of styles).
local M = {}

local dir = require("tools").art_dir
local cows, fonts

-- Cows that are crude rather than silly.
local skip_cows = { bong = true, ["head-in"] = true, kiss = true, mutilated = true, surgery = true }

local function read(path)
  local file = io.open(path, "rb")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return text
end

-- Some figlet fonts aren't UTF-8 (Latin-1 and the like); those would show as garbage.
local function valid_utf8(text)
  return not text:find("[\128-\255]") or vim.fn.iconv(text, "utf-8", "utf-16") ~= ""
end

local function trim(lines)
  while #lines > 0 and vim.trim(lines[1]) == "" do
    table.remove(lines, 1)
  end
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    table.remove(lines)
  end
  for i, line in ipairs(lines) do
    lines[i] = line:gsub("%s+$", "")
  end
  return lines
end

-- Forget the file lists, so art downloaded since is picked up.
function M.refresh()
  cows, fonts = nil, nil
end

local function list(pattern, skip)
  local files = {}
  for _, path in ipairs(vim.fn.glob(vim.fs.joinpath(dir, pattern), false, true)) do
    if not (skip and skip[vim.fn.fnamemodify(path, ":t:r")]) then
      table.insert(files, path)
    end
  end
  return files
end

-- A cow file is a bit of Perl: the picture is a heredoc, with backslash escapes and
-- variables for the eyes, tongue and the line up to the speech bubble.
local cow_vars = { thoughts = "\\", eyes = "oo", tongue = "  ", other_eye = "o", extra = "" }
local function parse_cow(text)
  local quote, tag = text:match("%$the_cow%s*=%s*<<%s*(['\"]?)(%w+)%1")
  if not tag then
    return nil
  end
  local body = text:match("<<%s*['\"]?" .. tag .. "['\"]?;?[^\n]*\n(.-)\n" .. tag .. "%s*\n")
    or text:match("<<%s*['\"]?" .. tag .. "['\"]?;?[^\n]*\n(.-)\n" .. tag .. "%s*$")
  if not body then
    return nil
  end
  if quote == "'" then
    return vim.split(body, "\n")
  end
  local out, i = {}, 1
  while i <= #body do
    local ch = body:sub(i, i)
    if ch == "\\" then
      table.insert(out, body:sub(i + 1, i + 1))
      i = i + 2
    elseif ch == "$" then
      local name, stop = body:match("^%${?([%a_]+)}?()", i)
      if not name then
        table.insert(out, ch)
        i = i + 1
      elseif cow_vars[name] then
        table.insert(out, cow_vars[name])
        i = stop
      else
        return nil
      end
    else
      table.insert(out, ch)
      i = i + 1
    end
  end
  return vim.split(table.concat(out), "\n")
end

-- A random cow saying `text`, or nil if none are downloaded yet.
function M.cow(text)
  cows = cows or list("cowsay/share/cowsay/cows/*.cow", skip_cows)
  if #cows == 0 then
    return nil
  end
  local lines = parse_cow(read(cows[math.random(#cows)]) or "")
  if not lines then
    return nil
  end
  local w = vim.fn.strdisplaywidth(text)
  local bubble = {
    " " .. string.rep("_", w + 2),
    "< " .. text .. " >",
    " " .. string.rep("-", w + 2),
  }
  return trim(vim.list_extend(bubble, lines))
end

-- Figlet fonts (.flf): a header line, comment lines, then each character from space to ~ as
-- `height` lines, every line ending in an end mark. The hard blank is a space that letters
-- can't overlap.
local function load_font(path)
  local text = read(path)
  if not text or not valid_utf8(text) then
    return nil
  end
  local lines = vim.split(text:gsub("\r", ""), "\n")
  local hardblank, height, comments = lines[1]:match("^flf2a(.)%s+(%d+)%s+%-?%d+%s+%-?%d+%s+%-?%d+%s+(%d+)")
  if not hardblank then
    return nil
  end
  return { lines = lines, hardblank = hardblank, height = tonumber(height), start = tonumber(comments) + 2 }
end

-- One character of a font, as rows of single characters.
local function glyph(font, char)
  local rows, width = {}, 0
  local first = font.start + (char:byte() - 32) * font.height
  for i = 0, font.height - 1 do
    local line = font.lines[first + i]
    if not line then
      return nil
    end
    local chars = vim.fn.split(line, "\\zs")
    local mark = chars[#chars]
    while #chars > 0 and chars[#chars] == mark do
      table.remove(chars)
    end
    rows[i + 1] = chars
    width = math.max(width, #chars)
  end
  for _, row in ipairs(rows) do
    while #row < width do
      table.insert(row, " ")
    end
  end
  return rows, width
end

-- Text in a random figlet font (no wider than max_width), or nil. Letters are moved together
-- until they'd touch, the way figlet "fits" them.
function M.figlet(text, max_width)
  fonts = fonts or list("figlet-fonts/*.flf")
  if #fonts == 0 then
    return nil
  end
  local font = load_font(fonts[math.random(#fonts)])
  if not font then
    return nil
  end
  local out = {}
  for r = 1, font.height do
    out[r] = {}
  end
  for char in text:gmatch(".") do
    local rows, width = glyph(font, char)
    if not rows then
      return nil
    end
    -- How far the glyph can slide left: limited by the row with the least room.
    local overlap = width
    for r = 1, font.height do
      local trailing = 0
      for c = #out[r], 1, -1 do
        if out[r][c] ~= " " then
          break
        end
        trailing = trailing + 1
      end
      local leading = 0
      for c = 1, width do
        if rows[r][c] ~= " " then
          break
        end
        leading = leading + 1
      end
      overlap = math.min(overlap, trailing + leading, #out[r])
    end
    for r = 1, font.height do
      local offset = #out[r] - overlap
      for c = 1, width do
        if rows[r][c] ~= " " or not out[r][offset + c] then
          out[r][offset + c] = rows[r][c]
        end
      end
    end
  end
  local lines = {}
  for r = 1, font.height do
    lines[r] = table.concat(out[r]):gsub(vim.pesc(font.hardblank), " ")
  end
  lines = trim(lines)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  if #lines == 0 or width > max_width then
    return nil
  end
  return lines
end

return M
