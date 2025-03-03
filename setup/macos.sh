#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print section header
print_header() {
  echo -e "\n${BLUE}===== $1 =====${NC}\n"
}

# Print success message
print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

# Print error message
print_error() {
  echo -e "${RED}✗ $1${NC}"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check OS type
check_os() {
  print_header "Checking OS"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    print_success "macOS detected"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    print_success "Linux detected"

    # Check Linux distribution
    if [ -f /etc/debian_version ]; then
      DISTRO="debian"
      print_success "Debian/Ubuntu detected"
    elif [ -f /etc/fedora-release ]; then
      DISTRO="fedora"
      print_success "Fedora detected"
    elif [ -f /etc/arch-release ]; then
      DISTRO="arch"
      print_success "Arch Linux detected"
    else
      DISTRO="unknown"
      print_error "Unknown Linux distribution"
    fi
  else
    print_error "Unsupported OS: $OSTYPE"
    exit 1
  fi
}

# Install package manager and essential tools
install_package_manager() {
  print_header "Installing Package Manager and Essential Tools"

  if [[ "$OS" == "macos" ]]; then
    # Install Homebrew on macOS
    if ! command_exists brew; then
      echo "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      # Add Homebrew to PATH
      if [[ -f ~/.zshrc ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -f ~/.bashrc ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.bashrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      print_success "Homebrew installed"
    else
      print_success "Homebrew already installed"
    fi
  elif [[ "$OS" == "linux" ]]; then
    # Install package manager based on Linux distribution
    if [[ "$DISTRO" == "debian" ]]; then
      sudo apt update
      sudo apt install -y git curl wget
      print_success "Essential tools installed"
    elif [[ "$DISTRO" == "fedora" ]]; then
      sudo dnf update -y
      sudo dnf install -y git curl wget
      print_success "Essential tools installed"
    elif [[ "$DISTRO" == "arch" ]]; then
      sudo pacman -Syu --noconfirm
      sudo pacman -S --noconfirm git curl wget
      print_success "Essential tools installed"
    else
      print_error "Unable to install package manager for unknown distribution"
    fi
  fi
}

# Setup Git configuration
setup_git() {
  print_header "Setting up Git"

  if ! command_exists git; then
    if [[ "$OS" == "macos" ]]; then
      brew install git
    elif [[ "$OS" == "linux" ]]; then
      if [[ "$DISTRO" == "debian" ]]; then
        sudo apt install -y git
      elif [[ "$DISTRO" == "fedora" ]]; then
        sudo dnf install -y git
      elif [[ "$DISTRO" == "arch" ]]; then
        sudo pacman -S --noconfirm git
      fi
    fi
  fi

  # Prompt for Git configuration
  echo "Enter your Git username:"
  read git_username
  echo "Enter your Git email:"
  read git_email

  git config --global user.name "$git_username"
  git config --global user.email "$git_email"

  print_success "Git configured with username: $git_username and email: $git_email"
}

# Generate SSH key and add to GitHub
setup_ssh() {
  print_header "Setting up SSH for GitHub"

  if [[ ! -f ~/.ssh/id_ed25519 ]]; then
    echo "Enter your email for SSH key generation:"
    read ssh_email

    # Generate SSH key
    ssh-keygen -t ed25519 -C "$ssh_email" -f ~/.ssh/id_ed25519 -N ""

    # Start ssh-agent and add key
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519

    # Display public key
    echo "Here's your public SSH key:"
    cat ~/.ssh/id_ed25519.pub

    echo "Would you like to automatically add this key to GitHub? (y/n)"
    read add_to_github

    if [[ "$add_to_github" == "y" ]]; then
      if ! command_exists gh; then
        if [[ "$OS" == "macos" ]]; then
          brew install gh
        elif [[ "$OS" == "linux" ]]; then
          if [[ "$DISTRO" == "debian" ]]; then
            sudo apt install -y gh
          elif [[ "$DISTRO" == "fedora" ]]; then
            sudo dnf install -y gh
          elif [[ "$DISTRO" == "arch" ]]; then
            sudo pacman -S --noconfirm github-cli
          fi
        fi
      fi

      # Login to GitHub CLI
      echo "Please login to GitHub CLI:"
      gh auth login -s admin:public_key

      # Add SSH key to GitHub
      gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)-$(date +%Y-%m-%d)"
      print_success "SSH key added to GitHub"
    else
      echo "Please manually add your SSH key to GitHub at: https://github.com/settings/keys"
    fi
  else
    print_success "SSH key already exists"
  fi
}

# Clone dotfiles repository
clone_dotfiles() {
  print_header "Cloning Dotfiles Repository"

  dotfiles_repo="git@github.com:aogallo/dotfiles.git"

  # Create dotfiles directory
  mkdir -p ~/dotfiles

  # Clone repository
  if git clone "$dotfiles_repo" ~/dotfiles; then
    print_success "Dotfiles repository cloned successfully"
  else
    print_error "Failed to clone repository"
    exit 1
  fi
}

# Install tools (Neovim, tmux, etc.)
install_tools() {
  print_header "Installing Development Tools"

  if [[ "$OS" == "macos" ]]; then
    # macOS with Homebrew
    brew install neovim tmux imagemagick lazygit fzf ripgrep fd pngpaste stylua
    print_success "Neovim and tmux installed"
  elif [[ "$OS" == "linux" ]]; then
    if [[ "$DISTRO" == "debian" ]]; then
      sudo apt install -y neovim tmux
    elif [[ "$DISTRO" == "fedora" ]]; then
      sudo dnf install -y neovim tmux
    elif [[ "$DISTRO" == "arch" ]]; then
      sudo pacman -S --noconfirm neovim tmux
    fi
    print_success "Tools are installed"
  fi

  # Install additional tools based on user input
  echo "Would you like to install additional tools? (y/n)"
  read install_additional

  if [[ "$install_additional" == "y" ]]; then
    echo "Enter space-separated list of additional tools to install:"
    read -a additional_tools

    if [[ "$OS" == "macos" ]]; then
      brew install "${additional_tools[@]}"
    elif [[ "$OS" == "linux" ]]; then
      if [[ "$DISTRO" == "debian" ]]; then
        sudo apt install -y "${additional_tools[@]}"
      elif [[ "$DISTRO" == "fedora" ]]; then
        sudo dnf install -y "${additional_tools[@]}"
      elif [[ "$DISTRO" == "arch" ]]; then
        sudo pacman -S --noconfirm "${additional_tools[@]}"
      fi
    fi

    print_success "Additional tools installed: ${additional_tools[*]}"
  fi
}

# Symlink dotfiles
setup_dotfiles() {
  print_header "Symlinking Dotfiles"

  # Create backups directory
  mkdir -p ~/.dotfiles_backup

  # Handle common dotfiles
  for file in ~/dotfiles/.{bash_profile,bashrc,gitconfig,tmux.conf,zshrc}; do
    if [[ -f "$file" ]]; then
      filename=$(basename "$file")

      # Backup existing file if it exists
      if [[ -f ~/."$filename" ]]; then
        mv ~/."$filename" ~/.dotfiles_backup/
        print_success "Backed up existing $filename"
      fi

      # Create symlink
      ln -sf "$file" ~/."$filename"
      print_success "Linked $filename"
    fi
  done

  # Creating the .config directory
  mkdir -p ~/.config

  # Handle Lazyvim configuration
  if [[ -d ~/dotfiles/lazyvim ]]; then
    ln -sf ~/dotfiles/lazyvim ~/.config/
    print_success "Linked Lazyvim configuration"
  fi

  # Handle Neovim configuration
  if [[ -d ~/dotfiles/kickstart.nvim ]]; then
    # Backup existing Neovim config if it exists
    # if [[ -d ~/.config/nvim ]]; then
    #   mv ~/.config/nvim ~/.dotfiles_backup/
    #   print_success "Backed up existing Neovim configuration"
    # fi

    # Create symlink
    ln -sf ~/dotfiles/kickstart.nvim ~/.config/nvim
    print_success "Linked Neovim configuration"
  fi

  # Handle tmux configuration
  if [[ -d ~/dotfiles/.tmux ]]; then
    # Backup existing tmux directory if it exists
    if [[ -d ~/.tmux ]]; then
      mv ~/.tmux ~/.dotfiles_backup/
      print_success "Backed up existing tmux directory"
    fi

    # Create symlink
    ln -sf ~/dotfiles/Tmux/.tmux.conf ~/
    print_success "Linked tmux file"
  fi
}

# Run custom install script if it exists
run_install_script() {
  print_header "Running Custom Install Script"

  if [[ -f ~/dotfiles/install.sh ]]; then
    chmod +x ~/dotfiles/install.sh
    ~/dotfiles/install.sh
    print_success "Custom install script executed"
  else
    echo "No custom install script found"
  fi
}

# Main function
main() {
  print_header "Starting Dotfiles Setup"

  check_os
  install_package_manager
  setup_git
  setup_ssh
  clone_dotfiles
  install_tools
  setup_dotfiles
  run_install_script

  print_header "Setup Complete!"
  echo "You may need to restart your terminal for all changes to take effect."
}

# Run main function
main
