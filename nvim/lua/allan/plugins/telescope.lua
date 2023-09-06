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

-- To get fzf loaded and working with telescope, you need to call
-- load_extension, somewhere after setup function:
--require('telescope').load_extension('fzf')

local keymap = vim.keymap
local options = { noremap = true, silent = true }
keymap.set("n","<leader>ff", "<cmd>Telescope find_files<cr>", options)
keymap.set("n","<leader>fs", "<cmd>Telescope live_grep<cr>", options)
keymap.set("n","<leader>fc", "<cmd>Telescope grep_string<cr>", options)
keymap.set("n","<leader>fb", "<cmd>Telescope buffers<cr>", options)
keymap.set("n","<leader>fh", "<cmd>Telescope help_tags<cr>", options)
keymap.set("n","<leader>fw", ":lua require('telescope.builtin').current_buffer_fuzzy_find({layout_strategy='vertical',layout_config={width=0.5}})<cr>", options)

