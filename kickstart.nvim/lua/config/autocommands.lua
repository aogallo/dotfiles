-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Conform on save file
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function(args)
    -- print("data", vim.inspect(args))
    -- vim.lsp.buf.code_action({
    --   apply = true,
    --   context = {
    --     only = { "source.organizeImports.ts" },
    --     diagnostics = {},
    --   },
    -- })

    require("conform").format({ async = true, lsp_fallback = true, bufnr = args.buf, timeout_ms = 5000 })
  end,
})

-- Remove the spaces at the end of the line
vim.api.nvim_create_autocmd({
  "BufWritePre",
}, {
  pattern = { "*" },
  command = [[%s/\s\+$//e]],
})

-- Go files
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
    local params = vim.lsp.util.make_range_params()
    params.context = { only = { "source.organizeImports" } }

    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params)
    for cid, res in pairs(result or {}) do
      for _, r in pairs(res.result or {}) do
        if r.edit then
          local enc = (vim.lsp.get_client_by_id(cid or {}).offset_encoding or "utf-16"
          vim.lsp.util.apply_workspace_edit(r.edit, enc)
        end
      end
    end
    vim.lsp.buf.format({async=false})
  end,
})
