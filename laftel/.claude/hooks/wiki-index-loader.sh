#!/usr/bin/env bash
# SessionStart 훅: LLM 위키(ryu-mg/wiki) index.md 를 컨텍스트에 주입한다.
# git 단독 관리(iCloud 밖, ~/ryu-mg/wiki). 실패 시 조용히 exit 0.
# 출력은 hookSpecificOutput.additionalContext (정식 SessionStart 컨텍스트 주입).

INDEX="$HOME/ryu-mg/wiki/index.md"

log() { bash "$HOME/.claude/hooks/hook-log.sh" wiki-index-loader "$1"; }

if [ -r "$INDEX" ]; then
  if jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ("# 개인 LLM 위키 Index (참조용 — 작업과 관련될 때 위키 파일을 직접 읽어 보강)\n\n" + .)}}' < "$INDEX"; then
    log "index 주입"
  else
    log "jq 실패 — skip"
  fi
else
  log "index 없음 — skip"
fi

exit 0
