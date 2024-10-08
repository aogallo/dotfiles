# Developer Environment Configurations

## Keyboard

### Iris Keyboard

#### Remapping each key

I use `Via Configurator`, you can follow this [Via Usage Guide](https://docs.keeb.io/via)

### Hombebrew

Install Hombebrew execute this command

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

For more information about Hombebrew you can visit this [web-site](https://brew.sh/)

## Font

I use the JetBrains Mono font

You can download [here](https://www.jetbrains.com/lp/mono/) the font. To install use the following instructions.

## iTerm2

Click [here](https://iterm2.com/) to read the documenation about `iterm2`

**NOTE**: change the key maps to `Natural Text Editing`

Go to Preferences -> Profile -> Keys -> Key Mappings

Click in `Presets` and choose `Natural Text Editing`

**Configure the font in iTerm2**

Go to Preferences -> Profile -> Text -> Font

Choose the `JetBrainsMono Nerd Font Mono` font and active the `Use ligatures` option.

## NVIM

Install nvim by brew

```bash
brew install nvim
```

For more information about Neovim you can visit this [neovim](https://neovim.io/)

## Tmux

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

I use dracula theme for tmux, to install the theme adding the following command in your `.tmux.conf` file:

```bash
set -g @plugin 'dracula/tmux'
```

## Create a symbolic link

```bash
ln -s ~/dotfiles/.config/nvim ~/.config
```

## Install Stylua formatter

This is the repository with all information about StyLua: [Stylua](https://github.com/JohnnyMorganz/StyLua)

To install Stylua with Homebew, run the following:

```bash
brew install stylua
```

[ripgrep](https://github.com/BurntSushi/ripgrep)

## Csharp language

Installing the lsp and formatter

```bash
dotnet tool install --global csharp-ls &&
dotnet tool install csharpier -g
```
