return {
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      opts.presets.lsp_doc_border = true
    end,
  },
  {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    opts = function(_, opts)
      local logo = [[
         █████╗  ██████╗
        ██╔══██╗██╔════╝
        ███████║██║  ███╗
        ██╔══██║██║   ██║
        ██║  ██║╚██████╔╝
        ╚═╝  ╚═╝ ╚═════╝
      ]]

      logo = string.rep("\n", 9) .. logo .. "\n\n"
      opts.config.header = vim.split(logo, "\n")
    end,
  },
}
