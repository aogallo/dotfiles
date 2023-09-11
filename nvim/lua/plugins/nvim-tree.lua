return {
  'nvim-tree/nvim-tree.lua',
  dependencies = {
    'nvim-tree/nvim-web-devicons'
  },
  keys = {
    {
      "<leader>e", ":NvimTreeToggle<CR>", desc = "Toggle tree"
    }
  },
  opts = {
    update_focused_file = {
      enable = true
    },
    renderer = {
      root_folder_label = ":t",
      icons = {
        glyphs = {
          folder = {
            -- arrow_closed = "", -- arrow when folder is closed
            arrow_closed = "",
            -- arrow_open = "", -- arrow when folder is open
            arrow_open = ""
          },
        },
      },
    },
    filters = {
      git_ignored = false,
      dotfiles = false,
      custom = {
        '^.env$'
      }
    },
    log = {
      enable = true,
      truncate = true,
      types = {
        all = false,
        config = false,
        copy_paste = true,
        dev = true,
        diagnostics = false,
        git = true,
        profile = false,
        watcher = false,
      }
    },
    actions = {
      open_file = {
        quit_on_open = false,
        resize_window = false,
        window_picker = {
          enable = true,
          picker = "default",
          chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
          exclude = {
            filetype = { "notify", "lazy", "qf", "diff", "fugitive", "fugitiveblame" },
            buftype = { "nofile", "terminal", "help" },
          },
        },
      }
    }
  }
}
