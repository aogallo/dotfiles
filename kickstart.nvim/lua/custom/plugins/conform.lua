return { -- Autoformat
  "stevearc/conform.nvim",
  event = { "LspAttach", "BufReadPost", "BufNewFile" },
  lazy = false,
  keys = {
    {
      ";f",
      function()
        require("conform").format({ formatters = { "injected" }, async = true, lsp_fallback = true })
      end,
      mode = { "n", "v" },
      desc = "[F]ormat buffer",
    },
  },
  opts = {
    notify_on_error = true,
    format_on_save = function(bufnr)
      -- Disable "format_on_save lsp_fallback" for languages that don't
      -- have a well standardized coding style. You can add additional
      -- languages here or re-enable it for the disabled ones.
      local disable_filetypes = { c = true, cpp = true }
      return {
        timeout_ms = 2500,
        lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
      }
    end,
    formatters_by_ft = {
      injected = { options = { ignore_errors = true } },
      lua = { "stylua" },
      -- Conform can also run multiple formatters sequentially
      -- python = { "isort", "black" },
      --
      -- You can use a sub-list to tell conform to run *until* a formatter
      -- is found.
      -- javascript = { { 'prettierd', 'prettier' } },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      csharp = { "csharpier" },
      -- gofmt_command
      -- For vim, set "gofmt_command" to "goimports":
      -- https://golang.org/change/39c724dd7f252
      -- https://golang.org/wiki/IDEsAndTextEditorPlugins
      -- etc
      go = { "goimports", "gofmt" },
      astro = { "prettier" },
      markdown = { "prettier", "markdownlint-cli2", "markdown-toc" },
      css = { "prettier" },
      ["markdown.mdx"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
      python = { "black" },
    },
    formatters = {
      injected = {
        options = {
          ignore_errors = false,
          lang_to_formatters = {
            sql = { "sleek" },
          },
        },
      },
    },
  },
}
