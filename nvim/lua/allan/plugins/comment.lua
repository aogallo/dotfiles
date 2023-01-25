local setup, comment = pcall(require, "vim-commentary")

if not setup then
	return
end

comment.setup()
