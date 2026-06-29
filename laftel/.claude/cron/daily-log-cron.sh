#!/bin/bash
# 매일 1회 launchd가 호출 → 어제 활동(Jira+Slack)을 LLM 위키 데일리 로그로 기록.
# 빈 날(둘 다 0건)은 스킬이 알아서 스킵. 권한은 daily-log-cron.settings.json allowlist 로 한정.
export PATH="/opt/homebrew/bin:/Users/bao/.nvm/versions/node/v22.22.2/bin:/usr/bin:/bin:/usr/sbin:/sbin"
LOG="$HOME/.claude/daily-log-cron.log"
SETTINGS="$HOME/.claude/daily-log-cron.settings.json"
echo "===== $(date '+%F %T') daily-log 시작 =====" >> "$LOG"
cd "$HOME" || exit 1
/opt/homebrew/bin/claude -p "/daily-log" --model opus --settings "$SETTINGS" >> "$LOG" 2>&1
echo "===== $(date '+%F %T') 종료 (exit $?) =====" >> "$LOG"
