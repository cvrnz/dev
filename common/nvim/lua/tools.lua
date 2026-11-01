-- Command-line tools the config depends on, installed on first start so nobody has to think
-- about them. Each goes into Neovim's data folder (no admin rights needed), which is put on
-- Neovim's PATH. Downloads are official release builds, checked against their published SHA-256.
local M = {}

local is_windows = vim.fn.has("win32") == 1
local bin = vim.fs.joinpath(vim.fn.stdpath("data"), "bin")
vim.env.PATH = bin .. (is_windows and ";" or ":") .. vim.env.PATH

M.installing = {}

local ripgrep_version = "14.1.1"

-- The ripgrep release archive for this OS and CPU, or nil if there isn't one.
local function ripgrep_asset()
  local uname = vim.uv.os_uname()
  local arch = ({ x86_64 = "x86_64", amd64 = "x86_64", AMD64 = "x86_64", aarch64 = "aarch64", arm64 = "aarch64" })[uname.machine]
  local target = ({
    Linux = { x86_64 = "x86_64-unknown-linux-musl", aarch64 = "aarch64-unknown-linux-gnu" },
    Darwin = { x86_64 = "x86_64-apple-darwin", aarch64 = "aarch64-apple-darwin" },
    Windows_NT = { x86_64 = "x86_64-pc-windows-msvc" },
  })[uname.sysname]
  target = target and target[arch]
  if target then
    return "ripgrep-" .. ripgrep_version .. "-" .. target, is_windows and ".zip" or ".tar.gz"
  end
end

-- Run the steps in order; each is a command list, or a function returning an error or nil.
local function run(steps, done)
  local step = table.remove(steps, 1)
  if not step then
    return done(nil)
  end
  if type(step) == "function" then
    local err = step()
    return err and done(err) or run(steps, done)
  end
  vim.system(step, {}, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        return done(table.concat(step, " ") .. ": " .. vim.trim(result.stderr or ""))
      end
      run(steps, done)
    end)
  end)
end

function M.ensure_ripgrep()
  if vim.fn.executable("rg") == 1 then
    return
  end
  local name, ext = ripgrep_asset()
  if not name then
    vim.notify("No ripgrep build for this system; install rg to use search", vim.log.levels.WARN)
    return
  end
  local url = "https://github.com/BurntSushi/ripgrep/releases/download/" .. ripgrep_version .. "/" .. name .. ext
  local tmp = vim.fn.tempname()
  local archive = vim.fs.joinpath(tmp, name .. ext)
  local exe = is_windows and "rg.exe" or "rg"
  vim.fn.mkdir(tmp, "p")
  vim.fn.mkdir(bin, "p")
  M.installing.rg = true
  run({
    { "curl", "-fsSL", "-o", archive, url },
    { "curl", "-fsSL", "-o", archive .. ".sha256", url .. ".sha256" },
    function()
      local expected = vim.fn.readfile(archive .. ".sha256")[1]:match("^%x+")
      local file = assert(io.open(archive, "rb"))
      local actual = vim.fn.sha256(file:read("*a"))
      file:close()
      if actual ~= expected then
        return "checksum mismatch for " .. name .. ext
      end
    end,
    { "tar", "-xf", archive, "-C", tmp },
    function()
      local ok, err = vim.uv.fs_copyfile(vim.fs.joinpath(tmp, name, exe), vim.fs.joinpath(bin, exe))
      if not ok then
        return err
      end
      vim.uv.fs_chmod(vim.fs.joinpath(bin, exe), tonumber("755", 8))
    end,
  }, function(err)
    M.installing.rg = nil
    vim.fn.delete(tmp, "rf")
    if err then
      vim.notify("Couldn't install ripgrep: " .. err, vim.log.levels.ERROR)
    else
      vim.notify("Installed ripgrep " .. ripgrep_version .. " for search")
    end
  end)
end

-- ASCII art for the welcome screen: cowsay's creatures and a large collection of figlet
-- fonts. Each is a pinned GitHub archive, unpacked into Neovim's data folder. Failures are
-- quiet (the welcome screen has art of its own) and retried on the next start.
local art_sources = {
  {
    dir = "cowsay",
    url = "https://github.com/cowsay-org/cowsay/archive/refs/tags/v3.8.4.tar.gz",
    sha256 = "c15bc10712835d3a9bcda780dc9453362567bf48d1185905dc7ef2334d79aadd",
  },
  {
    dir = "figlet-fonts",
    url = "https://github.com/xero/figlet-fonts/archive/417429ef36ab039cbf192a4424c60aa23fc32de8.tar.gz",
    sha256 = "f52f7c20ccedc774594f7a9bd49a745e73797127bac83892e352e38cb744d148",
  },
}
M.art_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "welcome")

-- Calls done() after downloading any art that's missing (not at all if nothing was).
function M.ensure_art(done)
  for _, source in ipairs(art_sources) do
    local dest = vim.fs.joinpath(M.art_dir, source.dir)
    if vim.fn.isdirectory(dest) == 0 and not M.installing[source.dir] then
      M.installing[source.dir] = true
      local tmp = vim.fn.tempname()
      local archive = vim.fs.joinpath(tmp, "art.tar.gz")
      local part = dest .. ".part"
      vim.fn.mkdir(tmp, "p")
      vim.fn.delete(part, "rf")
      vim.fn.mkdir(part, "p")
      run({
        { "curl", "-fsSL", "-o", archive, source.url },
        function()
          local file = assert(io.open(archive, "rb"))
          local actual = vim.fn.sha256(file:read("*a"))
          file:close()
          if actual ~= source.sha256 then
            return "checksum mismatch for " .. source.url
          end
        end,
        { "tar", "-xzf", archive, "-C", part, "--strip-components=1" },
        function()
          local ok, err = vim.uv.fs_rename(part, dest)
          return not ok and err or nil
        end,
      }, function(err)
        M.installing[source.dir] = nil
        vim.fn.delete(tmp, "rf")
        if err then
          vim.fn.delete(part, "rf")
        else
          done()
        end
      end)
    end
  end
end

return M
