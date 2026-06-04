#!/usr/bin/env bash
# SessionStart 훅: 개인 스킬 레포(ryu-mg/skills)를 git pull 하고
# 레포의 스킬/훅을 ~/.claude/{skills,hooks}/ 로 심링크 한다 (미러 패턴).
#
# 안전 원칙:
# - 세션 시작을 절대 막지 않도록 모든 실패 경로는 exit 0.
# - 파괴적 동작 없음: 우리 레포를 가리키는 심링크만 생성/유지한다.
#   실디렉토리·다른 타겟 심링크는 건드리지 않고 경고만 출력한다.
# - git pull 은 ConnectTimeout 으로 hang 을 막고, 실패해도(오프라인/충돌) 무시한다.

REPO="$HOME/laftel/skills"
[ -d "$REPO/.git" ] || exit 0

SKILLS_SRC="$REPO/laftel/.claude/skills"
HOOKS_SRC="$REPO/laftel/.claude/hooks"

# 1. 원격 최신 형상 반영 (네트워크 hang 방지, 실패 무시)
GIT_SSH_COMMAND="ssh -o ConnectTimeout=5 -o BatchMode=yes" \
  git -C "$REPO" pull --quiet --ff-only 2>/dev/null

created=()
warnings=()

# $1=소스 glob (따옴표 없이 확장), $2=타겟 부모 디렉토리
link_glob() {
  local pattern="$1" dest_parent="$2"
  mkdir -p "$dest_parent"
  local item name dest target
  for item in $pattern; do
    [ -e "$item" ] || continue          # glob 미매치 시 리터럴 방지
    name=$(basename "$item")
    dest="$dest_parent/$name"
    if [ -L "$dest" ]; then
      target=$(readlink "$dest")
      case "$target" in
        "$REPO"/*) continue ;;          # 우리 레포 가리킴 → 이미 OK
        *) warnings+=("$dest → $target (다른 타겟, 건너뜀)"); continue ;;
      esac
    elif [ -e "$dest" ]; then
      warnings+=("$dest (실파일/디렉토리 존재, 건너뜀 — 수동으로 심링크 전환 필요)")
      continue
    fi
    ln -s "$item" "$dest" && created+=("$dest")
  done
}

link_glob "$SKILLS_SRC/*" "$HOME/.claude/skills"
link_glob "$HOOKS_SRC/*" "$HOME/.claude/hooks"

# 2. 변경/경고가 있을 때만 출력 (없으면 침묵)
if [ ${#created[@]} -gt 0 ] || [ ${#warnings[@]} -gt 0 ]; then
  echo "[개인 스킬 동기화]"
  for created_path in "${created[@]}"; do
    echo "  + 심링크 생성: $created_path"
  done
  for warning in "${warnings[@]}"; do
    echo "  ⚠ $warning"
  done
fi

exit 0
