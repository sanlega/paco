#!/usr/bin/env bash
# paco self-test: runs every tester against known-good reference projects
# (each one must report "All tests passed") and against deliberately broken
# copies of them (each one must report failures). Together these catch both
# kinds of tester bugs: false failures, and silent false passes.
#
# usage: selftest/run.sh [image] [case...]
#   image  Docker image to test (default: paco-francinette)
#   case   only run the cases whose name contains this text
#
# Cases are "<project>[:<mutation>]". Projects live in selftest/projects/.
set -uo pipefail

SELFTEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
IMAGE="${1:-paco-francinette}"
shift || true
FILTERS=("$@")

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
BLUE=$'\033[0;36m'
NC=$'\033[0m'

# name | project | expectation (pass/fail) | mutation (sed program, file)
CASES=(
	"libft|libft|pass||"
	"libft:bonus-rule|libft|pass|s/^OBJS\t= \$(SRCS:.c=.o) \$(BSRCS:.c=.o)\$/OBJS\t= \$(SRCS:.c=.o)\\nBOBJS\t= \$(BSRCS:.c=.o)\\n\\nbonus: \$(OBJS) \$(BOBJS)\\n\tar rcs \$(NAME) \$(OBJS) \$(BOBJS)/|Makefile"
	"libft:wrong-strlen|libft|fail|s/return (i);/return (i + 1);/|ft_strlen.c"
	"get_next_line|get_next_line|pass||"
	"get_next_line:leak|get_next_line|fail|0,/^\tfree(buf);\$/{/^\tfree(buf);\$/d}|get_next_line.c"
	"ft_printf|ft_printf|pass||"
	"ft_printf:wrong-null|ft_printf|fail|s/\"(null)\"/\"(nil)\"/|ft_printf_utils.c"
	"pipex|pipex|pass||"
	"pipex:wrong-exit-code|pipex|fail|s/return (wait_all(px.last_pid));/return (wait_all(px.last_pid) \&\& 0);/|main.c"
	"minitalk|minitalk|pass||"
	"minitalk:flipped-bits|minitalk|fail|s/(sig == SIGUSR2)/(sig == SIGUSR1)/|server.c"
)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LOG_DIR="${SELFTEST_LOGS:-$WORK/logs}"
mkdir -p "$LOG_DIR"

matches_filter() {
	[ "${#FILTERS[@]}" -eq 0 ] && return 0
	for f in "${FILTERS[@]}"; do
		case "$1" in *"$f"*) return 0 ;; esac
	done
	return 1
}

failures=0
ran=0
for entry in "${CASES[@]}"; do
	IFS='|' read -r name project expect mutation file <<< "$entry"
	matches_filter "$name" || continue
	ran=$((ran + 1))

	dir="$WORK/${name//:/_}/$project"
	mkdir -p "$(dirname "$dir")"
	cp -R "$SELFTEST_DIR/projects/$project" "$dir"
	if [ -n "$mutation" ]; then
		before="$(cat "$dir/$file")"
		sed -i.orig -e "$mutation" "$dir/$file" && rm -f "$dir/$file.orig"
		if [ "$before" = "$(cat "$dir/$file")" ]; then
			printf '%s%-28s%s %sBROKEN CASE%s (mutation did not change %s)\n' \
				"$BLUE" "$name" "$NC" "$RED" "$NC" "$file"
			failures=$((failures + 1))
			continue
		fi
	fi

	log="$LOG_DIR/${name//:/_}.log"
	start=$SECONDS
	docker run --rm -v "$dir:/selftest/$project" -w "/selftest/$project" "$IMAGE" > "$log" 2>&1
	elapsed=$((SECONDS - start))

	if grep -q "Traceback (most recent call last)" "$log"; then
		got="crash"
	elif grep -q "All tests passed" "$log"; then
		got="pass"
	elif grep -q "Failed tests\|Norminette Errors\|Missing functions" "$log"; then
		got="fail"
	else
		got="no result"
	fi

	if [ "$got" = "$expect" ]; then
		printf '%s%-28s%s %sok%s   (expected %s, %ss)\n' "$BLUE" "$name" "$NC" "$GREEN" "$NC" "$expect" "$elapsed"
	else
		printf '%s%-28s%s %sFAIL%s (expected %s, got %s, %ss) - log: %s\n' \
			"$BLUE" "$name" "$NC" "$RED" "$NC" "$expect" "$got" "$elapsed" "$log"
		failures=$((failures + 1))
		if [ -z "${SELFTEST_LOGS:-}" ]; then
			sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$log" | tr '\r' '\n' | grep -v '^\s*$' | tail -n 40
		fi
	fi
done

if [ "$ran" -eq 0 ]; then
	echo "selftest: no case matches: ${FILTERS[*]}" >&2
	exit 2
fi
if [ "$failures" -ne 0 ]; then
	printf '\n%s%d of %d cases failed%s\n' "$RED" "$failures" "$ran" "$NC"
	exit 1
fi
printf '\n%sall %d cases ok%s\n' "$GREEN" "$ran" "$NC"
