#!/usr/bin/env bash
# SessionStart 훅: 평일 + 미출근이면 출근 안내를 출력한다.
# 그 외 상태(출근/자리비움/식사/퇴근/휴가)나 주말, 또는 조회 실패 시 조용히 종료.
# 세션 시작을 절대 막지 않도록 모든 종료 경로는 exit 0.

# 종료 직전 공통 로거에 결과 한 줄 남기고 종료
log_exit() { bash "$HOME/.claude/hooks/hook-log.sh" las-checkin "$1"; exit 0; }

# 평일(월~금)만. 주말이면 종료.
[ "$(date +%u)" -le 5 ] || log_exit "주말 — skip"

CONFIG="$HOME/.claude.json"
[ -f "$CONFIG" ] || log_exit "config 없음 — skip"

TOKEN=$(python3 - "$CONFIG" <<'PY' 2>/dev/null
import json, sys
try:
    config = json.load(open(sys.argv[1]))
    print(config["mcpServers"]["laftel-las"]["headers"]["Authorization"])
except Exception:
    pass
PY
)
[ -n "$TOKEN" ] || log_exit "토큰 없음 — skip"

TODAY=$(date +%F)
RESPONSE=$(curl -s --max-time 3 -H "Authorization: $TOKEN" \
  "https://las.lafty.org/api/attendance/daily?date=$TODAY" 2>/dev/null)
[ -n "$RESPONSE" ] || log_exit "응답 없음/네트워크 실패 — skip"

CURRENT_STATUS=$(printf '%s' "$RESPONSE" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("workStats", {}).get("currentStatus"))
except Exception:
    print("ERROR")
' 2>/dev/null)

# currentStatus 가 null(미출근)일 때만 안내. python 은 null 을 "None" 으로 출력.
[ "$CURRENT_STATUS" = "None" ] || log_exit "현재상태=$CURRENT_STATUS — 안내 안함"

cat <<'EOF'
[LAS] 오늘 아직 미출근 상태입니다. 출근하시겠어요?
근무지를 알려주시면 바로 처리해 드릴게요 — 여의도 / 샛강 / 재택 / 외근
(원치 않으면 무시하셔도 됩니다.)
EOF
log_exit "미출근 — 출근 안내 출력"
