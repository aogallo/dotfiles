return {
    cmd = { 'marksman', 'server' },
    filetypes = { 'markdown', 'markdown.mdx' },
    root_markers = { '.marksman.toml', '.git', '.gitignore' },
    root_dir = function(bufnr, on_dir)
        on_dir(
            vim.fs.root(bufnr, { '.marksman.toml', '.git', '.gitignore' })
                or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
        )
    end,
}
