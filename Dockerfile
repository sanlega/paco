# syntax=docker/dockerfile:1
#
# paco - a slim, disposable runner for the 42 school "francinette" tester
# (https://github.com/xicodomingues/francinette).
#
# This image only exists as a fallback for systems that cannot (or should
# not) install the compiler toolchain natively - see install.sh, which
# always tries a native install first. Because of that it is built to be
# as small as it can be while still behaving exactly like a real 42
# session: same compilers, same valgrind, nothing extra.
#
# Build with:   docker build -t paco .
# multi-arch is automatic: docker builds for the host's native platform
# (amd64 or arm64), no buildx/manifest juggling required.

# ---------------------------------------------------------------------------
# Stage 1: fetch francinette + its test-suite submodules, strip everything
# that is only useful for git history (.git, .github, docs). Doing this in
# a dedicated stage - instead of a later "rm -rf" in the final stage - keeps
# that stripped-away weight out of the final image entirely, since Docker
# layers are additive and a delete in one layer does not shrink the layers
# below it.
# ---------------------------------------------------------------------------
FROM ubuntu:22.04 AS fetch

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq \
	&& apt-get install -y --no-install-recommends ca-certificates git \
	&& rm -rf /var/lib/apt/lists/*

# Shallow clone: only the latest commit of francinette and of every
# submodule it pulls in (libftTester, gnlTester, printfTester, pipex-tester,
# pipexMedic, printf-unit-test, ft_printf_test, libft-unit-test,
# libft-war-machine). Full history is not needed to run tests.
RUN git clone --recursive --shallow-submodules --depth 1 \
		https://github.com/xicodomingues/francinette.git /francinette \
	&& find /francinette \( -name ".git" -o -name ".github" \) -prune -exec rm -rf {} + \
	&& rm -rf /francinette/.vscode /francinette/doc/example.png

# Apply our own patches on top of the vendored source (see overlay/ for
# what changed and why).
COPY overlay/ /francinette/

# ---------------------------------------------------------------------------
# Stage 2: the actual runtime image. Only what is needed to compile and
# test C (and the handful of C++ test harnesses) the way a real 42 session
# would, plus Python for the tester engine itself.
#
# Deliberately NOT installed, because nothing in francinette or any of its
# bundled testers uses them (verified by grepping the whole tree):
#   - ghc/haskell, cmake, postgresql/libpq-dev, libxext-dev
# These made up the bulk of the original 2.5 GB image.
#
# Also deliberately not using a Python venv: the container itself is
# already the isolation boundary, and creating one inside `RUN` steps is a
# no-op anyway (each RUN is its own shell, so "source venv/bin/activate"
# never survives to the next layer).
# ---------------------------------------------------------------------------
FROM ubuntu:22.04

LABEL description="paco - slim francinette runner for 42 school projects"

ENV DEBIAN_FRONTEND=noninteractive \
	PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1

RUN apt-get update -qq \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		git \
		gcc \
		clang \
		make \
		libbsd-dev \
		libncurses-dev \
		valgrind \
		python3 \
		python3-pip \
	&& rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
		/usr/share/doc/* /usr/share/man/* /usr/share/locale/*

COPY --from=fetch /francinette /francinette
WORKDIR /francinette

RUN pip3 install --no-cache-dir -r requirements.txt norminette \
	&& chmod +x tester.sh \
	&& rm -rf /root/.cache

ENTRYPOINT ["python3", "/francinette/main.py"]
