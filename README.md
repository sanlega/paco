# paco

A lightweight installer and runner for [Francinette](https://github.com/xicodomingues/francinette),
the 42 School project tester (`libft`, `get_next_line`, `printf`, `minitalk`, `pipex`...).

This is a rebuild of [francinette-image](https://github.com/WaRtr0/francinette-image) that fixes
its biggest problem: the Docker image was **2.5 GB**.

## What's different

- **Smaller image.** The original installed `ghc` (the Haskell compiler), `cmake`, `postgresql`/
  `libpq-dev` and `libxext-dev` — none of them used by any tester in the repo. It also never
  actually activated the Python venv it created (each Docker `RUN` is its own shell, so the
  `source venv/bin/activate` never survived to the next layer), and dragged in the full git
  history of 9 submodules. Cutting all of that, using `--no-install-recommends`, cleaning up the
  `apt` cache, and building in multiple stages (so what's deleted in one layer doesn't still
  weigh down the ones below it) gets the image down to **~1.1 GB** — while keeping the exact
  same `gcc` + `clang`, `valgrind` and `norminette` a real 42 session uses, since that's what
  keeps test results trustworthy.
- **Zero overhead when possible.** `install.sh` first tries installing francinette straight onto
  your system (no Docker) if you already have `gcc`, `clang`, `valgrind`, `libbsd-dev` and
  `libncurses-dev` — the common case on Linux. There, paco's "size" is zero: no image to build.
  Docker is only a fallback, for macOS, Windows/WSL without the toolchain, or any system missing
  those packages.
- **Actually cross-platform.** The original installer only touched `.zshrc` and relied on
  `systemctl` (which doesn't exist on macOS) to start the container on every new shell. Here, the
  installer configures whichever of `.bashrc`/`.zshrc` you actually have, the container starts
  lazily the first time you run `paco`, and `docker build` targets your machine's own
  architecture automatically (amd64 or arm64) — no manifests or `buildx` needed.
- **`get_next_line`'s bonus part is now graded as mandatory.** No more `_bonus`-suffixed files —
  everything lives directly in `get_next_line.c` / `.h` / `get_next_line_utils.c`. See
  [How it works](#how-it-works) below.

## Install

One command, no prompts:

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanlega/paco/<branch>/install.sh)"
```

Replace `<branch>` with this repo's default branch. It installs into `$HOME` by default (export
`INSTALL_DIR=/some/path` first to use a different location), figures out on its own whether to
go native or Docker, and wires up the `paco` and `francinette` commands in your shell.

## Usage

Inside a project folder (`libft`, `get_next_line`, etc.):

```shell
paco
```

It takes the same flags francinette does — `-m`/`--mandatory`, `-b`/`--bonus`, `-s`/`--strict`,
`-in`/`--ignore-norm`, `-t`/`--testers`, and more. Run `paco --help` to see all of them.

In Docker mode, your project needs to live under `$HOME` (or `/goinfre`, `/sgoinfre` if you're on
a 42 campus machine) for the container to see it.

## Uninstall / update / rebuild

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanlega/paco/<branch>/uninstall.sh)"
```

Once installed, `update.sh` pulls the latest version (of paco, and of francinette in native
mode), and `rebuild.sh` forces a clean rebuild — no cache — of the image or the native checkout.

## How it works

```
Dockerfile     Multi-stage build: clones francinette, applies overlay/, installs only what
               the testers actually use - no venv, no leftover apt/pip cache.
overlay/       Files copied on top of the cloned francinette (same mechanism for both Docker
               and native installs) - currently, the mandatory-bonus patch below.
paco           The CLI: starts/reuses the container in Docker mode, or runs
               francinette/main.py directly in native mode.
install.sh     Picks native vs Docker, clones/updates, sets up your shell.
uninstall.sh, update.sh, rebuild.sh
```

**The mandatory-bonus patch.** Since `get_next_line`'s bonus part is graded as part of the
mandatory work, students no longer split it into `_bonus`-suffixed files. francinette's upstream
test harnesses (including a vendored third-party C++ test suite) still look for those exact
filenames, so rather than patching that third-party code, `overlay/testers/get_next_line/GetNextLine.py`:

1. treats the bonus as mandatory unless `-m`/`--mandatory` is passed explicitly;
2. aliases the mandatory files onto the historical `_bonus` names
   (`get_next_line_bonus.c`, `get_next_line_bonus.h`, `get_next_line_utils_bonus.c`) inside the
   temporary working directory, so the vendored test suites keep compiling untouched.

This was verified end to end: a real build of the image, and a real test run against a
`get_next_line` project with no `_bonus` files, confirming the bonus part still compiles and runs
correctly with every bundled tester.

## Credits

- [xicodomingues](https://github.com/xicodomingues) and [arsalas](https://github.com/arsalas),
  creators of [francinette](https://github.com/xicodomingues/francinette).
- [WaRtr0](https://github.com/WaRtr0), author of
  [francinette-image](https://github.com/WaRtr0/francinette-image), which this project builds on.
- [Tripouille](https://github.com/Tripouille), [jtoty](https://github.com/jtoty) /
  [y3ll0w42](https://github.com/y3ll0w42), [alelievr](https://github.com/alelievr),
  [cacharle](https://github.com/cacharle), [vfurmane](https://github.com/vfurmane) and
  [gmarcha](https://github.com/gmarcha), authors of the various testers francinette uses.

`paco` is not a replacement for writing your own tests.
