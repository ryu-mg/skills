#!/usr/bin/env bash
# SessionEnd hook: enqueue ended Claude Code transcripts for LLM-wiki capture.
# A single background worker processes the queue, filters low-signal sessions, and
# asks headless claude(haiku) only when the transcript looks worth classifying.
#
# Safety:
# - SessionEnd path is cheap: enqueue + best-effort worker start + exit 0.
# - mkdir-based lock keeps at most one worker running.
# - Duplicate transcript paths are skipped after the first completed processing.
# - Failures never block Claude sessions.

INBOX="$HOME/ryu-mg/wiki/notes/_inbox.md"
QUEUE_DIR="$HOME/.claude/wiki-session-capture-queue"
DONE_DIR="$QUEUE_DIR/done"
LOCK_DIR="$QUEUE_DIR/.worker.lock"
LOG_NAME=wiki-session-capture
MAX_QUEUE_ITEMS=200

log() {
  bash "$HOME/.claude/hooks/hook-log.sh" "$LOG_NAME" "$1"
}

hash_key() {
  printf '%s' "$1" | shasum | awk '{print $1}'
}

worker_should_consider() {
  # $1 is the transcript tail. Keep this deliberately conservative: skip only
  # sessions that are dominated by startup/hook metadata or are too small.
  local body="$1"
  local bytes
  bytes=$(printf '%s' "$body" | wc -c | tr -d ' ')
  [ "${bytes:-0}" -ge 2500 ] || return 1

  if printf '%s' "$body" | grep -q '너는 LLM 위키 큐레이션 보조다'; then
    return 1
  fi

  if printf '%s' "$body" | grep -Eq 'tool_use|git diff|git status|error|Error|Exception|bug|fix|수정|버그|장애|원인|해결|결정|근거|runbook|http[s]?://'; then
    return 0
  fi

  return 1
}

run_capture() {
  local tp="$1" reason="$2" claude="$3" key="$4"
  local ts body out

  if [ ! -r "$tp" ]; then
    log "skip unreadable transcript"
    return 0
  fi

  body=$(tail -c 120000 "$tp" 2>/dev/null)
  if ! worker_should_consider "$body"; then
    : > "$DONE_DIR/$key"
    log "filtered low-signal transcript (reason=$reason)"
    return 0
  fi

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

  out=$("$claude" -p "$prompt
<transcript>
$body
</transcript>" --model haiku --settings "{\"advisorModel\":\"haiku\"}" --output-format text 2>/dev/null)

  if printf '%s' "$out" | grep -q "^### "; then
    {
      printf "\n---\n<!-- session-capture %s reason=%s -->\n" "$ts" "$reason"
      printf "%s\n" "$out"
    } >> "$INBOX"
    log "candidate appended (reason=$reason)"
  else
    log "no candidate (reason=$reason)"
  fi

  : > "$DONE_DIR/$key"
}

run_worker() {
  local claude job tp reason key count

  mkdir -p "$QUEUE_DIR" "$DONE_DIR" || exit 0
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
  fi
  trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM

  claude=$(command -v claude)
  if [ -z "$claude" ] || [ ! -d "$HOME/ryu-mg/wiki/.git" ]; then
    log "worker skip (claude=${claude:+y} wiki=$([ -d "$HOME/ryu-mg/wiki/.git" ] && printf y))"
    exit 0
  fi

  count=0
  for job in "$QUEUE_DIR"/*.job; do
    [ -e "$job" ] || break
    count=$((count + 1))
    [ "$count" -le "$MAX_QUEUE_ITEMS" ] || break

    IFS="$(printf '\t')" read -r tp reason < "$job"
    key=$(hash_key "$tp")

    if [ -e "$DONE_DIR/$key" ]; then
      rm -f "$job"
      log "duplicate skipped"
      continue
    fi

    run_capture "$tp" "${reason:-other}" "$claude" "$key"
    rm -f "$job"
  done
}

enqueue_and_start_worker() {
  local input tp reason job

  input=$(cat)
  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  reason=$(printf '%s' "$input" | jq -r '.reason // "other"' 2>/dev/null)

  if [ -z "$tp" ] || [ ! -r "$tp" ] || [ ! -d "$HOME/ryu-mg/wiki/.git" ]; then
    log "skip enqueue (tp=${tp:+y} wiki=$([ -d "$HOME/ryu-mg/wiki/.git" ] && printf y))"
    exit 0
  fi

  mkdir -p "$QUEUE_DIR" "$DONE_DIR" || exit 0
  job="$QUEUE_DIR/$(date +%Y%m%d%H%M%S)-$$-${RANDOM:-0}.job"
  printf '%s\t%s\n' "$tp" "${reason:-other}" > "$job"
  log "queued (reason=${reason:-other})"

  nohup "$0" --worker >/dev/null 2>&1 &
}

case "${1:-}" in
  --worker)
    run_worker
    ;;
  *)
    enqueue_and_start_worker
    ;;
esac

exit 0
