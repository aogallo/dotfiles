local telescope_status, telescope = pcall(require, "telescope")
if not telescope_status then
  return
end

local actions_status, actions = pcall(require, "telescope.actions")
if not actions_status then
  return
end

telescope.setup({
  defaults = {
    mappings = {
      i = {
        ["<C-k>"] = actions.move_selection_previous,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-q>"] = actions.close,
     },
     n = {
       ["q"] = actions.close,
     }
    }
  }
})

telescope.load_extension("fzf")

local keymap = vim.keymap
local options = { noremap = true, silent = true }
keymap.set("n","<leader>ff", "<cmd>Telescope find_files<cr>", options)
keymap.set("n","<leader>fs", "<cmd>Telescope live_grep<cr>", options)
keymap.set("n","<leader>fc", "<cmd>Telescope grep_string<cr>", options)
keymap.set("n","<leader>fb", "<cmd>Telescope buffers<cr>", options)
keymap.set("n","<leader>fh", "<cmd>Telescope help_tags<cr>", options)
