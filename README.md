# skills

개인 Claude Code 스킬 모음. 여러 PC에서 공용으로 쓰기 위해 git으로 동기화하고, 각 PC에서 `~/.claude/skills/` 로 symlink 한다.

## 구조

```
skills/
└── laftel/              # laftel 업무용 스킬
    └── las-status/      # LAS 근무 상태 변경 (출근/복귀/자리비움/식사/퇴근)
        └── SKILL.md
```

Claude Code는 `~/.claude/skills/<name>/SKILL.md` 를 자동 발견한다. repo의 그룹 폴더(`laftel/`)는 정리용일 뿐이라, 각 스킬을 개별 symlink 한다.

## 새 PC 셋업

```bash
# 1. 원하는 위치에 clone
git clone git@github.com:ryu-mg/skills.git ~/laftel/skills

# 2. 각 스킬을 ~/.claude/skills/ 로 symlink
mkdir -p ~/.claude/skills
ln -s ~/laftel/skills/laftel/las-status ~/.claude/skills/las-status
```

clone 경로가 다르면 symlink 대상 경로만 맞추면 된다.

## 업데이트

- 스킬 수정/추가 → repo에서 `git add . && git commit && git push`
- 다른 PC → `git pull`. symlink라 즉시 반영된다.
- 새 스킬을 추가하면 각 PC에서 symlink 한 줄만 더 걸면 된다.
