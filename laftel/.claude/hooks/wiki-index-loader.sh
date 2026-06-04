#!/usr/bin/env bash
# SessionStart 훅: LLM 위키(ryu.mg/wiki) index.md 를 컨텍스트에 올린다.
# Obsidian 앱 불필요 — iCloud 볼트 파일을 직접 읽는다. 실패 시 조용히 exit 0.

INDEX="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/ryu.mg/wiki/index.md"
[ -r "$INDEX" ] || exit 0

CONTENT=$(cat "$INDEX" 2>/dev/null)
[ -n "$CONTENT" ] || exit 0

echo "=== LLM Wiki Index (ryu.mg/wiki) ==="
echo "개인 세컨드 브레인 위키의 전체 페이지 카탈로그다. 위키 관련 질문/작업 시"
echo "해당 페이지를 Read 또는 mcp-obsidian 으로 열어 참조하라."
echo "볼트 경로: $(dirname "$INDEX")"
echo
printf '%s\n' "$CONTENT"
echo
echo "=== End Wiki Index ==="
exit 0
