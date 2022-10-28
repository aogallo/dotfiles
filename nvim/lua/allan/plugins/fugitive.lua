local keymap = vim.keymap

local options = { noremap = true, silent = true }

keymap.set("n", "<leader>gg", ":G <CR>", options)
keymap.set("n", "<leader>gp", ":G pull<CR>", options)
keymap.set("n", "<leader>gs", ":G status<CR>", options)
keymap.set("n", "<leader>gu", ":G push<CR>", options)
keymap.set("n", "<leader>gx", ":q<CR>", options)
