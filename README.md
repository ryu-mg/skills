# skills

개인 Claude Code 스킬 모음. 여러 PC에서 공용으로 쓰기 위해 git으로 동기화하고, 각 PC에서 `~/.claude/skills/` 로 symlink 한다.

## 구조

실제 `~/.claude/skills/` 경로를 그대로 미러링한다. 조직(`laftel/`)별로 묶고 그 아래 `.claude/skills/<skill>` 구조를 둔다.

```
skills/
└── laftel/
    └── .claude/
        └── skills/
            ├── las-status/        # LAS 근무 상태 변경 (출근/복귀/자리비움/식사/퇴근)
            │   └── SKILL.md
            ├── calendar-meeting/  # 회의 일정 잡기
            │   └── SKILL.md
            ├── server-claim-deploy/      # Laftel IDP 환경 점유 + 배포
            │   └── SKILL.md
            └── server-occupancy-status/  # Laftel IDP 환경 점유 현황 조회
                └── SKILL.md
```

> `server-*` 두 스킬은 `laftel-backend-skills` 마켓플레이스 플러그인에도 존재한다. 여기 사본은 개인 fork이며, 같은 이름이 플러그인에도 있으면 플러그인이 우선 적용된다. 팀 플러그인 업데이트와 드리프트할 수 있음에 주의.

Claude Code는 `~/.claude/skills/<name>/SKILL.md` 를 자동 발견한다. 각 스킬 디렉토리를 개별 symlink 한다.

## 새 PC 셋업

```bash
# 1. clone (개인계정 멀티 SSH면 github.com-myunggi alias 사용)
git clone git@github.com-myunggi:ryu-mg/skills.git ~/laftel/skills

# 2. 각 스킬을 ~/.claude/skills/ 로 symlink
mkdir -p ~/.claude/skills
SRC=~/laftel/skills/laftel/.claude/skills
ln -s "$SRC/las-status"             ~/.claude/skills/las-status
ln -s "$SRC/calendar-meeting"       ~/.claude/skills/calendar-meeting
ln -s "$SRC/server-claim-deploy"    ~/.claude/skills/server-claim-deploy
ln -s "$SRC/server-occupancy-status" ~/.claude/skills/server-occupancy-status
```

clone 경로가 다르면 `SRC` 만 맞추면 된다.

## 업데이트

- 스킬 수정/추가 → repo에서 `git add . && git commit && git push`
- 다른 PC → `git pull`. symlink라 즉시 반영된다.
- 새 스킬 추가 시 각 PC에서 symlink 한 줄만 더 걸면 된다.
