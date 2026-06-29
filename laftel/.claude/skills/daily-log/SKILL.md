---
name: daily-log
description: 특정 날짜에 내가 진행한 Jira 티켓(assignee=me + 그날 updated)과 Slack에서 나눈 이야기(내가 보낸 메시지 + 참여한 스레드 전체)를 조회해 LLM 위키(~/ryu-mg/wiki)의 날짜별 데일리 로그 노트로 정리하고 commit/push 한다. 매일 1회 루틴으로 도는 것을 전제. 날짜를 안 주면 어제로 진행하고, 같은 날짜 노트가 이미 있으면 새로 조회해 갱신한다. "데일리 로그", "오늘 한 일 정리", "어제 뭐 했는지 위키에", "daily log", "내 하루 정리", "어제 일지", "Jira slack 하루 정리" 등에 반응.
---

# 데일리 로그 (Jira + Slack → 위키)

특정 날짜 하루의 내 활동(Jira 티켓 + Slack 대화)을 모아 위키 `notes/daily/YYYY-MM-DD.md` 한 파일로 정리한다. 위키 위치: `~/ryu-mg/wiki` (repo `ryu-mg/llm-wiki`).

curation 스킬인 [wiki-capture]와 성격이 다르다 — 이건 **하루 활동의 기계적 기록(스트림)** 이지, 엄선된 지식이 아니다. 그래서 `index.md`는 건드리지 않고 `log.md`(시간순·grep)만 색인으로 쓴다.

## 0. 항상 먼저

위키 스키마 `~/ryu-mg/wiki/CLAUDE.md`를 읽고 frontmatter·언어(한국어 기본, 기술용어 원문)·log.md append 규칙을 따른다. **단, 데일리 로그의 디렉토리·색인 정책은 아래 이 스킬 규칙이 우선**한다(스키마 협의 완료 사항).

## 1. 날짜 결정

- 인자로 날짜(`YYYY-MM-DD` 또는 "어제"/"6월 28일" 등)를 받으면 그 날짜.
- 없으면 **어제**: `date -v-1d +%F` (macOS).
- 대상 파일: `~/ryu-mg/wiki/notes/daily/YYYY-MM-DD.md`. 이미 있으면 갱신 모드(아래 5).

## 2. 신원 확인 (한 번)

- **Jira**: `atlassianUserInfo`로 내 계정 확인. `getAccessibleAtlassianResources`로 `cloudId` 확보(laftel 사이트).
- **Slack**: 내 `user_id`는 `slack_search_public_and_private` 도구 설명의 *"Current logged in user's user_id is ..."* 에 명시돼 있다 — 그걸 그대로 `from:<@USER_ID>`에 쓴다. 하드코딩하지 말고 매번 도구 설명에서 읽는다.

## 3. Jira 조회

`searchJiraIssuesUsingJql` (cloudId, jql, fields, maxResults 100):

```
jql: assignee = currentUser() AND updated >= "YYYY-MM-DD" AND updated < "YYYY-MM-DD+1일" ORDER BY updated DESC
fields: ["summary","status","issuetype","priority","updated","comment"]
responseContentFormat: markdown
```

- `+1일`은 다음 날 날짜(예: 대상 06-28 → `updated < "2026-06-29"`). 그날 하루 경계.
- 각 티켓: key, summary, status, 그날 내가 단 코멘트/변경 요지. 코멘트가 많으면 그날(`updated` 날짜) 것만 추려 1–2줄 요약.
- 0건이면 "Jira: 활동 없음" 으로 둔다(억지로 채우지 않음).

## 4. Slack 조회

`slack_search_public_and_private` 로 내가 그날 친 메시지를 수집한다:

```
query: from:<@USER_ID> on:YYYY-MM-DD
sort: timestamp, sort_dir: asc, limit: 20, response_format: concise
```

- `response_format: concise` 로 응답 크기를 줄인다. 바쁜 날은 검색 결과가 커서 **컨텍스트 토큰 한도를 넘긴다** — 그러면 도구가 결과를 파일로 저장하고 경로를 알려준다.
- 페이지가 더 있으면 `cursor`로 이어 받아 그날 메시지를 모두 수집(20개 초과 가능).

**바쁜 날(결과가 크거나 파일로 떨어진 경우) — 서브에이전트에 위임한다** (메인 컨텍스트 보호):
- `general-purpose` 서브에이전트를 띄워 저장된 파일을 **character range 슬라이스**(`python3 -c "print(open('경로').read()[A:B])"`, ~80,000자 span 반복)로 100% 읽게 한다. Read offset/limit 은 줄이 길어 안 먹힌다.
- 서브에이전트에 시킬 것: 채널/DM/스레드별로 "누가·무슨 논의·결론"을 주제 단위로 압축 요약, 채널명·스레드 ts 식별, 업무/기술 위주(사적 잡담은 1줄), 추측은 "추정" 표시. 반환할 내용을 명시적으로 적어줄 것(막연한 "요약해줘" 금지).

**스레드 맥락 복원**: 요약 대상 중 스레드(부모/답글)인 항목은 `slack_read_thread`(channel_id, message_ts=부모 ts)로 스레드 전체를 읽어 상대 답변까지 포함. 같은 스레드는 한 번만. (서브에이전트에 위임했으면 거기서 함께 처리하게 지시.)

- 채널/DM별로 묶어 **주제 단위 요약**. 원문 복붙 금지 — "무슨 논의를 누구와, 결론이 뭐였나"로 압축.
- DM/비공개 채널은 민감할 수 있으니 사실 위주, 과도한 사적 내용 제외.
- 0건이면 "Slack: 활동 없음".

## 5. 데일리 로그 노트 작성

**Jira·Slack 둘 다 0건이면 노트를 만들지 않는다** — 주말/휴무일에 빈 노트 + 커밋이 쌓이는 걸 막는다. "그날(YYYY-MM-DD) 활동 없음 — 노트 생략" 한 줄 보고하고 끝낸다(commit/push도 안 함). 단 갱신 모드에서 기존 노트가 있으면 그건 건드리지 않는다.

`~/ryu-mg/wiki/notes/daily/YYYY-MM-DD.md` (폴더 없으면 생성). 템플릿:

```markdown
---
title: YYYY-MM-DD 데일리 로그
type: note
tags: [daily-log, jira, slack, <그날 토픽 태그…>]
created: YYYY-MM-DD      # 로그 대상 날짜
updated: <오늘 날짜>      # 이 노트를 만든/갱신한 날
---

# YYYY-MM-DD 데일리 로그

> 한 줄 요약: 이날 핵심 활동.

## Jira

| 티켓 | 제목 | 상태 | 그날 한 일 |
|---|---|---|---|
| [KEY-1234](url) | ... | In Progress | ... |

## Slack

### #채널 / 스레드 주제
- 누구와 무슨 논의 → 결론.

## 관련
- [[entities/laftel]] · [[그날 건드린 기존 entity/concept/note/sources …]]

## 메모 (수동)
<!-- 이 섹션은 자동 갱신 시 보존된다. 직접 메모 추가용. -->
```

### 그래프 연결 (중요)

Obsidian 그래프 뷰의 연결선은 **태그가 아니라 `[[wikilink]]`** 가 만든다. 데일리가 외딴 섬이 안 되려면 그날 건드린 **기존 위키 페이지로 링크**를 건다 — 시간이 쌓이면 `[[entities/laftel]]` 같은 허브가 모든 데일리를 묶는다.

1. **`## 관련` 섹션**: 노트 쓰기 전 `index.md` 를 스캔(또는 grep)해, 그날 작업/논의와 맞닿는 **이미 존재하는** 페이지(`entities/`·`concepts/`·`notes/`·`sources/`)를 골라 `[[…]]` 로 링크한다. 본문 안에서도 자연스러우면 인라인 wikilink. 거의 항상 `[[entities/laftel]]` 는 포함(업무 허브).
2. **새 페이지는 만들지 않는다**: 데일리는 기계적 스트림이라 새 concept/entity 를 자동 생성하면 고아·중복·저품질 stub 이 쌓인다(스키마 금기). 반복 등장하는 새 토픽(예: 어떤 기능·개념)이 보이면 **만들지 말고 보고만** 한다 — "`service_log` 가 자주 나옴, concept 페이지 만들까?" → 큐레이션은 [wiki-capture] 가 사용자 승인 받고 처리.
3. **토픽 태그 — 기존 어휘 재사용이 철칙**: 태그는 일관성이 없으면 검색이 파편화돼 무용지물이 된다(`service-log` vs `service_log` vs `재생`). 그래서 새로 짓기 전에 **위키의 기존 태그를 먼저 확인하고 매칭되는 걸 재사용**한다:
   ```bash
   grep -rh "^tags:" ~/ryu-mg/wiki --include="*.md" | sed 's/tags: *\[//; s/\]//; s/,/\n/g' | tr -d ' ' | grep -v '^$' | sort | uniq -c | sort -rn
   ```
   - 컨벤션: **lowercase-kebab 영문**(`claude-code`, `ai-agent`, `service-log`). 한글·snake_case·복수형 금지.
   - 매칭되는 기존 태그 있으면 그대로 쓴다. 동의어·유사 태그 새로 만들지 않는다.
   - 정말 없을 때만 컨벤션 맞춰 신규 1개 추가(시드). generic 3개(`daily-log, jira, slack`)는 항상 포함.
   - 태그는 **검색·필터 보조용**일 뿐 — 그래프 연결과 "나중에 찾기"의 주축은 1번 wikilink + Obsidian 전문검색 + `log.md` grep 이다. 태그를 과신하거나 남발하지 않는다(태그 pane 오염 방지).
4. (선택) 직전 데일리 파일이 있으면 `## 관련` 에 `[[notes/daily/전날]]` 를 걸어 시간순 체인을 만든다.

**갱신 모드(파일 존재)**: Jira·Slack·관련 섹션은 새로 조회한 내용으로 다시 쓰고, `## 메모 (수동)` 섹션이 있으면 그 내용을 **그대로 보존**한다. `updated`만 오늘로 갱신, `created`(대상 날짜)는 유지. 멱등 — 같은 날 여러 번 돌려도 안전.

## 6. 색인 + 커밋

1. `index.md`는 **건드리지 않는다**(데일리는 스트림이라 카탈로그 도배 방지).
2. `log.md` 맨 아래 append (append-only, 시간순):
   ```
   ## [<오늘 날짜>] daily | YYYY-MM-DD 데일리 로그
   - 생성/갱신: [[notes/daily/YYYY-MM-DD]]
   - 내용: Jira N건, Slack 주요 논의 M건 요약 (1줄).
   ```
3. commit + push:
   ```bash
   cd ~/ryu-mg/wiki && git add -A && git commit -m "daily: YYYY-MM-DD 데일리 로그" && git push
   ```
4. 무엇을 담았는지 한 줄 보고(Jira N건 / Slack M주제 / 파일 경로).

## 금기

- `index.md` 도배 금지(log.md만 색인). `raw/` 수정 금지. `## 메모 (수동)` 내용 덮어쓰기 금지. 확실하지 않은 사실 단정 금지("추정"·"확인 필요" 명시). Slack 사적 내용 과다 수록 금지.

## 루틴 등록 (참고)

매일 자동 실행은 `/schedule`(cron 클라우드 에이전트) 또는 `/loop`로 이 스킬을 날짜 인자 없이(=어제) 돌게 걸면 된다. 등록 자체는 이 스킬 밖의 일.
