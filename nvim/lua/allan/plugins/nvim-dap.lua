local status, dap = pcall(require, "dap")

if not status then
  print("Dap not found")
  return
end


dap.adapters.chrome = {
  type = "executable",
  command = "node",
  args = {
    os.getenv("HOME") .. "~/vscode-chrome-debug/out/src/chromeDebug.js",
  }
}

dap.configurations.javascriptreact = {
  {
    type = "chrome",
    request = "attach",
    program = "${file}",
    cwd = vim.fn.getcwd(),
    sourceMaps = true,
    protocol = "inspector",
    port = 9222,
    webRoot = "${workspaceFolder}"
  }
}

dap.configurations.typescriptreact = {
  {
    type = "chrome",
    request = "attach",
    program = "${file}",
    cwd = vim.fn.getcwd(),
    sourceMaps = true,
    protocol = "inspector",
    port = 9222,
    webRoot = "${workspaceFolder}"
  }
}

