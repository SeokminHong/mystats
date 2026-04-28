# mystats

`mystats` is a lightweight Apple Silicon menu bar monitor for macOS.

The product goal is to show accurate, low-overhead CPU, GPU, thermal, disk, and
network status without requiring privileged helpers, external daemons, or runtime
dependencies.

## Development

Build:

```sh
swift build
```

Test:

```sh
swift test
```

Run locally:

```sh
./script/build_and_run.sh
```

The app currently boots with deterministic sample metrics while the real
collectors are implemented.

## Install

```sh
brew install seokminhong/brew/mystats
```

Launch:

```sh
mystats
```

Check the installed version without launching the menu bar app:

```sh
mystats --version
```
