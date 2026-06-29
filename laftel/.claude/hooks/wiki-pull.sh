#!/usr/bin/env bash
# SessionStart 훅: LLM 위키 레포(ryu-mg/llm-wiki, ~/ryu-mg/wiki)를 git pull 한다.
# iCloud 자동동기화를 대체 — 세션 시작마다 원격 최신 형상을 당겨온다.
#
# 안전 원칙 (sync-personal-skills.sh 미러):
# - 세션 시작을 절대 막지 않도록 모든 실패 경로는 exit 0.
# - --ff-only: 로컬과 갈라졌으면 당기지 않고 실패만(working tree 무손상).
# - ConnectTimeout 으로 오프라인 hang 방지, 실패해도 무시.
# - wiki-index-loader 보다 먼저 실행되어야 fresh index 가 주입됨.

REPO="$HOME/ryu-mg/wiki"
[ -d "$REPO/.git" ] || exit 0

if GIT_SSH_COMMAND="ssh -o ConnectTimeout=5 -o BatchMode=yes" \
     git -C "$REPO" pull --quiet --ff-only 2>/dev/null; then
  pull_status="ok"
else
  pull_status="fail"
fi

bash "$HOME/.claude/hooks/hook-log.sh" wiki-pull "pull=$pull_status"

# 갈라짐(=ff 불가)일 때만 사용자에게 알림 — 로컬 미push 변경이 있다는 신호
if [ "$pull_status" = "fail" ] && [ -n "$(git -C "$REPO" status --porcelain 2>/dev/null)" ]; then
  echo "[위키] git pull --ff-only 실패 + 로컬 변경 있음 → cd ~/ryu-mg/wiki 에서 commit/push 또는 pull --rebase 확인"
fi

exit 0
