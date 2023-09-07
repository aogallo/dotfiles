local status, null_ls = pcall(require,'null-ls')

if not status then
  print('null-ls package not found')
  return
end

local code_actions = null_ls.builtins.code_actions
local diagnostics = null_ls.builtins.diagnostics
local formatting = null_ls.builtins.formatting

--npm install -g cspell
null_ls.setup({
    sources = {
        null_ls.builtins.formatting.stylua,
        -- null_ls.builtins.diagnostics.eslint,
        -- null_ls.builtins.completion.spell,
        -- diagnostics.cspell,
        code_actions.cspell
    },
})
