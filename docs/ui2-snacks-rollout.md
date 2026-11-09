# UI2 and Snacks rollout

Refs #107.

This draft integration branch collects the reviewed Neovim message-ownership and
split-shortcut changes. Do not merge the tracker until the dependent PRs have
been reviewed and integrated by a human.

## Scope

- Use Neovim 0.12 UI2 for native editor messages and its pager.
- Use Snacks for full-text notifications and notification history.
- Remove the parallel history, command-line message recapture and self-reinstalling
  notification wrapper while retaining adapters used by existing tools.
- Add normal-mode `ss` for a split below and `sv` for a vertical split right.
- Keep existing database, formatter, LSP and window-navigation behavior.

## Review order

```text
main
└── feat/ui2-snacks                         (draft integration tracker)
    └── refactor/ui2-snacks-messages        (message ownership and regression tests)
        └── feat/ui2-snacks-splits          (split shortcuts and their tests)
```

Review each child against its immediate parent. The message-ownership unit is
larger than the advisory 400-line budget because removing the old subsystem,
updating its existing tests and covering the replacement belong together.
Do not omit tests or leave intermediate configurations with missing APIs to
artificially reduce the diff.

## Verification

Focused and attached-UI checks cover full notification text, separate histories,
focus, native pager sizing at 80/120/160 columns and split behavior. Independent
verification found no candidate-caused blocker. The full smoke suite also exposed
two baseline issues: missing `sqsh` emits a completion error, and an ancestor
`package.json` changes a formatter fixture's expected selection.

## Exclusions and delivery

The centered floating command-line proposal in issue #62 is not implemented by
this native-UI2 approach. The active explorer specification, existing explorer
include-pattern edit and other pre-existing local changes are excluded.

Use a nonclosing `Refs` issue link. No automatic issue closure, self-merge or push
to `main` is authorized. After child review, a human integrates the branches and
reviews the tracker before merging it.
