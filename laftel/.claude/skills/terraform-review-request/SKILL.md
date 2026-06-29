---
name: terraform-review-request
description: >
  laftel-terraform 레포에서 현재 브랜치 PR을 일일 [테라폼 PR] 슬랙 스레드에 요약해 올리고
  마지막에 @june(이현주) 을 멘션해 테라폼 리뷰를 요청한다. #팀_백엔드 채널의
  "[테라폼 PR] @June @Brandon" 메시지를 오늘자→(없으면)어제자 순으로 찾아 그 스레드에 단다.
  laftel-terraform 레포가 아니면 동작하지 않는다. 전송 전 항상 초안을 사용자에게 보여 컨펌받는다.
  "준한테 리뷰 요청", "june 리뷰 요청", "PR 리뷰 요청 슬랙에 올려줘", "리뷰 요청해줘",
  "테라폼 리뷰 요청", "테라폼 PR 스레드에 올려줘" 등의 요청 시 사용한다.
allowed-tools: >
  Bash(git *),
  Bash(gh *),
  Bash(date *),
  mcp__plugin_slack_slack__slack_search_public,
  mcp__plugin_slack_slack__slack_send_message
---

# Terraform Review Request (laftel-terraform → June)

현재 브랜치의 PR을 **일일 `[테라폼 PR]` 슬랙 스레드**에 팀 포맷대로 요약해 올리고, 끝에 **@june** 을 멘션해 테라폼 리뷰를 요청한다.

왜 이런 흐름인가: 백엔드팀은 `#팀_백엔드` 채널에 매일 `[테라폼 PR] @June @Brandon` PR 현황 메시지를 올리고, 테라폼 리뷰 요청은 그 스레드 안에 모은다. 그래서 새 메시지를 채널에 따로 던지지 않고, 그날 스레드를 찾아 그 안에 단다. (OTT 앱 PR 은 별도 `[OTT PR]` 스레드를 쓰며 이 스킬 대상 아니다.)

## 0. 가드 — laftel-terraform 레포에서만 동작

이 스킬은 테라폼 리뷰 전용이다. 시작 전 현재 레포가 laftel-terraform 인지 확인한다:

```bash
git remote get-url origin   # laftel-team/laftel-terraform 이어야 함
```

`laftel-terraform` 이 아니면 **즉시 멈추고** 사용자에게 알린다: "이 스킬은 laftel-terraform 레포 전용입니다. 현재 레포: {origin}." (다른 레포 PR 을 테라폼 리뷰 스레드에 올리지 않는다.)

PR URL 을 인자로 받은 경우에도 그 URL 이 `github.com/laftel-team/laftel-terraform` 인지 확인하고, 아니면 같은 사유로 멈춘다.

## 고정 식별자

| 항목 | 값 |
|---|---|
| 채널 (`#팀_백엔드`) | `C01HYHCBZL4` |
| 일일 메시지 텍스트 | `[테라폼 PR] @June @Brandon ...` |
| @june (이현주, 리뷰어) | `UCPBMQP5W` → 멘션 `<@UCPBMQP5W>` |

## 워크플로우

### 1. 그날의 [테라폼 PR] 스레드 찾기

오늘 날짜로 검색한다. 봇/수동 메시지 모두 잡히게 `include_bots: true` 를 켠다(빼면 봇 메시지 누락).

```
오늘 = date +%F          # 예: 2026-06-29
어제 = date -v-1d +%F
```

`slack_search_public` 호출:
- `query`: `"[테라폼 PR]" in:<#C01HYHCBZL4> on:{오늘}`
- `include_bots`: `true`
- `include_context`: `false`

결과의 `Message_ts`(예: `1782707476.293419`)가 스레드 부모다. 이걸 `thread_ts` 로 쓴다.

**오늘자 0건이면** 같은 쿼리를 `on:{어제}` 로 재검색한다. 어제도 0건이면 사용자에게 알리고 멈춘다(임의로 채널에 새 메시지 만들지 않는다).

### 2. 현재 브랜치 PR 조회

```bash
branch=$(git branch --show-current)
gh pr list --head "$branch" --json number,url,title,state,statusCheckRollup
```

- PR URL 을 인자로 받았으면 그걸 우선 사용한다(`gh pr view <url|번호>`). 단, 0단계 가드대로 laftel-terraform PR 인지 먼저 확인.
- PR 없으면: 사용자에게 알리고 멈춘다(필요하면 `/create-pr` 먼저 쓰라고 안내).
- PR 여러 개면 사용자에게 어느 것인지 확인한다.

CI 상태 도출: `statusCheckRollup` 의 모든 `conclusion` 이 `SUCCESS` → "통과". 하나라도 `FAILURE`/`null`(진행 중) → 그 상태를 그대로 적는다("실패", "진행 중").

Plan 요약(있으면, best-effort): 이 레포는 CI 가 PR 코멘트에 plan 결과를 단다. 한 줄 요약을 끌어오면 메시지가 풍부해진다.

```bash
gh pr view <num> --json comments \
  --jq '.comments[].body' | grep -iE "^Plan: [0-9]" | tail -1
```

안 잡히면 Plan 줄은 생략한다. 게이트 아님.

### 3. 메시지 작성 (팀 포맷)

아래 포맷을 그대로 따른다:

```
*:white_check_mark: PR #{번호} 리뷰 준비 완료*

[{KEY}-{번호}] {PR 제목}
<{pr_url}|{pr_url 에서 github.com/... 부분}>

*내용*
- {변경 요약 1}
- {변경 요약 2}
- ...

*CI*
- {통과/실패/진행 중} / Plan: {plan 한 줄, 있으면}

<@UCPBMQP5W> 리뷰 부탁드립니다 :pray::skin-tone-2:
```

규칙:
- **헤더**: `*:white_check_mark: PR #{번호} 리뷰 준비 완료*` — 볼드(`*`)만, 대괄호 `[ ]` 없음, 기울임 없음. ✅ 렌더.
- **제목 줄**: `[{KEY}-{번호}] {PR 제목}`. `{KEY}-{번호}` 는 PR 제목/브랜치에서 추출(LAFTEL/STORE/GLOBAL, 기본 LAFTEL).
- **GitHub 링크 줄**: 슬랙 링크 문법 `<{pr_url}|github.com/laftel-team/laftel-terraform/pull/{번호}>`. (Jira 링크는 넣지 않는다.)
- **`*내용*`**: PR 의 핵심 변경을 불릿 2~5개로. PR 본문 `## 변경` 섹션이나 diff 에서 뽑는다. 코드 식별자는 `백틱`.
- **`*CI*`**: CI 상태 + plan 한 줄. plan 못 구하면 `/ Plan: ...` 생략하고 상태만.
- **마지막 줄**: `<@UCPBMQP5W> 리뷰 부탁드립니다 :pray::skin-tone-2:` 항상 포함. terraform GitOps라 **머지 = apply** 이므로 리뷰가 곧 배포 게이트다.

### 4. 전송 전 컨펌 (필수)

슬랙 전송은 외부로 나가는 되돌릴 수 없는 동작이다. **보내기 전 반드시 초안 전문 + 채널/스레드/멘션 대상을 사용자에게 보여주고 승인받는다.** 사용자가 문구를 고치라고 하면 반영 후 다시 보여준다.

### 5. 전송

승인되면 `slack_send_message`:
- `channel_id`: `C01HYHCBZL4`
- `thread_ts`: 1단계에서 찾은 스레드 부모 ts
- `message`: 3단계 본문

전송 후 반환된 `message_link` 를 사용자에게 보고한다.

## 예시

**상황**: PR #520, LAFTEL-7182, CI 통과, plan `0 add, 1 change, 0 destroy`.

전송 메시지:
```
*:white_check_mark: PR #520 리뷰 준비 완료*

[LAFTEL-7182] CI role ecs:RunTask 추가 (migration run-task)
<https://github.com/laftel-team/laftel-terraform/pull/520|github.com/laftel-team/laftel-terraform/pull/520>

*내용*
- `laftel-ott-ci-policy.json` 에 `ECSRunMigrationTask` statement 추가 (`ecs:RunTask`, cluster condition 한정)
- #519(PassRole) 후속 — dev 배포 migrate 잡 run-task 권한 갭 (workflow 전체 감사, 마지막 갭)

*CI*
- 통과 / Plan: 0 add, 1 change, 0 destroy (IAM in-place)

<@UCPBMQP5W> 리뷰 부탁드립니다 :pray::skin-tone-2:
```
