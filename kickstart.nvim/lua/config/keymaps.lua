-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`
--
-- use `+` and `-` to increment and decrement 8
vim.keymap.set("n", "+", "<C-a>")
vim.keymap.set("n", "-", "<C-x>")
vim.keymap.set("v", "+", "g<C-a>gv")
vim.keymap.set("v", "-", "g<C-x>gv")
vim.keymap.set("n", ";bd", ":bdelete<CR>", { desc = "Delete Current Buffer" })
vim.keymap.set("n", ";bo", function()
  local bufs = vim.api.nvim_list_bufs()
  local current_buf = vim.api.nvim_get_current_buf()
  for _, buf in pairs(bufs) do
    if buf ~= current_buf then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end, { desc = "Close all other buffers except the current" })

-- These keymaps controls the size of the splits (heigth/width)
vim.keymap.set("n", "<C-,>", "<c-w>5<", { desc = "" })
vim.keymap.set("n", "<C-.>", "<c-w>5>", { desc = "" })
vim.keymap.set("n", "<S-t>", "<c-w>+", { desc = "" })
vim.keymap.set("n", "<S-d>", "<c-w>-", { desc = "" })

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.keymap.set("i", "jk", "<Esc>")
vim.keymap.set("n", "L", ":bnext<CR>")
vim.keymap.set("n", "H", ":bprev<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous [D]iagnostic message" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next [D]iagnostic message" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- create new buffer
vim.keymap.set("n", ";bn", "<cmd>enew<CR>", { desc = "Create a new buffer" })

vim.api.nvim_set_keymap(
  "n",
  "<leader>bo",
  ":%bd|e#|bd#<CR>",
  { desc = "Delete others buffers", noremap = true, silent = true }
)

vim.keymap.set("n", "<leader>bd", function()
  local bufremove = require("mini.bufremove")
  bufremove.delete(0, false)
end, { desc = "Delete buffer" })

vim.keymap.set("n", "<leader>bD", function()
  local bufremove = require("mini.bufremove")
  bufremove.delete(0, true)
end, { desc = "Delete buffer (force)" })

vim.keymap.set("n", ";j", function()
  -- local buffer = vim.api.nvim_get_current_buf()
  vim.cmd([[%s/\\n/\r/g]])
  vim.cmd([[%s/\\"/"/g]])

  -- vim.api.
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local buffer_content = table.concat(lines, "\n")

  local found = string.find(buffer_content, "\\", 1, true)

  if found ~= nil then
    vim.cmd([[%s/\\\\/\\/g]])
  end

  vim.cmd([[nohlsearch]])
end, {
  desc = "Format jq filter",
})
