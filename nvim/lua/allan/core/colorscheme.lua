-- local status, _ = pcall(vim.cmd, "colorscheme gruvbox")
--local status, _ = pcall(vim.cmd, "colorscheme nightfly")
local status, _ = pcall(vim.cmd, "colorscheme kanagawa")

if not status then
  print("Colorscheme not found!")
  return
end
