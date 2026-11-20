-- Installed explicitly with :MasonInstall lemminx.
return {
    cmd = require('config.ace').command 'lemminx',
    filetypes = { 'xml' },
    root_markers = { '.project', '.git' },
    settings = {
        xml = {
            downloadExternalResources = false,
            validation = { enabled = true },
        },
    },
}
