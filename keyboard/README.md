# Keyboard Configuration

This directory stores repository-managed keyboard configuration assets.

## Iris Rev. 5

`iris_rev__5.json` is the VIA configuration for the Iris Rev. 5 keyboard. Import it with
VIA when you need to inspect, restore, or update the shared keyboard layout.

Keep keyboard files in this directory rather than the repository root so hardware-specific
configuration remains discoverable and grouped with future keyboard assets.

## Validation

From the repository root:

```sh
ruby -rjson -e 'JSON.parse(File.read("keyboard/iris_rev__5.json"))'
test -f keyboard/iris_rev__5.json
test ! -e iris_rev__5.json
```

When relocating this file, compare checksums before and after the move to confirm the VIA
configuration content was preserved exactly.

## Rollback

To restore the previous layout location, move `keyboard/iris_rev__5.json` back to
`iris_rev__5.json` at the repository root and revert the documentation changes, or revert the
feature commit.
