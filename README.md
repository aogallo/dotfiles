# Files

## Tmux Configuration

For manage plugins in Tmux clone the following (repository)[https://github.com/tmux-plugins/tpm]

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
