-- NOTE: Plugins can also be configured to run Lua code when they are loaded.
--
-- This is often very useful to both group configuration, as well as handle
-- lazy loading plugins that don't need to be loaded immediately at startup.
--
-- For example, in the following configuration, we use:
--  event = 'VimEnter'
--
-- which loads which-key before all the UI elements are loaded. Events can be
-- normal autocommands events (`:help autocmd-events`).
--
-- Then, because we use the `config` key, the configuration only runs
-- after the plugin has been loaded:
--  config = function() ... end

return { -- Useful plugin to show you pending keybinds.
  "folke/which-key.nvim",
  event = "VimEnter", -- Sets the loading event to 'VimEnter'
  config = function() -- This is the function that runs, AFTER loading
    local wk = require("which-key")

    -- Document existing key chains
    wk.add({
      { "<leader>c", group = "[C]ode" },
      { "<leader>d", group = "[D]ocument" },
      { "<leader>r", group = "[R]ename" },
      { "<leader>s", group = "[S]earch" },
      { "<leader>w", group = "[W]orkspace" },
      { "<leader>t", group = "[T]oggle" },
      { "<leader>g", group = "[G]it" },
      { "<leader>p", group = "[P]ull Request" },
      -- [";s"] = { name = "[S]urround", _ = "which_key_ignore", b = "[B]uffer" },
      { "<leader>x", group = "[T]rouble" },
      { "<leader>h", group = "[H]unk" },
      { "<leader>h", group = "Git [H]unk", mode = "v" },
    })
  end,
}
