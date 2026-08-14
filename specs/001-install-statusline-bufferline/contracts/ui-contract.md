# UI Contract: Statusline and Bufferline Upgrade

## Scope

This contract defines the observable editor behavior for the statusline and bufferline. It does not define internal Lua structure.

## Statusline Contract

- The editor shows one primary statusline after startup.
- The statusline communicates mode, file identity, diagnostics, filetype, and cursor position when that information is available.
- Missing optional context, such as git branch or diagnostics, does not produce errors or empty broken segments.
- The old custom statusline does not render alongside the new statusline.

## Bufferline Contract

- Opening multiple files makes the buffer list visible.
- The active buffer is distinguishable from inactive buffers.
- Modified buffers are distinguishable from clean buffers.
- Closing a buffer updates the buffer list without leaving stale entries.
- A single-buffer session avoids unnecessary visual noise.

## Keymap Contract

- Buffer actions remain discoverable under the `<leader>b` workflow domain.
- Code actions remain under `<leader>c`; this change does not move unrelated workflows.
- Any new mapping includes a short description for discoverability.
- No mapping is added unless it supports a concrete buffer/status workflow.

## Failure Contract

- Startup must not show plugin setup errors.
- Missing icons or optional metadata must degrade gracefully.
- Headless startup validation must complete successfully.
