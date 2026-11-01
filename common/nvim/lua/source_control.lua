-- VS Code-style source control tab. A sidebar on the left has two tabs: Repos (every git repo
-- around the working directory, with its branch and whether it has changes) and Changes (the
-- selected repo's changed files). Moving through Changes shows a side-by-side diff on the right.
local M = {}

local ns = vim.api.nvim_create_namespace("source_control")

local function git(repo, args)
  local result = vim.system(vim.list_extend({ "git", "-C", repo }, args), { text = true }):wait()
  return result.code == 0, result.stdout or ""
end

-- Repos at or above the working directory, plus any below it (a few levels deep).
local function find_repos()
  local cwd = vim.fn.getcwd()
  local repos = {}
  local above = vim.fs.root(cwd, ".git")
  if above then
    table.insert(repos, above)
  end
  for path in vim.fs.dir(cwd, {
    depth = 4,
    skip = function(dir)
      local name = vim.fs.basename(dir)
      return name ~= ".git" and name ~= "node_modules"
    end,
  }) do
    if vim.fs.basename(path) == ".git" then
      local repo = vim.fs.joinpath(cwd, vim.fs.dirname(path))
      if repo ~= above then
        table.insert(repos, vim.fs.normalize(repo))
      end
    end
  end
  return repos
end

-- Changed files from `git status`, as { status = "M", path = "...", old = "..." }.
local function changes(repo)
  local _, out = git(repo, { "status", "--porcelain=v1", "-z", "--untracked-files=all" })
  local list, fields = {}, vim.split(out, "\0", { trimempty = true })
  local i = 1
  while i <= #fields do
    local xy, path = fields[i]:sub(1, 2), fields[i]:sub(4)
    local change = { path = path, status = xy == "??" and "U" or vim.trim(xy):sub(1, 1) }
    if xy:find("[RC]") then
      i = i + 1
      change.old = fields[i]
    end
    table.insert(list, change)
    i = i + 1
  end
  table.sort(list, function(a, b)
    return a.path < b.path
  end)
  return list
end

local function branch(repo)
  local _, name = git(repo, { "branch", "--show-current" })
  name = vim.trim(name)
  if name ~= "" then
    return name
  end
  local _, sha = git(repo, { "rev-parse", "--short", "HEAD" })
  return "detached at " .. vim.trim(sha)
end

-- Commits to push and to pull: how far the branch is ahead of and behind its upstream, as of
-- the last fetch. Nil for a branch with no upstream.
local function sync(repo)
  local ok, out = git(repo, { "rev-list", "--left-right", "--count", "HEAD...@{upstream}" })
  local ahead, behind = out:match("(%d+)%s+(%d+)")
  if ok and ahead then
    return { ahead = tonumber(ahead), behind = tonumber(behind) }
  end
end

-- The first remote, which a branch with no upstream is published to; nil if there's none.
local function remote(repo)
  local _, out = git(repo, { "remote" })
  return out:match("[^\n]+")
end

-- "↓2 ↑1": commits to pull and push, leaving out a direction with none.
local function arrows(counts)
  local parts = {}
  if counts and counts.behind > 0 then
    table.insert(parts, "↓" .. counts.behind)
  end
  if counts and counts.ahead > 0 then
    table.insert(parts, "↑" .. counts.ahead)
  end
  return table.concat(parts, " ")
end

-- Talking to remotes never prompts: a remote that needs a password or an unknown host key
-- just fails, rather than waiting on input nobody can type.
local function quiet_env()
  local env = { GIT_TERMINAL_PROMPT = "0" }
  if not vim.env.GIT_SSH_COMMAND then
    env.GIT_SSH_COMMAND = "ssh -o BatchMode=yes"
  end
  return env
end

-- Fetch in the background so the pull count is current, at most once a minute per repo
-- (any time when `force` is set).
local last_fetch = {}
local function fetch(repo, done, force)
  if not force and last_fetch[repo] and vim.uv.now() - last_fetch[repo] < 60000 then
    return
  end
  last_fetch[repo] = vim.uv.now()
  vim.system({ "git", "-C", repo, "fetch", "--quiet", "--no-tags" }, { env = quiet_env() }, function(result)
    if result.code == 0 then
      vim.schedule(done)
    end
  end)
end

-- The file's lines at the last commit and in the working tree, for a side-by-side diff.
local function versions(repo, change)
  local function lines(text)
    if text:find("\0", 1, true) then
      return { "(binary file)" }
    end
    return vim.split(text, "\n", { trimempty = true })
  end
  local old, new = {}, {}
  local has_head = git(repo, { "rev-parse", "--verify", "--quiet", "HEAD" })
  if has_head and change.status ~= "U" and change.status ~= "A" then
    local _, out = git(repo, { "show", "HEAD:" .. (change.old or change.path) })
    old = lines(out)
  end
  local file = io.open(vim.fs.joinpath(repo, change.path), "rb")
  if file and change.status ~= "D" then
    new = lines(file:read("*a"))
  end
  if file then
    file:close()
  end
  return old, new
end

local function scratch()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].modifiable = false
  vim.b[buf].source_control = true
  return buf
end

-- Replace a buffer's lines; highlights are { line, start_col, end_col, group } (0-based bytes).
local function render(buf, lines, highlights)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, hl in ipairs(highlights or {}) do
    vim.api.nvim_buf_set_extmark(buf, ns, hl[1], hl[2], { end_col = hl[3], hl_group = hl[4] })
  end
end

local status_colors = {
  M = "DiagnosticWarn",
  R = "DiagnosticInfo",
  C = "DiagnosticInfo",
  A = "DiagnosticOk",
  U = "DiagnosticOk",
  D = "DiagnosticError",
}

local function open()
  local cwd = vim.fn.getcwd()
  vim.cmd("tabnew")
  local tab = vim.api.nvim_get_current_tabpage()
  local side_win, repos_buf, changes_buf = vim.api.nvim_get_current_win(), scratch(), scratch()
  vim.api.nvim_win_set_buf(side_win, repos_buf)
  vim.cmd("rightbelow vsplit")
  local old_win, old_buf = vim.api.nvim_get_current_win(), scratch()
  vim.b[old_buf].source_control_diff = true
  vim.api.nvim_win_set_buf(old_win, old_buf)
  vim.cmd("rightbelow vsplit")
  local new_win, new_buf = vim.api.nvim_get_current_win(), scratch()
  vim.b[new_buf].source_control_diff = true
  vim.api.nvim_win_set_buf(new_win, new_buf)
  for _, win in ipairs({ old_win, new_win }) do
    vim.api.nvim_win_call(win, function()
      vim.cmd("diffthis")
    end)
    vim.wo[win].foldcolumn = "0"
  end
  vim.api.nvim_set_current_win(side_win)
  vim.wo[side_win].cursorline = true
  vim.wo[side_win].number = false
  vim.wo[side_win].wrap = false

  -- Size the sidebar to its widest line (both lists), up to half the screen, and split the
  -- rest evenly between the two sides of the diff.
  local function fit()
    local width = 0
    for _, buf in ipairs({ repos_buf, changes_buf }) do
      for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        width = math.max(width, vim.fn.strdisplaywidth(line))
      end
    end
    width = math.min(width + 1, math.floor(vim.o.columns / 2))
    vim.api.nvim_win_set_width(side_win, width)
    vim.api.nvim_win_set_width(old_win, math.floor((vim.o.columns - width - 2) / 2))
  end

  local repos, repo, files, shown, view = {}, nil, {}, nil, "repos"

  -- Each sidebar list starts with its tab row ("Repos  Changes", the current one highlighted)
  -- and a blank line, under the same blank row as every other page. Only rows with something
  -- on them (a repo, a file, the sync button) can hold the cursor: items maps those rows to
  -- what's on them, and the cursor skips the rest.
  local items = { [repos_buf] = {}, [changes_buf] = {} }
  local function sidebar(buf, which, rows)
    local lines = { " Repos   Changes ", "" }
    local highlights = {
      { 0, 0, 7, which == "repos" and "TabLineSel" or "TabLine" },
      { 0, 8, 17, which == "changes" and "TabLineSel" or "TabLine" },
    }
    local map = {}
    for _, row in ipairs(rows) do
      table.insert(lines, row[1])
      for _, hl in ipairs(row[2] or {}) do
        -- An end of -1 means the end of the line.
        table.insert(highlights, { #lines - 1, hl[1], hl[2] == -1 and #row[1] or hl[2], hl[3] })
      end
      map[#lines] = row.item
    end
    items[buf] = map
    render(buf, lines, highlights)
  end
  local function entry()
    local buf = vim.api.nvim_win_get_buf(side_win)
    return items[buf][vim.api.nvim_win_get_cursor(side_win)[1]] or {}
  end
  local function row_of(buf, test)
    local rows = vim.tbl_keys(items[buf])
    table.sort(rows)
    for _, row in ipairs(rows) do
      if test(items[buf][row]) then
        return row
      end
    end
  end
  -- Keep the cursor on an item, moving on in the direction it was going.
  local last_row = {}
  local function snap()
    local buf = vim.api.nvim_win_get_buf(side_win)
    local row = vim.api.nvim_win_get_cursor(side_win)[1]
    if not items[buf][row] then
      local step = row < (last_row[buf] or 0) and -1 or 1
      for _, dir in ipairs({ step, -step }) do
        local r = row + dir
        while r >= 1 and r <= vim.api.nvim_buf_line_count(buf) and not items[buf][r] do
          r = r + dir
        end
        if items[buf][r] then
          row = r
          vim.api.nvim_win_set_cursor(side_win, { row, 0 })
          break
        end
      end
    end
    last_row[buf] = row
  end

  local function show_diff()
    local change = view == "changes" and entry().change or nil
    if change == shown or not vim.api.nvim_win_is_valid(new_win) then
      return
    end
    shown = change
    local old, new = {}, {}
    if change then
      old, new = versions(repo.path, change)
    end
    local ft = change and vim.filetype.match({ filename = change.path }) or ""
    -- Same leading blank lines as the sidebar, so both sides line up with its list.
    for _, side in ipairs({ { old_buf, old }, { new_buf, new } }) do
      render(side[1], change and { "", "", unpack(side[2]) } or {})
      vim.bo[side[1]].filetype = ft
    end
    -- Each side is labelled in the row above it.
    local function label(text)
      return change and "%#Comment# " .. text:gsub("%%", "%%%%") or " "
    end
    vim.wo[old_win].winbar = label((change and (change.old or change.path) or "") .. "  (last commit)")
    vim.wo[new_win].winbar = label((change and change.path or "") .. "  (working tree)")
    vim.api.nvim_win_call(new_win, function()
      vim.cmd("diffupdate")
    end)
  end

  -- Repos tab: "● name  branch  3" for a repo with 3 changes, "  name  branch" for a clean one.
  -- The status bar shows the selected repo, its branch and commits to pull and push.
  local function label_repo()
    local label = repo and vim.trim(repo.name .. "  " .. repo.branch .. "  " .. arrows(repo.sync)) or "Source Control"
    vim.api.nvim_tabpage_set_var(tab, "source_control_repo", label)
  end

  local function render_repos()
    local width = 0
    for _, r in ipairs(repos) do
      width = math.max(width, #r.name)
    end
    local rows = {}
    for _, r in ipairs(repos) do
      local dot = r.count > 0 and "●" or " "
      local name = r.name .. string.rep(" ", width - #r.name)
      local line = dot .. " " .. name .. "  " .. r.branch
      local name_col, branch_col = #dot + 1, #dot + 1 + #name + 2
      local hls = { { 0, #dot, "DiagnosticWarn" }, { branch_col, #line, "Comment" } }
      if repo and r.path == repo.path then
        table.insert(hls, { name_col, name_col + #r.name, "Title" })
      end
      -- Commits to pull and push, in the text color so they stand out from the branch.
      if arrows(r.sync) ~= "" then
        line = line .. "  " .. arrows(r.sync)
      end
      if r.count > 0 then
        line = line .. "  " .. r.count
        table.insert(hls, { #line - #tostring(r.count), #line, "DiagnosticWarn" })
      end
      table.insert(rows, { line, hls, item = { repo = r } })
    end
    if #rows == 0 then
      rows = { { "No git repos in " .. vim.fn.fnamemodify(cwd, ":~"), { { 0, -1, "Comment" } } } }
    end
    sidebar(repos_buf, "repos", rows)
  end

  -- The sync button at the top of Changes, like VS Code's: what Enter will do (pull, push,
  -- both, or publish a branch with no upstream), a spinner while it runs, then how it went.
  local busy -- { repo, verb, frame } while running; { repo, text, group } for a moment after
  local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local function plural(n, word)
    return n .. " " .. word .. (n == 1 and "" or "s")
  end
  -- Pull as the repo is configured to; with nothing configured, git refuses to pull diverged
  -- branches, so merge then (VS Code's default too).
  local function pull()
    local rebase = git(repo.path, { "config", "pull.rebase" })
    local ff = git(repo.path, { "config", "pull.ff" })
    return (rebase or ff) and { "pull", "--no-edit" } or { "pull", "--no-edit", "--no-rebase" }
  end
  local function sync_action()
    local s = repo.sync
    if not s then
      return repo.remote and { label = "↑ Publish branch", verb = "Publishing", done = "Published",
        steps = { { "push", "--set-upstream", repo.remote, "HEAD" } } }
    elseif s.behind > 0 and s.ahead > 0 then
      return { label = "⇅ Sync changes  " .. arrows(s), verb = "Syncing", done = "Synced",
        steps = { pull(), { "push" } } }
    elseif s.behind > 0 then
      return { label = "↓ Pull " .. plural(s.behind, "commit"), verb = "Pulling", done = "Pulled",
        steps = { pull() } }
    elseif s.ahead > 0 then
      return { label = "↑ Push " .. plural(s.ahead, "commit"), verb = "Pushing", done = "Pushed",
        steps = { { "push" } } }
    end
    -- Nothing to do: Enter checks the remote for new commits.
    return { label = "✓ Up to date", verb = "Checking", done = "Up to date", dim = true, fetch = true }
  end
  local function sync_row()
    if busy and busy.repo == repo.path then
      if busy.verb then
        local text = spinner[busy.frame % #spinner + 1] .. " " .. busy.verb .. "…"
        return { text, { { 0, -1, "Comment" } }, item = { sync = true } }
      end
      return { busy.text, { { 0, -1, busy.group } }, item = { sync = true } }
    end
    local action = sync_action()
    if action then
      return { action.label, action.dim and { { 0, -1, "Comment" } } or {}, item = { sync = true } }
    end
  end

  local function render_changes()
    if not repo then
      sidebar(changes_buf, "changes", { { "Pick a repo in Repos", { { 0, -1, "Comment" } } } })
      return
    end
    local rows = {}
    local button = sync_row()
    if button then
      table.insert(rows, button)
      table.insert(rows, { "" })
    end
    for _, change in ipairs(files) do
      table.insert(rows, {
        change.status .. "  " .. change.path,
        { { 0, 1, status_colors[change.status] or "DiagnosticWarn" } },
        item = { change = change },
      })
    end
    if #files == 0 then
      table.insert(rows, { "No changes", { { 0, -1, "Comment" } } })
    end
    sidebar(changes_buf, "changes", rows)
  end

  local function refresh()
    repos = vim.tbl_map(function(path)
      local name = vim.fs.relpath(cwd, path) or vim.fn.fnamemodify(path, ":~")
      return {
        path = path,
        name = name == "." and vim.fs.basename(path) or name,
        branch = branch(path),
        sync = sync(path),
        remote = remote(path),
        count = #changes(path),
      }
    end, find_repos())
    for _, r in ipairs(repos) do
      if r.sync then
        fetch(r.path, function()
          if vim.api.nvim_buf_is_valid(repos_buf) then
            r.sync = sync(r.path)
            render_repos()
            fit()
            label_repo()
          end
        end)
      end
    end
    if repo then
      for _, r in ipairs(repos) do
        if r.path == repo.path then
          repo = r
        end
      end
      files = changes(repo.path)
    end
    shown = nil
    label_repo()
    render_repos()
    render_changes()
    fit()
    show_diff()
  end

  local function show(which)
    view = which
    vim.api.nvim_win_set_buf(side_win, view == "repos" and repos_buf or changes_buf)
    snap()
    label_repo()
    shown = nil
    show_diff()
  end

  local function select_repo()
    local r = entry().repo
    if not r then
      return
    end
    repo, files = r, changes(r.path)
    render_repos()
    render_changes()
    fit()
    show("changes")
    -- Start on the first changed file (or the sync button when nothing has changed).
    local row = row_of(changes_buf, function(item)
      return item.change ~= nil
    end) or row_of(changes_buf, function()
      return true
    end)
    if row then
      vim.api.nvim_win_set_cursor(side_win, { row, 0 })
      last_row[changes_buf] = row
    end
    show_diff()
  end

  -- Run the sync button's action: its git commands in turn, with the spinner going.
  local function run_sync()
    if not repo or (busy and busy.verb) then
      return
    end
    local action = sync_action()
    if not action then
      return
    end
    local target = repo
    busy = { repo = target.path, verb = action.verb, frame = 0 }
    local timer = vim.uv.new_timer()
    timer:start(0, 80, vim.schedule_wrap(function()
      if not vim.api.nvim_buf_is_valid(changes_buf) then
        timer:stop()
        return
      end
      busy.frame = (busy.frame or 0) + 1
      render_changes()
    end))
    local function finish(err)
      timer:stop()
      timer:close()
      if not vim.api.nvim_buf_is_valid(changes_buf) then
        return
      end
      if err then
        busy = { repo = target.path, text = "✕ " .. action.verb:gsub("ing$", "") .. " failed", group = "DiagnosticError" }
        vim.notify(err, vim.log.levels.ERROR)
      else
        busy = { repo = target.path, text = "✓ " .. action.done, group = "DiagnosticOk" }
      end
      refresh()
      local shown_busy = busy
      vim.defer_fn(function()
        if busy == shown_busy and vim.api.nvim_buf_is_valid(changes_buf) then
          busy = nil
          render_changes()
          fit()
        end
      end, err and 4000 or 2500)
    end
    if action.fetch then
      vim.system({ "git", "-C", target.path, "fetch", "--quiet", "--no-tags" }, { env = quiet_env(), text = true },
        function(result)
          vim.schedule(function()
            last_fetch[target.path] = vim.uv.now()
            finish(result.code ~= 0 and vim.trim(result.stderr or "") or nil)
          end)
        end)
      return
    end
    local steps = vim.deepcopy(action.steps)
    local function next_step()
      local args = table.remove(steps, 1)
      if not args then
        return finish(nil)
      end
      local cmd = vim.list_extend({ "git", "-C", target.path }, args)
      vim.system(cmd, { env = quiet_env(), text = true }, function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            finish("git " .. table.concat(args, " ") .. ": " .. vim.trim((result.stderr or "") .. (result.stdout or "")))
          else
            next_step()
          end
        end)
      end)
    end
    next_step()
  end

  for _, buf in ipairs({ repos_buf, changes_buf }) do
    vim.keymap.set("n", "<Tab>", function()
      show(view == "repos" and "changes" or "repos")
    end, { buffer = buf, desc = "Switch between Repos and Changes" })
    -- Pick up edits made elsewhere when coming back to the sidebar.
    vim.api.nvim_create_autocmd("FocusGained", { buffer = buf, callback = refresh })
  end
  -- Clicking "Repos" or "Changes" in the tab row switches to it; other clicks work as usual.
  for _, buf in ipairs({ repos_buf, changes_buf }) do
    vim.keymap.set("n", "<LeftMouse>", function()
      local mouse = vim.fn.getmousepos()
      if mouse.winid == side_win and mouse.line == 1 and mouse.column <= 17 then
        vim.schedule(function()
          show(mouse.column <= 7 and "repos" or "changes")
        end)
        return ""
      end
      return "<LeftMouse>"
    end, { buffer = buf, expr = true, desc = "Switch sidebar tab" })
  end
  for _, lhs in ipairs({ "<CR>", "<2-LeftMouse>" }) do
    vim.keymap.set("n", lhs, select_repo, { buffer = repos_buf, desc = "Show this repo's changes" })
    vim.keymap.set("n", lhs, function()
      if entry().sync then
        run_sync()
      end
    end, { buffer = changes_buf, desc = "Pull and push" })
  end
  vim.api.nvim_create_autocmd("CursorMoved", { buffer = repos_buf, callback = snap })
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = changes_buf,
    callback = function()
      snap()
      show_diff()
    end,
  })

  -- The sidebar's buffers stay hidden while switching tabs, so clean them up with the tab.
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(side_win),
    once = true,
    callback = function()
      vim.schedule(function()
        for _, buf in ipairs({ repos_buf, changes_buf, old_buf, new_buf }) do
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end
      end)
    end,
  })

  refresh()
  -- Start on the repo Neovim was opened in, if any; otherwise on the repo list.
  local root = vim.fs.root(cwd, ".git")
  for _, r in ipairs(repos) do
    if root and r.path == vim.fs.normalize(root) then
      vim.api.nvim_win_set_cursor(side_win, { row_of(repos_buf, function(item)
        return item.repo == r
      end), 0 })
      select_repo()
      return
    end
  end
  show("repos")
end

-- Each call opens a new source control tab, so several can be open at once.
M.open = open

return M
