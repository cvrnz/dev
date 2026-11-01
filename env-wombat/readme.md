### Wombat
A Windows host running Git Bash, connected to a remote Linux dev workspace. It also uses the shared configs in [`../common`](../common).

```
common/   configs used on both the host and the remote
host/     configs for the Windows host
remote/   configs for the remote Linux workspace
```

### Common
| Config | What it is |
|---|---|
| [`copilot.settings.json`](common/copilot.settings.json) | GitHub Copilot CLI settings: theme, model and effort level |

### Host
| Config | What it is |
|---|---|
| [`bashrc.sh`](host/bashrc.sh) | Git Bash `~/.bashrc`: fast nvm loading, aliases, the prompt, Neovim (MSYS2) and Starship on PATH |
| [`bash_profile.sh`](host/bash_profile.sh) | Git Bash `~/.bash_profile`, sources `~/.profile` and `~/.bashrc` |
| [`powertoys.json`](host/powertoys.json) | PowerToys Keyboard Manager: left alt + key (and left alt + shift + key) remapped to ctrl, for macOS-style shortcuts |
| [`vscode-settings.jsonc`](host/vscode-settings.jsonc) | VS Code settings |
| [`windows-terminal.json`](host/windows-terminal.json) | Windows Terminal settings, keybindings and profiles |

### Remote
| Config | What it is |
|---|---|
| [`bashrc.sh`](remote/bashrc.sh) | `~/.bashrc`: PATH, the prompt, vi mode, Starship (toggle with `toggle-starship`), fnm, .NET, ODBC and git aliases |
| [`vscode-keybindings.jsonc`](remote/vscode-keybindings.jsonc) | VS Code keybindings |

There is no copy script yet, so these are set up by hand in their apps.
