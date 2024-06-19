return {
  "nvim-telescope/telescope.nvim",
  -- change some options
  opts = {
    defaults = {
      file_ignore_patterns = {
        "./node_modules/*",
        "node_modules",
        "^node_modules/*",
        "node_modules/*",
      },
    },
  },
}
