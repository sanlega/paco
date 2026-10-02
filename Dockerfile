# syntax=docker/dockerfile:1
#
# paco - a slim, disposable runner for the 42 school "francinette" tester
# (https://github.com/xicodomingues/francinette).
#
# This image only exists as a fallback for systems that cannot (or should
# not) install the compiler toolchain natively - see install.sh, which
# always tries a native install first.
#
# Build with:   docker build -t paco-francinette .
# Docker builds for the host's native platform (amd64 or arm64) on its own,
# no buildx/manifest juggling required.
#
# Size budget: < 500 MB uncompressed (the original francinette-image was
# 2.5 GB, the previous paco image 1.1 GB). How it gets there:
#   - only the toolchain the testers actually call (clang, valgrind, make,
#     python3, norminette); no haskell/cmake/postgres/X11 leftovers
#   - every file no tester can ever reach is removed (32-bit runtimes,
#     non-memcheck valgrind tools, sanitizer runtimes for other
#     architectures, perl, docs, python test suites...)
#   - the final image is a single flattened layer (FROM scratch + COPY), so
#     those deletions really shrink it instead of being hidden by a
#     whiteout on top of the layer that still carries the bytes.

ARG UBUNTU=ubuntu:22.04

# ---------------------------------------------------------------------------
# Stage 1: fetch francinette + its test-suite submodules (shallow, no git
# history) and apply paco's fixes on top (see patches/).
# ---------------------------------------------------------------------------
FROM ${UBUNTU} AS fetch

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq \
	&& apt-get install -y -qq --no-install-recommends ca-certificates git >/dev/null \
	&& rm -rf /var/lib/apt/lists/*

RUN git clone -q --recursive --shallow-submodules --depth 1 \
		https://github.com/xicodomingues/francinette.git /francinette

COPY patch-francinette.sh /paco/
COPY patches/ /paco/patches/
RUN /paco/patch-francinette.sh /francinette \
	&& find /francinette \( -name ".git" -o -name ".github" -o -name ".vscode" \) -prune -exec rm -rf {} + \
	&& rm -rf /francinette/doc /francinette/bin/install.sh /francinette/bin/update.sh

# ---------------------------------------------------------------------------
# Stage 2: install the runtime and trim it down. Nothing from this stage is
# shipped as-is: the next stage copies its final filesystem in one layer.
# ---------------------------------------------------------------------------
FROM ${UBUNTU} AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq \
	&& apt-get install -y -qq --no-install-recommends \
		ca-certificates \
		git \
		clang \
		make \
		libbsd-dev \
		libncurses-dev \
		valgrind \
		python3 \
		python3-pip \
		>/dev/null

COPY --from=fetch /francinette /francinette

RUN pip3 install -q --no-cache-dir --no-compile -r /francinette/requirements.txt norminette \
	&& apt-get purge -y -qq --auto-remove python3-pip >/dev/null

# 42 machines use clang as their C compiler ('cc' is clang there), and every
# tester already compiles with clang/clang++ anyway. The few places that
# hardcode 'gcc' (and student Makefiles using 'cc'/'gcc') get clang too, so
# results match a real 42 session and we avoid shipping a second compiler.
#
# All of them go through a tiny wrapper adding -fdebug-default-version=4:
# clang >= 14 defaults to DWARF 5 debug info, which this valgrind (3.18)
# can't read ("unhandled dwarf2 abbrev form code 0x25 ... Giving up"), so
# any test built with -g failed under valgrind. 42's clang 12 defaults to
# DWARF 4, so this is also what a campus machine does. It only changes the
# format of debug info, never whether it is generated.
RUN set -eu; \
	llvm="$(dirname "$(readlink -f /usr/bin/clang)")"; \
	for c in clang cc gcc c99 c89; do \
		printf '#!/bin/sh\nexec %s/clang -fdebug-default-version=4 "$@"\n' "$llvm" > "/usr/local/bin/$c"; \
	done; \
	for c in clang++ c++ g++; do \
		printf '#!/bin/sh\nexec %s/clang++ -fdebug-default-version=4 "$@"\n' "$llvm" > "/usr/local/bin/$c"; \
	done; \
	chmod 755 /usr/local/bin/*; \
	for c in cc gcc c99 c89 c++ g++; do ln -sf "/usr/local/bin/$c" "/usr/bin/$c"; done; \
	# war-machine (and francinette's own tester.sh) call a bare `python`
	ln -sf python3 /usr/bin/python

RUN set -eu; \
	arch="$(uname -m)"; \
	case "$arch" in x86_64) vg=amd64 ;; aarch64) vg=arm64 ;; *) vg="$arch" ;; esac; \
	# perl: only pulled in by git for helper scripts (send-email, svn...) never used here
	dpkg --purge --force-depends perl perl-modules-5.34 libperl5.34 liberror-perl >/dev/null 2>&1; \
	# valgrind: memcheck is the only tool any tester runs; keep it for this arch only
	find /usr/libexec/valgrind -type f ! -name "*.supp" ! -name "*.xml" \
		! -name "memcheck-$vg-linux" ! -name "vgpreload_core-$vg-linux.so" \
		! -name "vgpreload_memcheck-$vg-linux.so" -delete; \
	rm -rf /usr/lib/*-linux-gnu/valgrind /usr/bin/callgrind* /usr/bin/cg_* /usr/bin/ms_print \
		/usr/bin/vgdb /usr/bin/valgrind-di-server /usr/bin/valgrind-listener; \
	# valgrind only needs the debug symbols of the dynamic linker (to redirect
	# its strlen), not those of the whole libc: keep just that one file
	ld="$(readlink -f "$(ldd /bin/true | awk '/ld-linux/ { print $1 }')")"; \
	id="$(readelf -n "$ld" | awk '/Build ID/ { print $3 }')"; \
	find /usr/lib/debug -type f ! -path "*/.build-id/${id%"${id#??}"}/${id#??}.debug" -delete; \
	# GCC's sanitizer runtimes (clang links its own) and static archives
	# nobody links against (-static builds of libc/libm/libstdc++...)
	rm -f /usr/lib/*-linux-gnu/libasan.so* /usr/lib/*-linux-gnu/libtsan.so* \
		/usr/lib/*-linux-gnu/liblsan.so* /usr/lib/*-linux-gnu/libubsan.so* \
		/usr/lib/*-linux-gnu/libc.a /usr/lib/*-linux-gnu/libm-*.a /usr/lib/*-linux-gnu/libmvec.a \
		/usr/lib/*-linux-gnu/libncurses*.a /usr/lib/*-linux-gnu/libtinfo.a /usr/lib/*-linux-gnu/libform*.a \
		/usr/lib/*-linux-gnu/libmenu*.a /usr/lib/*-linux-gnu/libpanel*.a; \
	cd /usr/lib/gcc/*-linux-gnu/*/ && rm -f libasan* libtsan* liblsan* libubsan* libhwasan* \
		libstdc++.a libstdc++fs.a libgomp.a libitm.a libquadmath.a libobjc*.a libbacktrace.a libgcov.a; \
	cd /; \
	# 32-bit runtimes: only the (removed) x86 valgrind tools and -m32 builds need them
	rm -rf /usr/lib32 /lib32 /usr/libx32 /libx32 /usr/lib/i386-linux-gnu /usr/share/doc; \
	# libclang.so is the C API for IDE tooling; the clang binary itself never loads it
	rm -f /usr/lib/*-linux-gnu/libclang-[0-9]*.so* /usr/lib/llvm-*/lib/libclang.so* /usr/lib/llvm-*/lib/libclang-[0-9]*.so*; \
	# sanitizer runtimes: keep address/undefined/leak (+ builtins) for this arch only
	find /usr/lib/llvm-*/lib/clang/*/lib/linux -type f \
		! \( -name "*$arch*" \( -name "*asan*" -o -name "*ubsan*" -o -name "*lsan*" -o -name "*builtins*" \
			-o -name "crt*" \) \) -delete; \
	find /usr/lib/llvm-*/lib/clang/*/lib/linux -name "*hwasan*" -delete; \
	# compiler headers for GPU/other-arch targets
	cd /usr/lib/llvm-*/lib/clang/*/include; \
	rm -rf cuda_wrappers openmp_wrappers ppc_wrappers __clang_cuda_* __clang_hip_* opencl-c*.h \
		altivec.h htmintrin.h htmxlintrin.h s390intrin.h vecintrin.h riscv_vector.h hexagon_* hvx_* \
		msa.h velintrin*; \
	cd /; \
	# python: drop the stdlib's test suites, GUI and dev tooling, and all bytecode caches
	rm -rf /usr/lib/python3*/test /usr/lib/python3*/unittest/test /usr/lib/python3*/idlelib \
		/usr/lib/python3*/tkinter /usr/lib/python3*/lib2to3 /usr/lib/python3*/ensurepip \
		/usr/lib/python3*/pydoc_data /usr/lib/python3*/distutils/tests; \
	find / -xdev -name "__pycache__" -type d -prune -exec rm -rf {} +; \
	# docs, manuals, locales, caches
	rm -rf /var/lib/apt/lists/* /var/cache/apt/* /var/cache/debconf/*-old /var/log/* \
		/usr/share/man /usr/share/info /usr/share/locale /usr/share/lintian /usr/share/gcc \
		/usr/share/gdb /usr/share/bash-completion /usr/share/zsh /root/.cache \
		/usr/share/git-core/templates/hooks; \
	# git helpers that need perl/tk or are network daemons
	cd /usr/lib/git-core && rm -f git-svn git-send-email git-archimport git-cvs* git-instaweb \
		git-p4 git-request-pull git-add--interactive git-gui* git-citool git-daemon \
		git-http-backend git-shell git-imap-send git-credential-netrc git-filter-branch

# Smoke test: fail the build right here if the trimming above broke anything
# the testers rely on.
RUN set -eu; cd /tmp; \
	printf '#include <stdlib.h>\n#include <bsd/string.h>\nint main(void){return !malloc(1);}\n' > t.c; \
	printf '#include <iostream>\nint main(){std::cout<<"ok";}\n' > t.cpp; \
	cc -g -Wall -Wextra -Werror t.c -lbsd -o t && valgrind -q --error-exitcode=1 ./t; \
	valgrind -q --leak-check=full ./t 2>&1 | grep -q "definitely lost"; \
	gcc -g -fsanitize=address,undefined t.c -o t && ! ./t 2>/dev/null; \
	c++ -std=c++11 t.cpp -o t && [ "$(./t)" = ok ]; \
	norminette --version >/dev/null; python3 -c "import git, halo, pexpect, rich, toml"; \
	git --version >/dev/null; rm -f t t.c t.cpp

# ---------------------------------------------------------------------------
# Stage 3: the shipped image - stage 2's filesystem as one single layer.
# ---------------------------------------------------------------------------
FROM scratch

LABEL description="paco - slim francinette runner for 42 school projects" \
	org.opencontainers.image.source="https://github.com/sanlega/paco"

COPY --from=build / /

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
	LANG=C.UTF-8 \
	TERM=xterm-256color \
	PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1

WORKDIR /francinette

# main.py directly, not tester.sh: that script sources a venv/bin/activate
# this image never creates and falls back to a bare 'python' it doesn't have.
ENTRYPOINT ["python3", "/francinette/main.py"]
