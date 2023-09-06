-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

--[[
 THESE ARE EXAMPLE CONFIGS FEEL FREE TO CHANGE TO WHATEVER YOU WANT
 `lvim` is the global options object
]]
-- vim options
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.relativenumber = true

-- general
lvim.log.level = "info"
lvim.format_on_save = {
  enabled = true,
  -- pattern = { "*.lua" },
  timeout = 1000,
}
-- to disable icons and use a minimalist setup, uncomment the following
-- lvim.use_icons = false

-- keymappings <https://www.lunarvim.org/docs/configuration/keybindings>
lvim.leader = "space"
-- add your own keymapping
lvim.keys.normal_mode["<C-s>"] = ":w<cr>"
lvim.keys.insert_mode["jk"] = "<ESC>"
lvim.keys.insert_mode["JK"] = "<ESC>"
-- X closes a buffer
lvim.keys.normal_mode["<S-x>"] = ":BufferKill<CR>"

-- Centers cursor when moving 1/2 page down
lvim.keys.normal_mode["<C-d>"] = "<C-d>zz"

lvim.lsp.buffer_mappings.normal_mode["<leader>c"] = nil

lvim.keys.normal_mode["<leader>x"] = ":bdelete<cr>"

lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"
lvim.builtin.terminal.open_mapping = "<c-t>"

-- TroubleToggle
lvim.keys.normal_mode["<leader>dt"] = ":TroubleToggle<CR>"
-- lvim.keys.normal_mode["<leader>mp"] = ":MarkdownPreview<CR>"
-- lvim.keys.normal_mode["<leader>ms"] = ":MarkdownPreviewStop<CR>"
-- lvim.keys.normal_mode["<leader>mt"] = ":MarkdownPreviewToggle<CR>"

lvim.builtin.which_key.mappings["m"] = {
  name = '+Markdown',
  p = { ":MarkdownPreview<CR>" },
  s = { ":MarkdownPreviewStop<CR>" },
  t = { ":MarkdownPreviewToggle<CR>" }
}


-- -- Use which-key to add extra bindings with the leader-key prefix
-- lvim.builtin.which_key.mappings["W"] = { "<cmd>noautocmd w<cr>", "Save without formatting" }
-- lvim.builtin.which_key.mappings["P"] = { "<cmd>Telescope projects<CR>", "Projects" }
lvim.builtin.which_key.mappings["t"] = {
  name = "+Terminal",
  f = { "<cmd>ToggleTerm<cr>", "Floating terminal" },
  v = { "<cmd>2ToggleTerm size=30 direction=vertical<cr>", "Split vertical" },
  h = { "<cmd>2ToggleTerm size=30 direction=horizontal<cr>", "Split horizontal" },
}


-- -- Change theme settings
-- lvim.colorscheme = "lunar"

lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = true
-- lvim.builtin.nvimtree.setup.update_focused_file.enable = false
lvim.builtin.nvimtree.setup.update_focused_file.update_root = false
lvim.builtin.nvimtree.setup.actions.change_dir.enable = false
lvim.builtin.nvimtree.setup.actions.change_dir.global = false

-- Automatically install missing parsers when entering buffer
lvim.builtin.treesitter.auto_install = true
lvim.builtin.treesitter.rainbow.enable = true


-- lvim.builtin.treesitter.ignore_install = { "haskell" }

-- -- always installed on startup, useful for parsers without a strict filetype
-- lvim.builtin.treesitter.ensure_installed = { "comment", "markdown_inline", "regex" }

-- -- generic LSP settings <https://www.lunarvim.org/docs/languages#lsp-support>

-- --- disable automatic installation of servers
-- lvim.lsp.installer.setup.automatic_installation = false

-- ---configure a server manually. IMPORTANT: Requires `:LvimCacheReset` to take effect
-- ---see the full default list `:lua =lvim.lsp.automatic_configuration.skipped_servers`
-- vim.list_extend(lvim.lsp.automatic_configuration.skipped_servers, { "pyright" })
-- check the lspconfig documentation for a list of all possible options
-- local opts = {}
-- require("lvim.lsp.manager").setup("eslint_d", opts)

-- ---remove a server from the skipped list, e.g. eslint, or emmet_ls. IMPORTANT: Requires `:LvimCacheReset` to take effect
-- ---`:LvimInfo` lists which server(s) are skipped for the current filetype
-- lvim.lsp.automatic_configuration.skipped_servers = vim.tbl_filter(function(server)
--   return server ~= "emmet_ls"
-- end, lvim.lsp.automatic_configuration.skipped_servers)

-- -- you can set a custom on_attach function that will be used for all the language servers
-- -- See <https://github.com/neovim/nvim-lspconfig#keybindings-and-completion>
-- lvim.lsp.on_attach_callback = function(client, bufnr)
--   local function buf_set_option(...)
--     vim.api.nvim_buf_set_option(bufnr, ...)
--   end
--   --Enable completion triggered by <c-x><c-o>
--   buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")
-- end

local linters = require "lvim.lsp.null-ls.linters"

-- linters and formatters <https://www.lunarvim.org/docs/languages#lintingformatting>
linters.setup {
  { name = "eslint", filetype = { "typescript", "typescriptreact", "javascriptreact", "javascript" } }
}

local code_actions = require "lvim.lsp.null-ls.code_actions"
code_actions.setup {
  {
    name = "proselint",
  },
}

local formatters = require("lvim.lsp.null-ls.formatters")
formatters.setup {
  {
    name = "black"
  },
  {
    command = "prettier",
    args = {
      "--no-semi",
      "--single-quote",
      "--jsx-single-quote"
    },
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "css", "scss", "yaml", "yml" },
  },
  {
    command = "prettier",
    filetypes = { "scss" },
  },
}
-- -- Additional Plugins <https://www.lunarvim.org/docs/plugins#user-plugins>
lvim.plugins = {
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  {
    "nacro90/numb.nvim",
    event = "BufRead",
    config = function()
      require("numb").setup {
        show_numbers = true,    -- Enable 'number' for the window while peeking
        show_cursorline = true, -- Enable 'cursorline' for the window while peeking
      }
    end,
  },
  {
    "f-person/git-blame.nvim",
    event = "BufRead",
    config = function()
      vim.cmd "highlight default link gitblame SpecialComment"
      vim.g.gitblame_enabled = 0
    end,
  },
  {
    "tpope/vim-fugitive",
    cmd = {
      "G",
      "Git",
      "Gdiffsplit",
      "Gread",
      "Gwrite",
      "Ggrep",
      "GMove",
      "GDelete",
      "GBrowse",
      "GRemove",
      "GRename",
      "Glgrep",
      "Gedit"
    },
    ft = { "fugitive" }
  },
  {
    "mrjones2014/nvim-ts-rainbow",
  },
  {
    "folke/todo-comments.nvim",
    event = "BufRead",
    config = function()
      require("todo-comments").setup()
    end,
  },
  {
    "kylechui/nvim-surround",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- Configuration here, or leave empty to use defaults
      })
    end

  },
  {
    "windwp/nvim-ts-autotag"
  },
  {
    'mattn/emmet-vim'
  },
  {
    "tpope/vim-surround",

    -- make sure to change the value of `timeoutlen` if it's not triggering correctly, see https://github.com/tpope/vim-surround/issues/117
    -- setup = function()
    --  vim.o.timeoutlen = 500
    -- end
  },
  {
    "mxsdev/nvim-dap-vscode-js",
  },
  {
    "sindrets/diffview.nvim",
    event = "BufRead"
  },
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && npm install",
    ft = "markdown",
    config = function()
      vim.g.mkdp_auto_start = 1
    end,
  },
  --preview color
  {
    'brenoprata10/nvim-highlight-colors'
  },
}



--vim-surround configuration
vim.o.timeoutlen = 500

-- -- Autocommands (`:help autocmd`) <https://neovim.io/doc/user/autocmd.html>
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "zsh",
--   callback = function()
--     -- let treesitter use bash highlight for zsh files as well
--     require("nvim-treesitter.highlight").attach(0, "bash")
--   end,
-- })


vim.api.nvim_create_autocmd(
  {
    "BufWritePre"
  },
  {
    pattern = { "*" },
    command = [[%s/\s\+$//e]],
    -- command = "echo 'Out'",
  }
)





lvim.lsp.installer.setup.ensure_installed = {
  "astro",
  "cssls",
  "jsonls",
  "html",
  "emmet_ls",
  "tsserver"
}

lvim.builtin.treesitter.autotag = {
  enable = true
}

lvim.builtin.treesitter.ensure_installed = {
  "astro",
  "html",
  "lua",
}

vim.filetype.add({
  extension = {
    astro = "astro"
  }
})

--Emmet configuration
vim.g.user_emmet_install_global = 0
vim.g.user_emmet_mode = 'a'
vim.g.user_emmet_leader_key = '<C-e>'
-- autocmd FileType html,css EmmetInstall
vim.api.nvim_create_autocmd({
  "BufRead",
  "BufNewFile"
}, {
  pattern = { "*.html", "*.css", "*.jsx", "*.tsx" },
  command = "EmmetInstall"
})

--DAP CONFIGURATION
--
require("dap").adapters["pwa-node"] = {
  type = "server",
  host = "localhost",
  port = "${port}",
  executable = {
    command = "node",
    -- 💀 Make sure to update this path to point to your installation
    args = { "../../js-debug/src/dapDebugServer.js", "${port}" },
  }
}

require("dap").configurations.javascript = {
  {
    type = "pwa-node",
    request = "launch",
    name = "Launch file",
    program = "${file}",
    cwd = "${workspaceFolder}",
  },
}

require("dap").configurations.typescript = {
  {
    type = "pwa-node",
    request = "launch",
    name = "Launch file",
    program = "${file}/main.ts",
    cwd = "${workspaceFolder}",
  },
}

--DAP GUI CONFIGURATION

-- local M = {}

-- M.test = function()
--   print("hola")
-- end

-- M.test()

-- return M
