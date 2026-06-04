---
name: server-claim-deploy
description: >-
  Laftel IDP 환경에 브랜치를 점유 + 배포하고, 1분 간격으로 배포 완료를 폴링한 뒤 완료되면 알린다.
  사용자가 "feature-3에 내 브랜치 배포해줘", "이 브랜치 qa-2에 올려줘", "환경 점유하고 배포해줘",
  "배포 트리거 돌려줘", "feature-1에 dev 배포" 같은 배포 요청을 하면 반드시 이 스킬을 사용한다.
  타인이 이미 점유/배포한 환경이면 가로채기 여부를 먼저 사용자에게 묻는다. 기본 대상은 ott(laftel-server),
  사용자가 "store"를 명시하면 store도 가능하다.
---

# 서버 점유 및 배포

브랜치 + 환경을 받아 IDP로 배포를 트리거하고, 배포가 실제로 환경에 반영될 때까지 1분 간격으로 확인한 다음 완료를 알린다. 목적은 "트리거 → 탭 열어두고 기다리기 → 됐나 새로고침" 루틴을 자동화하는 것이다. 이미 다른 사람이 쓰던 환경을 모르고 덮어쓰는 사고를 막는 것도 핵심이다.

## 사용하는 MCP 도구

- `mcp__laftel-idp__get_deployment_status(service, force_refresh)` — 환경×role의 현재 실제 상태. 폴링과 baseline 확보에 쓴다.
- `mcp__laftel-idp__trigger_deployment(repo, ref, environment, deploy_type, force)` — GitHub Actions 배포 트리거. **타인 점유 슬롯이 있으면 `force=False`(기본)일 때 배포하지 않고 `action="skipped"` + `conflicts`를 반환**한다. 이 충돌 보호를 그대로 활용한다.

`repo`는 ott면 `"laftel-server"`, store면 store repo. `deploy_type`은 laftel-server에서 `all`/`api`/`staff` (미지정 시 all).

## 입력 파싱

사용자 발화에서 다음을 추출한다. 빠진 게 있으면 묻는다.

- **ref (브랜치/태그)**: 명시 안 하면 현재 체크아웃된 브랜치를 기본 후보로 제시하고 확인받는다 (`git rev-parse --abbrev-ref HEAD`).
- **environment**: `feature-3`, `qa-2` 등. 필수. 없으면 묻는다.
- **deploy_type**: api/staff/all. 명시 안 하면 `all`.
- **service**: 기본 ott. "store" 명시 시 store.

## 절차

### 1. 대상 슬롯 확정 + baseline 확보

**대상 슬롯 집합**을 먼저 정한다. laftel-server는 환경마다 `api`/`staff` 인스턴스가 따로 있다 (`instance_id`도 별개).
- `deploy_type="api"` → `(env, api)` 1개
- `deploy_type="staff"` → `(env, staff)` 1개
- `deploy_type="all"` (기본) → **`(env, api)` + `(env, staff)` 2개 모두**

`get_deployment_status(service, force_refresh=True)`로 대상 슬롯 **각각**의 현재 **실행 중** `branch`, `sha`, `last_deploy_at`을 baseline으로 기록한다. all이면 두 슬롯 baseline을 따로 둔다. 완료 판정의 기준점이다.

> **필드 의미 주의**: row의 `branch`/`sha`는 인스턴스에서 SSM으로 읽은 **실제 실행 중인 상태(현실)**. `last_deploy_ref`/`last_deploy_sha`는 마지막으로 **트리거된 의도**일 뿐 아직 롤아웃 안 됐을 수 있다 (idp 트리거 직후엔 `last_deploy_sha`가 빈 문자열, `branch`는 여전히 이전 브랜치). 그래서 완료 판정은 항상 **실행 중 `branch`/`sha`** 기준으로 본다.

### 2. 배포 트리거 (충돌 보호)

`trigger_deployment(repo, ref, environment, deploy_type, force=False)` 호출.

- **`action="deployed"`** → 충돌 없이 트리거됨. 3번으로.
- **`action="skipped"`** → `conflicts`에 타인 점유 슬롯이 있다. **여기서 임의로 force하지 말 것.** conflicts의 `current_user_email`, `claimed_at`과 (필요하면 get_deployment_status로 본) 현재 배포 브랜치를 사용자에게 보여주고 **가로채기 배포할지 명시적으로 묻는다.**
  - 사용자가 동의하면 `trigger_deployment(..., force=True)` 재호출.
  - 거부하면 중단하고 그대로 알린다.

가로채기는 남의 작업 환경을 덮어쓰는 행위다. 반드시 사용자 동의를 받고 진행한다.

**점유(claim) 확인**: `trigger_deployment`는 칠판 모델상 배포와 함께 호출자 점유를 확정하는 것으로 설계돼 있다 (force 시 `takeovers`로 이전 점유자 교체). 배포 성공 후 `get_claims(env_filter=environment)`로 대상 슬롯이 본인(`user_email`) 점유로 잡혔는지 확인한다. 안 잡혀 있으면 `claim_environment(environment, role)`를 호출해 명시적으로 점유한다 (스킬 이름 그대로 "점유 및 배포"를 보장).

### 3. 완료 폴링 (1분 간격)

배포 트리거 후 GitHub Actions 빌드 + ECS 롤아웃이 끝나야 환경에 반영된다. **1분에 한 번** `get_deployment_status(service, force_refresh=True)`로 대상 슬롯들을 확인한다.

**슬롯별 완료 판정**: 해당 슬롯의 **실행 중 `branch`**가 배포한 `ref`와 일치하고, 동시에 `sha` 또는 `last_deploy_at`이 **1번 baseline과 달라졌을 때** = 새 배포가 실제 인스턴스에 반영됨. (`branch`가 아직 이전 값이거나 sha/`last_deploy_at`이 baseline 그대로면 롤아웃 진행 중이므로 미완료.)

**전체 완료 판정**: `deploy_type="all"`이면 **api·staff 두 슬롯이 모두** 완료돼야 끝이다. 한쪽만 반영됐으면 아직 진행 중. (한 슬롯만 보고 완료 선언하는 실수 금지.)

**폴링 기전 — 루프 본문은 "체크"만, 배포 재트리거 절대 금지**:
- 사용자가 말한 "1분에 한 번 체크 → 완료 시 /loop 종료"를 구현한다. 이때 반복되는 것은 **상태 확인**이지 이 스킬(=배포) 전체가 아니다. `/loop`에 이 배포 스킬을 통째로 걸면 매분 재배포된다 — 하지 말 것.
- 구현: `ScheduleWakeup(delaySeconds=60, prompt=<완료 체크 재개 지시>)`로 60초 뒤 자신을 깨워 `get_deployment_status`만 다시 본다. 미완료면 다시 `ScheduleWakeup`, 완료면 다음 wakeup을 예약하지 않아 루프 종료 (`/loop` dynamic 모드의 1분 주기와 동일한 동작).
- `Monitor`는 shell 전용이라 MCP 도구(`get_deployment_status`) 폴링엔 못 쓴다. ScheduleWakeup를 쓴다.

- **타임아웃**: 약 15회(=15분) 폴링해도 미완료면 멈추고 "배포가 예상보다 오래 걸린다. GitHub Actions 확인 필요"라고 알린다. 무한 폴링 금지.
- row에 `error` 필드가 차 있으면 즉시 멈추고 에러를 보여준다.

### 4. 완료 알림

모든 대상 슬롯이 완료되면 폴링을 끝내고 사용자에게 알린다. `all`이면 슬롯별로 다 보여준다:

```
✅ 배포 완료
환경: feature-3 (all)
브랜치: feature/LAFTEL-6478-...
- api:   a1b2c3d (subject) — 2026-05-29 09:32 (KST)
- staff: a1b2c3d (subject) — 2026-05-29 09:33 (KST)
```

## 주의

- baseline을 안 잡고 폴링하면 "원래 반영돼 있던 상태"와 "방금 내가 배포한 상태"를 구분 못 한다. 1번을 건너뛰지 말 것.
- `ref`가 브랜치면 tip sha가 트리거 시점에 정해진다. 로컬에 브랜치가 있으면 `git rev-parse origin/<ref>`로 목표 sha를 미리 확인해 완료 판정을 더 정확히 할 수 있다 (선택).
- store는 IDP 미연동일 수 있다. trigger 결과가 비정상이면 store는 별도 CI/CD라고 알린다.
