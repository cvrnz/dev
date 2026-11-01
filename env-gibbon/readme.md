### Dev
My dev environments. Each `env-*` folder holds the setup for one environment, and `common/` holds the configs they all share.

```
common/        configs shared by every environment
env-gibbon/    gibbon: its own configs, scripts, container and Claude Code skills
env-wombat/    wombat (empty for now)
env-ocelot/    ocelot (empty for now)
```

### Common configs
In [`../common`](../common), shared by every environment.

| File | What it is |
|---|---|
| [`nvim/`](../common/nvim) | Neovim config, with the darq theme, a welcome screen, a command palette and a source control sidebar |
| [`starship.toml`](../common/starship.toml) | Starship prompt |
| [`tmux.conf`](../common/tmux.conf) | tmux config |
| [`keychron-keymap.json`](../common/keychron-keymap.json) | Keychron keyboard keymap |
| [`vimium.css`](../common/vimium.css) | Vimium browser extension styles |

### Gibbon
```
configs/     configs only gibbon uses
container/   dev-dockerfile for the dev container
scripts/     copy-configs.zsh, dev-setup.sh and the docker helper scripts
skills/      Claude Code skills
```

| Config | What it is |
|---|---|
| [`ghostty.conf`](configs/ghostty.conf) | Ghostty theme and app icon |
| [`karabiner.arrow-keys.json`](configs/karabiner.arrow-keys.json) | Karabiner-Elements rule: right command + h/j/k/l as arrow keys |
| [`vscode-keybindings.jsonc`](configs/vscode-keybindings.jsonc) | VS Code keybindings |
| [`vscode-settings.jsonc`](configs/vscode-settings.jsonc) | VS Code settings |
| [`zshrc.sh`](configs/zshrc.sh) | macOS `~/.zshrc`: env vars, PATH, fnm and the prompt |

### Copy configs
Interactive menu that copies the skills and the Neovim, starship, tmux and Ghostty configs onto the system (macOS and Linux, needs zsh). Anything already at a destination is moved to `~/.dev-backups/<timestamp>/` first, never deleted.
```sh
zsh env-gibbon/scripts/copy-configs.zsh
```

| Item | From | To |
|---|---|---|
| Skills | `env-gibbon/skills/*` | `~/.claude/skills/` |
| Neovim config | `common/nvim` | `~/.config/nvim` |
| Starship theme | `common/starship.toml` | `~/.config/starship.toml` |
| tmux config | `common/tmux.conf` | `~/.tmux.conf` if it exists, else `~/.config/tmux/tmux.conf` |
| Ghostty config | `env-gibbon/configs/ghostty.conf` | `~/.config/ghostty/config` |

The other configs (VS Code, Karabiner, Keychron, Vimium, zsh) are set up by hand in their apps.

### Container
An Ubuntu container with zsh, for running `dev-setup.sh`. The scripts work from any folder.

create image (built from the repo root, so it can include `common/`)
```bash
bash env-gibbon/scripts/create-image.sh
```

create container (named `dev0`, with ports 1776-1800 open)
```bash
bash env-gibbon/scripts/create-container.sh
```

connect to container
```bash
docker exec -it dev0 zsh
```

to install tools
```bash
bash /root/dev-setup.sh
```

`dev-setup.sh` is an interactive menu that installs apt packages, git, Starship, Neovim, tmux, Zellij, Gleam, fnm, Node, pnpm, Claude Code and the GitHub CLI, and sets up aliases and the zsh prompt. It copies the Neovim, Starship and tmux configs from `common/`, moving any old copy to `~/.dev-backups/<timestamp>/` first. It runs in the container or from the repo on any Ubuntu machine.

### Skills
Personal [Claude Code skills](https://docs.claude.com/en/docs/claude-code/skills), in [`skills/`](skills).

| Skill | What it does |
|---|---|
| [commit](skills/commit/SKILL.md) | Commits the relevant changed files using the repo's commit message pattern, one single-line commit per distinct change. |

Claude Code loads personal skills from `~/.claude/skills/`. Copy them there with the copy script.

Each skill is a folder with a `SKILL.md` (frontmatter with name and description, then instructions) and optional `scripts/` it runs.
