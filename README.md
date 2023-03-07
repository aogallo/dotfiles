# Files

## Tmux Configuration

### Tmux installation
To install tmux go to Installation section in this <a target="_blank" href="https://github.com/tmux/tmux#welcome-to-tmux">tmux repository</a>

### Tmux plugins
  For manage plugins in Tmux clone the following <a target="_blank" href="https://github.com/tmux-plugins/tpm">tmux-plugins repository</a>

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Add the following configuration to your `.tmux.conf` file

```zsh
set -g @plugin 'tmux-plugins/tpm'
```

### Tmux Theme

I use dracula them for tmux, add the following command in your `.tmux.conf` file:

```bash
set -g @plugin 'dracula/tmux'
```
