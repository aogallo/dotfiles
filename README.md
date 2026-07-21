# Developer Environment Configurations

## Contribution Workflow

Implementation commits must not go directly to `main`. Create a feature branch, commit the
work there with conventional commit messages, and submit it through a pull request linked to
the approved issue for the change. Before creating a pull request, verify whether the active
specification is related to the PR and ask whether that specification should be closed when
the PR completes the solution.

## Keyboard

### Iris Keyboard

The shared VIA configuration for the Iris Rev. 5 keyboard lives in
`keyboard/iris_rev__5.json`. See `keyboard/README.md` for validation and rollback guidance.

#### Remapping each key

I use `Via Configurator App`, you can follow this [Via Usage Guide](https://www.usevia.app/)
Also review the Via documentation [Via web site](https://docs.keeb.io/via)

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

## Ghosty

Other terminal option would be Ghosty, if you wnat to see images in neovim Ghosty is a good option. You can download it [here](https://ghostty.org/docs/install/binary#macos)

## NVIM

![neovim_logo](https://github.com/user-attachments/assets/61f55e5d-e434-4f5e-b986-b0ed7fe11a3c)


Install nvim by brew

```bash
brew install nvim
```

For more information about Neovim you can visit this [neovim](https://neovim.io/)

This repository's Neovim configuration is documented in `nvim/README.md`. Use that file for
validation, dependency checks, linking, local overrides, and rollback guidance.

## Tmux

### Tmux installation

To install tmux go to Installation section in this <a target="_blank" href="https://github.com/tmux/tmux#welcome-to-tmux">tmux repository</a>

This repository's tmux configuration is documented in `Tmux/README.md`. Use that file for
TPM setup, activation, reload, plugin behavior, validation, and rollback guidance.

## Create a symbolic link

See `nvim/README.md` for the safe Neovim linking workflow. It documents the dry-run path and
refuses to overwrite unmanaged local configuration by default.

## Zsh

The repository-managed zsh configuration lives in `zsh/`. See `zsh/README.md` for the current-machine inventory, local-only override boundaries, dependency validation, and future safe-linking expectations.

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

## Images in Neovim

I use `snacks/image` so the following are the requirements:

- Install ImageMagick

### Mac OS X

```bash
brew install imagemagick
```

```bash
brew install ghostscript
```
