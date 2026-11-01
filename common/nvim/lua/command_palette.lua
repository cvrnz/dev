-- VS Code-style command palette for `:`. A modal lists every command, user and plugin ones
-- first (with their descriptions), then Neovim's built-in ones, filtered as you type.
--   Enter  runs the highlighted command. If what you typed is already a valid command line
--          (`w`, `e foo.txt`, `%s/a/b/g`, `10`) and you haven't moved the highlight off the top
--          result, it runs exactly that, so the palette does everything the plain command line did.
--   Tab    puts the highlighted command in the prompt, ready for arguments.
-- Commands go through the real command line, so history, `@:` and error messages work as usual.
local M = {}

local function commands()
  local list, seen = {}, {}
  local user = vim.api.nvim_get_commands({})
  local names = vim.tbl_keys(user)
  table.sort(names)
  for _, name in ipairs(names) do
    -- For Lua commands `definition` is the description; for Vimscript ones it's the code it
    -- runs, which isn't worth showing.
    local desc = user[name].callback and vim.trim(user[name].definition or "") or ""
    table.insert(list, { name = name, desc = desc })
    seen[name] = true
  end
  for _, name in ipairs(vim.fn.getcompletion("", "command")) do
    if not seen[name] then
      table.insert(list, { name = name, desc = "" })
    end
  end
  return list
end

local function run(text)
  if text ~= "" then
    -- "n": not remapped, so this `:` is the plain command line rather than the palette again.
    -- "t": as if typed, so it lands in the history and `@:` can repeat it.
    vim.api.nvim_feedkeys(":" .. text .. "\r", "nt", false)
  end
end

-- The full name of the command a prompt would run (`w` -> `write`), or nil.
local function resolve(prompt)
  local ok, parsed = pcall(vim.api.nvim_parse_cmd, prompt, {})
  return ok and parsed.cmd or nil
end

-- Fuzzy matching, but the command the typed text runs (`w` -> `write`) or names exactly comes
-- first, and names starting with the typed text come before other matches. Lower scores sort
-- first; -1 means no match.
local function sorter()
  local fuzzy = require("telescope.config").values.generic_sorter({})
  local score = fuzzy.scoring_function
  local last_prompt, resolved
  fuzzy.scoring_function = function(self, prompt, line, ...)
    if prompt ~= last_prompt then
      last_prompt, resolved = prompt, resolve(prompt)
    end
    if line == resolved then
      return 0
    end
    local base = score(self, prompt, line, ...)
    if base < 0 or prompt == "" then
      return base
    elseif line:lower() == prompt:lower() then
      return 0
    elseif vim.startswith(line:lower(), prompt:lower()) then
      return base / 1000
    end
    return base
  end
  return fuzzy
end

function M.open()
  local actions, state = require("telescope.actions"), require("telescope.actions.state")
  require("telescope.pickers")
    .new(require("telescope.themes").get_dropdown({
      previewer = false,
      -- 60% of the screen height (at least 20 rows), instead of the dropdown's ~15.
      layout_config = {
        height = function(_, _, max_lines)
          return math.min(max_lines, math.max(20, math.floor(max_lines * 0.6)))
        end,
      },
    }), {
      prompt_title = "Commands",
      finder = require("telescope.finders").new_table({
        results = commands(),
        entry_maker = function(cmd)
          return {
            value = cmd,
            ordinal = cmd.name,
            display = function()
              if cmd.desc == "" then
                return cmd.name
              end
              return cmd.name .. "  " .. cmd.desc, { { { #cmd.name + 2, #cmd.name + 2 + #cmd.desc }, "Comment" } }
            end,
          }
        end,
      }),
      sorter = sorter(),
      attach_mappings = function(prompt_buf, map)
        actions.select_default:replace(function()
          local picker = state.get_current_picker(prompt_buf)
          local typed = vim.trim(picker:_get_prompt())
          local entry = state.get_selected_entry()
          -- Before the results have loaded (Enter pressed straight after typing) there's no
          -- manager yet, so nothing can have moved.
          local moved = picker.manager and entry ~= picker.manager:iter()() or false
          local complete = typed ~= "" and resolve(typed) ~= nil
          actions.close(prompt_buf)
          local text = ((complete and not moved) or not entry) and typed or entry.value.name
          vim.schedule(function()
            run(text)
          end)
        end)
        map("i", "<Tab>", function()
          local entry = state.get_selected_entry()
          if entry then
            state.get_current_picker(prompt_buf):set_prompt(entry.value.name .. " ")
          end
        end)
        return true
      end,
    })
    :find()
end

return M
