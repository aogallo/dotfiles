-- For taking notes in neovim
return {
  "nvim-neorg/neorg",
  build = ":Neorg sync-parsers",
  -- tag = "*",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("neorg").setup({
      load = {
        -- ["core.defaults"] = {
        --   "core.esupports.indent",
        -- }, -- Loads default behaviour
        -- ["core.concealer"] = {}, -- Adds pretty icons to your documents
        ["core.dirman"] = { -- Manages Neorg workspaces
          config = {
            workspaces = {
              personal = "~/notes/personal",
              work = "~/notes/work",
            },
          },
        },
      },
    })
  end,
}
