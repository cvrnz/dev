-- Darq: the look of the Vera app's classic mode (its dark theme) on a #151515 background.
-- Classic's colors are oklch values; these are them converted to hex. Its surfaces and
-- borders are white tints over the background, mixed here over #151515. Code needs more hues
-- than classic has, so purple and cyan are added at the same lightness as its blue.
local c = {
  bg = "#151515",
  fg = "#f1f2f4", -- foreground
  muted = "#8f9299", -- muted
  accent = "#3279d7", -- accent / focus
  blue = "#6da6f5", -- the accent's hue, light enough for text
  purple = "#b699eb",
  cyan = "#71d0d5",
  green = "#11c965", -- success
  amber = "#f7b750", -- warning
  red = "#e94646", -- danger
}

-- `amount` of `color` mixed into `base` (0-100).
local function mix(color, amount, base)
  local function channels(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
  end
  local r1, g1, b1 = channels(color)
  local r2, g2, b2 = channels(base or c.bg)
  local t = amount / 100
  local function blend(x, y)
    return math.floor(x * t + y * (1 - t) + 0.5)
  end
  return string.format("#%02x%02x%02x", blend(r1, r2), blend(g1, g2), blend(b1, b2))
end

c.bar = mix("#ffffff", 4) -- a step above the background, like classic's surfaces
c.cursor = mix("#ffffff", 7) -- --default
c.border = mix("#ffffff", 8) -- --border
c.segment = mix("#ffffff", 12) -- --segment
c.selection = mix(c.accent, 30)
c.search = mix(c.amber, 25)
c.faint = mix(c.fg, 30)

vim.cmd("highlight clear")
vim.g.colors_name = "darq"
vim.o.background = "dark"

local groups = {
  -- Editor
  Normal = { fg = c.fg, bg = c.bg },
  NormalNC = { link = "Normal" },
  NormalFloat = { fg = c.fg, bg = c.bg },
  FloatBorder = { fg = c.border, bg = c.bg },
  FloatTitle = { fg = c.muted, bg = c.bg },
  Cursor = { fg = c.bg, bg = c.accent },
  CursorLine = { bg = c.cursor },
  CursorColumn = { bg = c.cursor },
  ColorColumn = { bg = c.bar },
  LineNr = { fg = c.faint },
  CursorLineNr = { fg = c.fg },
  SignColumn = { bg = c.bg },
  FoldColumn = { fg = c.faint, bg = c.bg },
  Folded = { fg = c.muted, bg = c.bar },
  NonText = { fg = c.border },
  EndOfBuffer = { fg = c.border },
  Whitespace = { fg = c.border },
  SpecialKey = { fg = c.border },
  Visual = { bg = c.selection },
  VisualNOS = { bg = c.selection },
  Search = { bg = c.search },
  IncSearch = { fg = c.bg, bg = c.amber },
  CurSearch = { fg = c.bg, bg = c.amber },
  Substitute = { fg = c.bg, bg = c.red },
  MatchParen = { fg = c.blue, bold = true },
  WinSeparator = { fg = c.border },
  VertSplit = { link = "WinSeparator" },
  StatusLine = { fg = c.muted, bg = c.bar },
  StatusLineNC = { fg = c.faint, bg = c.bar },
  WinBar = { fg = c.muted, bg = c.bg },
  WinBarNC = { fg = c.faint, bg = c.bg },
  TabLine = { fg = c.muted, bg = c.bar },
  TabLineSel = { fg = c.fg, bg = c.bg, bold = true },
  TabLineFill = { bg = c.bar },
  Title = { fg = c.fg, bold = true },
  Directory = { fg = c.blue },
  Conceal = { fg = c.muted },
  QuickFixLine = { bg = c.cursor },

  -- Menus
  Pmenu = { fg = c.fg, bg = c.bar },
  PmenuSel = { bg = c.cursor },
  PmenuSbar = { bg = c.bar },
  PmenuThumb = { bg = c.segment },
  PmenuKind = { fg = c.purple, bg = c.bar },
  PmenuExtra = { fg = c.muted, bg = c.bar },
  WildMenu = { bg = c.cursor },

  -- Messages
  ModeMsg = { fg = c.muted },
  MoreMsg = { fg = c.blue },
  Question = { fg = c.blue },
  ErrorMsg = { fg = c.red },
  WarningMsg = { fg = c.amber },
  MsgArea = { fg = c.fg },

  -- Syntax: keywords purple, functions blue, types cyan, strings green, constants amber.
  Comment = { fg = c.muted, italic = true },
  Constant = { fg = c.amber },
  String = { fg = c.green },
  Character = { fg = c.green },
  Number = { fg = c.amber },
  Boolean = { fg = c.amber },
  Float = { fg = c.amber },
  Identifier = { fg = c.fg },
  Function = { fg = c.blue },
  Statement = { fg = c.purple },
  Conditional = { fg = c.purple },
  Repeat = { fg = c.purple },
  Label = { fg = c.purple },
  Operator = { fg = c.muted },
  Keyword = { fg = c.purple },
  Exception = { fg = c.purple },
  PreProc = { fg = c.purple },
  Include = { fg = c.purple },
  Define = { fg = c.purple },
  Macro = { fg = c.blue },
  PreCondit = { fg = c.purple },
  Type = { fg = c.cyan },
  StorageClass = { fg = c.purple },
  Structure = { fg = c.cyan },
  Typedef = { fg = c.cyan },
  Special = { fg = c.amber },
  SpecialChar = { fg = c.amber },
  Tag = { fg = c.blue },
  Delimiter = { fg = c.muted },
  SpecialComment = { fg = c.muted },
  Debug = { fg = c.red },
  Underlined = { underline = true },
  Error = { fg = c.red },
  Todo = { fg = c.bg, bg = c.amber, bold = true },
  Added = { fg = c.green },
  Changed = { fg = c.amber },
  Removed = { fg = c.red },

  -- Tree-sitter
  ["@variable"] = { fg = c.fg },
  ["@variable.builtin"] = { fg = c.purple },
  ["@variable.parameter"] = { fg = c.fg },
  ["@variable.member"] = { fg = c.fg },
  ["@property"] = { fg = c.fg },
  ["@constant"] = { fg = c.amber },
  ["@constant.builtin"] = { fg = c.amber },
  ["@module"] = { fg = c.fg },
  ["@string"] = { link = "String" },
  ["@string.escape"] = { fg = c.amber },
  ["@string.special"] = { fg = c.amber },
  ["@function"] = { link = "Function" },
  ["@function.builtin"] = { fg = c.blue },
  ["@function.method"] = { fg = c.blue },
  ["@constructor"] = { fg = c.blue },
  ["@keyword"] = { link = "Keyword" },
  ["@keyword.return"] = { fg = c.purple },
  ["@operator"] = { link = "Operator" },
  ["@punctuation"] = { fg = c.muted },
  ["@punctuation.delimiter"] = { fg = c.muted },
  ["@punctuation.bracket"] = { fg = c.muted },
  ["@punctuation.special"] = { fg = c.muted },
  ["@type"] = { link = "Type" },
  ["@type.builtin"] = { fg = c.cyan },
  ["@tag"] = { fg = c.blue },
  ["@tag.attribute"] = { fg = c.purple },
  ["@tag.delimiter"] = { fg = c.muted },
  ["@comment"] = { link = "Comment" },
  ["@markup.heading"] = { fg = c.blue, bold = true },
  ["@markup.strong"] = { bold = true },
  ["@markup.italic"] = { italic = true },
  ["@markup.link"] = { fg = c.blue, underline = true },
  ["@markup.link.url"] = { fg = c.blue, underline = true },
  ["@markup.raw"] = { fg = c.green },
  ["@markup.list"] = { fg = c.muted },
  ["@markup.quote"] = { fg = c.muted, italic = true },

  -- Diagnostics
  DiagnosticError = { fg = c.red },
  DiagnosticWarn = { fg = c.amber },
  DiagnosticInfo = { fg = c.blue },
  DiagnosticHint = { fg = c.purple },
  DiagnosticOk = { fg = c.green },
  DiagnosticUnderlineError = { undercurl = true, sp = c.red },
  DiagnosticUnderlineWarn = { undercurl = true, sp = c.amber },
  DiagnosticUnderlineInfo = { undercurl = true, sp = c.blue },
  DiagnosticUnderlineHint = { undercurl = true, sp = c.purple },

  -- Diffs (source control): tinted backgrounds, like the selection.
  DiffAdd = { bg = mix(c.green, 15) },
  DiffDelete = { fg = mix(c.red, 40), bg = mix(c.red, 12) },
  DiffChange = { bg = mix(c.amber, 10) },
  DiffText = { bg = mix(c.amber, 25) },

  -- Spelling
  SpellBad = { undercurl = true, sp = c.red },
  SpellCap = { undercurl = true, sp = c.amber },
  SpellLocal = { undercurl = true, sp = c.blue },
  SpellRare = { undercurl = true, sp = c.purple },

  -- Explorer
  NeoTreeNormal = { fg = c.fg, bg = c.bg },
  NeoTreeNormalNC = { fg = c.fg, bg = c.bg },
  NeoTreeDirectoryName = { fg = c.fg },
  NeoTreeDirectoryIcon = { fg = c.blue },
  NeoTreeRootName = { fg = c.muted, bold = true },
  NeoTreeIndentMarker = { fg = c.border },
  NeoTreeDotfile = { fg = c.muted },
  NeoTreeGitModified = { fg = c.amber },
  NeoTreeGitAdded = { fg = c.green },
  NeoTreeGitUntracked = { fg = c.green },
  NeoTreeGitDeleted = { fg = c.red },
  NeoTreeGitConflict = { fg = c.red },
  NeoTreeWinSeparator = { fg = c.border, bg = c.bg },
}

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end

-- Colors for :terminal, so programs running in it match too.
for i, color in ipairs({
  c.bar, c.red, c.green, c.amber, c.blue, c.purple, c.cyan, c.fg,
  c.muted, c.red, c.green, c.amber, c.blue, c.purple, c.cyan, "#ffffff",
}) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
