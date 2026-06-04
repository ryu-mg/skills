# skills

개인 Claude Code 스킬 모음. 여러 PC에서 공용으로 쓰기 위해 git으로 동기화하고, 각 PC에서 `~/.claude/skills/` 로 symlink 한다.

## 구조

실제 `~/.claude/{skills,hooks}/` 경로를 그대로 미러링한다. 조직(`laftel/`)별로 묶고 그 아래 `.claude/skills/<skill>`, `.claude/hooks/<hook>` 구조를 둔다.

```
skills/
└── laftel/
    └── .claude/
        ├── skills/
        │   ├── las-status/                # LAS 근무 상태 변경 (출근/복귀/자리비움/식사/퇴근)
        │   ├── calendar-meeting/          # 회의 일정 잡기
        │   ├── server-claim-deploy/       # Laftel IDP 환경 점유 + 배포
        │   └── server-occupancy-status/   # Laftel IDP 환경 점유 현황 조회
        └── hooks/
            ├── sync-personal-skills.sh    # SessionStart: 레포 pull + 스킬/훅 자동 심링크
            ├── las-checkin-prompt.sh      # SessionStart: 평일 미출근 시 출근 안내
            └── wiki-index-loader.sh       # SessionStart: 위키 index 컨텍스트 주입
```

> `server-*` 두 스킬은 `laftel-backend-skills` 마켓플레이스 플러그인에도 존재한다. 여기 사본은 개인 fork이며, 같은 이름이 플러그인에도 있으면 플러그인이 우선 적용된다. 팀 플러그인 업데이트와 드리프트할 수 있음에 주의.

Claude Code는 `~/.claude/skills/<name>/SKILL.md` 와 `~/.claude/hooks/<hook>` 를 자동 발견한다. 각 항목을 개별 symlink 한다.

## 새 PC 셋업

```bash
# 1. clone (개인계정 멀티 SSH면 github.com-myunggi alias 사용)
git clone git@github.com-myunggi:ryu-mg/skills.git ~/laftel/skills

# 2. sync 훅을 직접 한 번 실행 → 모든 스킬/훅이 ~/.claude/{skills,hooks}/ 로 자동 심링크
bash ~/laftel/skills/laftel/.claude/hooks/sync-personal-skills.sh

# 3. sync 훅을 SessionStart 에 등록 → 이후 세션마다 자동 pull + 심링크
#    ~/.claude/settings.json 의 hooks.SessionStart 배열에 추가:
#      { "hooks": [ { "type": "command",
#                     "command": "bash ~/.claude/hooks/sync-personal-skills.sh",
#                     "timeout": 15 } ] }
```

clone 경로가 `~/laftel/skills` 가 아니면 `sync-personal-skills.sh` 안의 `REPO` 변수를 맞춘다.

## 업데이트

sync 훅이 등록된 PC에서는 **세션을 켤 때마다 자동으로** `git pull` + 새 항목 심링크가 된다.

- 스킬/훅 수정·추가 → repo에서 `git add . && git commit && git push`
- 다른 PC → 다음 세션 시작 시 자동 반영 (즉시 반영하려면 `git pull`. symlink라 내용은 바로 보인다)
- sync 훅은 **우리 레포를 가리키는 심링크만** 만든다. 같은 이름이 실디렉토리거나 다른 타겟이면 건드리지 않고 경고만 출력한다 → 수동으로 정리한다.
