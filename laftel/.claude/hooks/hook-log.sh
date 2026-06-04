#!/usr/bin/env bash
# 공통 SessionStart 훅 로거.
# 사용법: hook-log.sh <hook-name> <message>
# ~/.claude/logs/hooks.log 에 한 줄 append 하고, 오늘 날짜가 아닌 줄은 제거한다.
# stdout 에는 아무것도 쓰지 않는다 (훅의 컨텍스트 출력을 오염시키지 않기 위해).

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/hooks.log"

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
echo "$timestamp  [$1]  $2" >> "$LOG_FILE"

# 오늘 날짜 줄만 보존
today="${timestamp%% *}"
grep "^$today " "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null && mv "$LOG_FILE.tmp" "$LOG_FILE"

exit 0
