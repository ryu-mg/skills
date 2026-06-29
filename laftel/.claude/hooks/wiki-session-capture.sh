#!/usr/bin/env bash
# SessionEnd 훅: 종료/clear 시 세션 transcript 를 헤드리스 claude(haiku)로
# "위키감" 판단 → 후보면 인박스(notes/_inbox.md)에 append 한다.
# 위키 본구조엔 쓰지 않고 commit 도 안 한다(승인 원칙 유지). 정식 파일링은 /wiki-capture.
#
# 안전 원칙:
# - 비대화형·fire-and-forget. 백그라운드 분리 + 즉시 exit 0 으로 종료 지연 방지.
# - claude 없거나 transcript 없거나 위키 repo 없으면 조용히 skip.
# - 실패해도 세션/위키에 영향 없음.

INBOX="$HOME/ryu-mg/wiki/notes/_inbox.md"
LOG_NAME=wiki-session-capture

input=$(cat)
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
reason=$(printf '%s' "$input" | jq -r '.reason // "other"' 2>/dev/null)

CLAUDE=$(command -v claude)
if [ -z "$CLAUDE" ] || [ ! -r "$tp" ] || [ ! -d "$HOME/ryu-mg/wiki/.git" ]; then
  bash "$HOME/.claude/hooks/hook-log.sh" "$LOG_NAME" "skip (claude=${CLAUDE:+y} tp=${tp:+y})"
  exit 0
fi

# 백그라운드로 분리 — 종료 지연 방지. claude 판단은 수 초~수십 초 걸릴 수 있음.
nohup bash -c '
  tp="$1"; inbox="$2"; reason="$3"; claude="$4"; logname="$5"
  ts=$(date "+%Y-%m-%d %H:%M")
  prompt="너는 LLM 위키 큐레이션 보조다. 아래 <transcript> 는 Claude Code 세션 기록(JSONL) 끝부분이다.
이 세션에 위키에 남길 가치가 있는 내용이 있는가?
남길 것: 중요 기술 결정과 근거, 장애·버그 원인과 해결(재발방지), 재사용 runbook, 외부 소스(URL/글/영상) 지식, 깨달음/개념 정리.
버릴 것: 일상 코딩·단순 수정·리뷰 왕복, 코드/git/CLAUDE.md 에 이미 남는 것, 잡담, 이 세션에서만 의미있는 것.
남길 게 없으면 정확히 NOTHING 한 단어만 출력하라.
남길 게 있으면 아래 마크다운 후보 블록만 출력하라(파일 쓰지 말 것):
### [${ts}] <한글 제목>
- 요약: <2~3줄>
- 분류 제안: notes | concepts | entities | sources 중 택
- 근거: <왜 위키감인지 한 줄>"
  # transcript 는 stdin 이 아니라 prompt 에 임베드해야 모델이 본다.
  # advisorModel=fable 가 이 계정 게이팅이라 헤드리스 요청이 400 → settings 로 덮어씀.
  body=$(tail -c 120000 "$tp")
  out=$("$claude" -p "$prompt
<transcript>
$body
</transcript>" --model haiku --settings "{\"advisorModel\":\"haiku\"}" --output-format text 2>/dev/null)
  if printf "%s" "$out" | grep -q "^### "; then
    {
      printf "\n---\n<!-- session-capture %s reason=%s -->\n" "$ts" "$reason"
      printf "%s\n" "$out"
    } >> "$inbox"
    bash "$HOME/.claude/hooks/hook-log.sh" "$logname" "candidate appended (reason=$reason)"
  else
    bash "$HOME/.claude/hooks/hook-log.sh" "$logname" "no candidate (reason=$reason)"
  fi
' _ "$tp" "$INBOX" "$reason" "$CLAUDE" "$LOG_NAME" >/dev/null 2>&1 &

exit 0
