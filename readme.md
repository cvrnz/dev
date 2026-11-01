### Dev
My dev environments. Each `env-*` folder holds the setup for one environment, and `common/` holds the configs they all share.

```
common/        configs shared by every environment
env-gibbon/    gibbon: macOS and an Ubuntu dev container, with its own configs, scripts and Claude Code skills
env-wombat/    wombat: a Windows host with Git Bash, and a remote Linux dev workspace
```

### Common configs
In [`common/`](common), shared by every environment.

| File | What it is |
|---|---|
| [`nvim/`](common/nvim) | Neovim config, with the darq theme, a welcome screen, a command palette and a source control sidebar |
| [`starship.toml`](common/starship.toml) | Starship prompt |
| [`tmux.conf`](common/tmux.conf) | tmux config |
| [`keychron-keymap.json`](common/keychron-keymap.json) | Keychron keyboard keymap |
| [`vimium.css`](common/vimium.css) | Vimium browser extension styles |

### Environments
| Environment | Readme |
|---|---|
| gibbon | [`env-gibbon/readme.md`](env-gibbon/readme.md) |
| wombat | [`env-wombat/readme.md`](env-wombat/readme.md) |
