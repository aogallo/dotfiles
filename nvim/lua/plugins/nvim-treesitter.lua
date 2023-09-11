return {
  'nvim-treesitter/nvim-treesitter',
  event = 'VeryLazy',
  build = ":TSUpdate",
  main = "nvim-treesitter.configs",
  dependencies = {
    'nvim-treesitter/nvim-treesitter-textobjects',
    'HiPhish/nvim-ts-rainbow2',
    'windwp/nvim-autopairs',
    'windwp/nvim-ts-autotag'
  },
  opts = {
    ensure_installed = {
      "luadoc",
      "astro",
      "lua",
      "javascript",
      "css",
      "html",
      "python",
      "dockerfile",
      "dart",
      "dot",
      "json",
      "graphql",
      "yaml",
      "toml",
      "vim",
      "tsx",
      "bash",
      "sql",
      "gitignore",
      "typescript",
      "markdown",
      "markdown_inline"

    },
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
    indent = {
      enable = true
    },
    rainbow = {
      enable = true,
      extended_mode = false,
      max_file_lines = nil,
    },
    autotag = {
      enable = true
    },
    textobjects = {
      select = {
        enable = true,
        lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
        keymaps = {
          -- You can use the capture groups defined in textobjects.scm
          ['aa'] = '@parameter.outer',
          ['ia'] = '@parameter.inner',
          ['af'] = '@function.outer',
          ['if'] = '@function.inner',
          ['ac'] = '@class.outer',
          ['ic'] = '@class.inner',
        },
      },
      move = {
        enable = true,
        set_jumps = true, -- whether to set jumps in the jumplist
        goto_next_start = {
          [']m'] = '@function.outer',
          [']]'] = '@class.outer',
        },
        goto_next_end = {
          [']M'] = '@function.outer',
          [']['] = '@class.outer',
        },
        goto_previous_start = {
          ['[m'] = '@function.outer',
          ['[['] = '@class.outer',
        },
        goto_previous_end = {
          ['[M'] = '@function.outer',
          ['[]'] = '@class.outer',
        },
      },
      swap = {
        enable = true,
        swap_next = {
          ['<leader>a'] = '@parameter.inner',
        },
        swap_previous = {
          ['<leader>A'] = '@parameter.inner',
        },
      },
    },
  }
}
