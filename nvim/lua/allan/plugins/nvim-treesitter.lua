local status, treesitter = pcall(require, "nvim-treesitter.configs")
if not status then
  return
end

treesitter.setup {
  auto_install = true,
  -- highlight = {
  --   enable = true
  -- },
  autotag = {
    enable = true
  },
  rainbow = {
    enable = true,
    extended_mode = false,
    max_file_lines = nil,
  },
  autopairs = {
    enable = true
  },
  ensure_installed = {
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
}
