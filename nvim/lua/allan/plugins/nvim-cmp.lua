local cmp_status, cmp = pcall(require, "cmp")
if not cmp_status then
  return
end

local luasnip_status, luasnip = pcall(require, "luasnip")
if not luasnip_status then
  return
end

local lspkind_status, lspkind = pcall(require, "lspkind")
if not lspkind_status then
  return
end

local cmp_autopairs_status, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
if not cmp_autopairs_status then
  return
end

local ts_utils = require("nvim-treesitter.ts_utils")

-- load friendly-snippets
require("luasnip.loaders.from_vscode").lazy_load()

vim.opt.completeopt = "menu,menuone,noselect"

cmp.setup({
  snippet = {
    expand = function(args)
      -- print(vim.inspect(args))
      luasnip.lsp_expand(args.body)
      -- vim.fn["vsnip#anonymous"](args.body)
    end
  },
  window = {
    completion = cmp.config.window.bordered(),
  },
	mapping = cmp.mapping.preset.insert({
		['<C-b>'] = cmp.mapping.scroll_docs(-4),
		['<C-f>'] = cmp.mapping.scroll_docs(4),
		['<C-o>'] = cmp.mapping.complete(),
		['<C-e>'] = cmp.mapping.abort(),
		['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      -- elseif has_words_before() then
      --   cmp.complete()
      else
        fallback() -- The fallback function sends a already mapped key. In this case, it's probably `<Tab>`.
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function()
      if cmp.visible() then
        cmp.select_prev_item()
      elseif vim.fn["vsnip#jumpable"](-1) == 1 then
        feedkey("<Plug>(vsnip-jump-prev)", "")
      end
    end, { "i", "s" }),
	}),
  -- sources for autocompletion
  sources = cmp.config.sources({
    {
      name = 'nvim_lsp',
      keyword_length = 3,
      entry_filter = function(entry, context)
        local kind = entry:get_kind()
        local node = ts_utils.get_node_at_cursor():type()

        -- log(node)

        if node == "arguments" then
          if kind == 6 then
            return true
          else
            return false
          end
        end

        return true
      end
    }, -- lsp
    { name = 'luasnip' }, -- snippets
    { name = 'buffer' }, -- text within current buffer
    { name = 'path' }, -- file system paths
  }),
  formatting = {
    format = function(entry, vim_item)
      local kind = vim_item.kind --> Class, Method, Variable ....

      local source = entry.source.name --> nvim_lsp, luasnip, buffer, path ...
      vim_item.menu = "[" .. source .."]"

      return vim_item
    end
  }
})


-- setup lspconfig
vim.cmd [[packadd nvim-lspconfig]]

local lsp = require 'lspconfig'
local cmp_lsp = require 'cmp_nvim_lsp'

lsp.vimls.setup {
  capabilities = cmp_lsp.default_capabilities(vim.lsp.protocol.make_client_capabilities())
}

cmp.event:on(
  "confirm_done",
  cmp_autopairs.on_confirm_done()
)
