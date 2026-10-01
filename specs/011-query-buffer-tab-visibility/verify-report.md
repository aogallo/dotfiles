# 011 — Verification Report: Query Buffer Tab Visibility

Spec: `specs/011-query-buffer-tab-visibility/`
Branch: `011-query-buffer-tab-visibility` · PR: #99 · Issue: #96

## Status

61 of 62 tasks done. The implementation, the documentation and the static validation are complete.
The one open task is a live session, not code:

| Task | What it needs | Why it is open |
| --- | --- | --- |
| T059 | an interactive Neovim session against a real Sybase ASE connection | the `quickstart.md` §5 walkthrough — the reported sequence end to end, and which half of "a name shows up but it hides" was happening. No headless run can stand in for it; the developer runs it on the Windows machine |

T061, the close decision itself, is recorded at the end of this report.

The spec is closed as the completed solution for #96. T059 is handed to the developer rather than
folded into the close, so the record stays honest about what was and was not observed here.

## Gate

```
TOTAL 404 pass / 0 fail
stylua: clean
boot:   clean
```

Thirteen smoke suites, all with `-u NORC` (no plugin state), plus a real-configuration boot.
339 of the assertions are the pre-existing regression baseline; 65 are new.

## What was verified, and how

| Claim | Evidence |
| --- | --- |
| a tab exists for every buffer the developer opened | the route matrix: `:buffer N`, `:bnext`, `nvim_set_current_buf`, `nvim_win_set_buf`, `BufEnter`, `BufWinEnter`, `TabEnter`, `VimEnter` — all end in the same state |
| coming back is route-independent | that matrix is the defect: only `:edit <name>` used to work, and the workaround is what the original report was really running |
| reopening the same query never raises `Vim:E95` | the closed buffer is reclaimed with its name, filetype and `b:db` intact; no notice is emitted |
| two live queries of the same object do not collide | the first keeps `master.proc1.sql`, the second gets `master.proc1.2.sql`, and the first buffer's text is untouched |
| the text and the connection come back | snapshot on `BufUnload`, restore on the explicit reopen; the **recorded** URL is restored, never one re-resolved from the registry |
| live text is never overwritten | a buffer that already holds text wins over its snapshot (data-model invariant 3) |
| closing is final | a closed query is not revived by window or tab switching — the rejected symmetric list-sync routine of contract §5 has a test |
| nothing is persisted | a fresh Neovim has no record of the buffer; a second process is spawned to prove it |
| a close writes no file | asserted in an empty temp directory |
| generated output takes no tab | `.dbout`, `buftype=nofile` drawers and `b:aogallo_no_tab` are all excluded, and a read-only *ordinary* file is not — a state is not an intent |
| a summoned result takes no tab | the `db_results.show()` regression: `:pedit` re-derives buffer options, so the drawer settings are re-applied after it |
| the guard is add-only | it never unlists, unloads or wipes; it does not touch `filetype` or `bufhidden`; it never switches the current buffer |
| no keymap, no dependency, bufferline untouched | `keymaps.lua` and the bufferline option block have a zero-line diff |

## The four measured causes

Recorded because each one looked like the whole bug and none of them was:

1. `:bdelete` clears `'buflisted'`, and bufferline renders only listed buffers
   (`bufferline.nvim` `utils/init.lua:150`). No bufferline option relaxes this.
2. Coming back does not undo it: `:buffer N`, `:bnext` and `nvim_set_current_buf` all leave the
   buffer unlisted. Only `:edit <name>` and fzf-lua's explicit `vim.bo[buf].buflisted = true`
   re-listed it.
3. Reopening the same query raised `Vim:E95`, because a second buffer was created for a name the
   closed buffer still owned. The unhandled error skipped filetype, `b:db` and focus, leaving an
   unnamed `[No Name]` orphan tab.
4. `:bdelete` unloads, which destroys `b:db` and the unsaved text — so a tab that came back would
   have been empty and unbound.

`bufhidden = 'hide'` was investigated as a candidate and **ruled out** (R-0004): it is inert with
`'hidden'` on, which it always is here, and the picker's `h` marker tracks `getbufinfo().hidden` for
a loaded-but-not-displayed buffer, which is a true statement about the buffer.

## A-001, as decided

A force-close writes nothing, creates nothing, asks nothing, does not restore on its own, and does
not resurrect the buffer from disk. Draft text is recoverable only in memory, and only by an
explicit reopen. The tests assert each clause separately, because "no side effects" is a claim that
fails quietly when only half of it is true.

## Not verified here

- **T059.** No Sybase ASE server is reachable from this machine, so the interactive walkthrough was
  not run. The scenarios to walk are in `quickstart.md` §5.1–§5.2: the reported sequence end to end,
  and then which half of "a name shows up but it hides" was actually happening to the developer —
  the buffer with no tab, or the buffer with a tab that is hard to identify.
- The Windows session is also the first run on a second platform, so `T059` covers the
  cross-platform check (FR-025) as well as the defect itself.

## T061 — the close decision

Asked before the PR, as constitution XIII requires, and answered by the developer: **yes**,
`specs/011-query-buffer-tab-visibility/spec.md` is to be closed as the completed solution for
issue #96, with the interactive validation run on the Windows machine.

The question is recorded with the outcome rather than assumed, because the answer decides something
the code cannot: whether #96 is resolved. It is, on the mechanism — the buffer is listed again
because a guard re-lists it on every entry route, not because one particular route happened to
work, and the E95 orphan tab is gone because the duplicate-buffer path is gone rather than caught.
