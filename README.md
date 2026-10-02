# paco

A lightweight installer and runner for [Francinette](https://github.com/xicodomingues/francinette),
the 42 School project tester (`libft`, `get_next_line`, `ft_printf`, `minitalk`, `pipex`...).

It started as a rebuild of [francinette-image](https://github.com/WaRtr0/francinette-image), whose
Docker image weighed **2.5 GB**. paco's weighs **~420 MB (a ~140 MB download)**, installs natively
with no Docker at all when your system already has the toolchain, and fixes a long list of
francinette testers that crashed - or worse, silently "passed" without testing anything - on Linux.

## Install

One command, no prompts. It **removes any previous version first** (an older paco, the original
francinette, or francinette-image, including their Docker images and shell aliases), then installs
the current one:

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanlega/paco/main/install.sh)"
```

Then open a new terminal. The installer picks the mode by itself:

- **Native** (Linux with `gcc`, `clang`, `valgrind`, `libbsd-dev` and `libncurses-dev`, like 42's
  machines): francinette runs directly on your system. Nothing to download but francinette itself.
- **Docker** (macOS, Windows/WSL, or Linux without those packages): francinette runs inside the
  slim image, built once during the install.

Options, exported before running the command: `INSTALL_DIR=/some/path` (default: `$HOME`),
`PACO_MODE=native` or `PACO_MODE=docker` to skip the detection.

## Uninstall

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/sanlega/paco/main/uninstall.sh)"
```

or simply `paco --uninstall`. Either one removes paco, francinette, the Docker container and image,
and the `paco`/`francinette` aliases from `~/.bashrc` and `~/.zshrc` (a backup of each file is kept as
`.bashrc.paco-backup` / `.zshrc.paco-backup`). It also cleans up leftovers of francinette-image.

## Usage

Inside a project folder:

```shell
paco
```

It takes the same options as francinette: `-m`/`--mandatory`, `-b`/`--bonus`, `-s`/`--strict`,
`-in`/`--ignore-norm`, `-t`/`--testers`, `-tm`/`--timeout`... (`paco --help` lists them all).
`francinette` works as an alias of `paco`.

paco's own commands:

| Command          | What it does                                                             |
| ---------------- | ------------------------------------------------------------------------ |
| `paco --update`  | Updates paco and re-applies its fixes (the image rebuilds by itself).    |
| `paco --rebuild` | Rebuilds everything from scratch, if something ever gets corrupted.      |
| `paco --uninstall` | Removes paco completely (see above).                                   |
| `paco --version` | Shows the installed version and mode.                                    |

In Docker mode your project can be anywhere: folders under `$HOME`, `/goinfre` and `/sgoinfre` use a
runner container that stays up between runs (each run is just a `docker exec`), anything else gets a
one-off container. The container runs as your user, so it never leaves root-owned files behind.

## Bonus is mandatory

Bonus is graded as part of the mandatory work now, so it no longer gets its own files or Makefile
rule:

- **get_next_line**: no `_bonus` files - everything lives in `get_next_line.c` / `.h` /
  `get_next_line_utils.c`.
- **libft**: `make` (`all`) builds everything, bonus functions included. Projects that still have a
  separate `bonus:` rule keep working: paco calls it too.

The bonus part is tested by default; `-m`/`--mandatory` still tests only the historical mandatory
part.

## What paco fixes in francinette

francinette is no longer maintained, and several of its testers only ever worked on macOS. paco
applies [its fixes](patches/) on top of it, identically in Docker and native mode:

- **Testers that reported success without testing anything**: fsoares' `ft_printf` tester crashed at
  startup on Linux (AddressSanitizer vs. its malloc mock), and every fsoares tester crashed as soon
  as one test failed (`fclose(NULL)`). In both cases the empty output was reported as
  "All tests passed".
- **Testers that never worked on Linux**: pipexMedic (did not compile with any recent compiler, and
  bash >= 5.1 changed its error format), pipex-tester (required `ping`), fsoares' minitalk tester
  (`SIGINFO` and macOS signal numbers), fsoares' pipex tester (its error comparison crashed under
  `dash`, and its leak check only existed for macOS - it uses valgrind now).
- **False failures**: valgrind could not read clang's DWARF 5 debug info ("unhandled dwarf2 abbrev
  form code"), the stdio buffer was reported as a leak in `ft_printf`, and `grep` randomly printed
  "Broken pipe" in pipex tests.
- **Crashes without a terminal** (`paco | tee log`, CI): "Inappropriate ioctl for device", and
  `tput` failing without `$TERM`.
- **Python 3.12/3.13** (native installs on recent distros): removed `pipes` module, warnings.
- **Speed**: libftTester compiles and runs its tests in parallel (a libft run went from ~90 s to
  ~60 s), and francinette no longer checks for updates over the network on every run.

## Size

| Image                     | Size    |
| ------------------------- | ------- |
| francinette-image         | 2.5 GB  |
| paco (previous)           | 1.1 GB  |
| **paco**                  | **~420 MB** (~140 MB download) |

The image has exactly what the testers use - `clang` (which is also `cc`/`gcc`, as on 42's
machines), `make`, `valgrind` (memcheck), `norminette`, `python3` - and nothing else: no Haskell,
CMake or PostgreSQL like the original, no 32-bit runtimes, no other valgrind tools, sanitizer
runtimes for other architectures, Perl, docs or caches. It is shipped as a single layer, so what is
deleted while building really is gone, and the build smoke-tests the toolchain before finishing.

(With Docker's containerd image store, `docker images` shows the unpacked size plus the compressed
download as "disk usage", ~580 MB.)

## How it works

```
paco                  The CLI: runs francinette natively, or through the Docker runner.
install.sh            Removes old versions, picks native vs Docker, sets up the aliases.
uninstall.sh          Removes paco and every older layout (also used by install.sh).
update.sh, rebuild.sh paco --update / paco --rebuild.
patch-francinette.sh  Applies patches/ to a francinette checkout (Docker and native).
patches/              paco's fixes to francinette, one commit-style patch per fix.
Dockerfile            Multi-stage build, flattened into a single slim layer.
selftest/             Reference projects + a script that checks every tester.
```

### Self-test

`selftest/run.sh [image]` runs every tester against small, correct reference projects (each must
report "All tests passed") and against deliberately broken copies of them (each must report
failures), which catches both false failures and silent false passes:

```shell
docker build -t paco-francinette . && selftest/run.sh paco-francinette
```

It also runs on every pull request (see `.github/workflows/selftest.yml`).

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
