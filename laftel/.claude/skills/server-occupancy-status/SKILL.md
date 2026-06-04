---
name: server-occupancy-status
description: >-
  Laftel IDP 환경(feature-N, qa-N)의 점유 현황을 조회해 "점유 중인 서버"와 "점유 가능한 서버"를
  두 개의 테이블로 보여준다. 사용자가 "점유 서버 보여줘", "서버 현황", "점유 가능한 서버", "비어있는 서버",
  "누가 어디 점유했어", "feature 환경 누가 쓰고 있어", "qa 서버 현황" 같은 말을 하면 반드시 이 스킬을 사용한다.
  기본 대상은 ott(laftel-server)이고, 사용자가 "store"를 명시하면 store도 조회한다.
---

# 서버 점유 현황 조회

Laftel IDP가 관리하는 배포 환경의 점유 상태를 한눈에 보여준다. Slack 칠판으로 일일이 확인하던 걸 대체하는 용도다. 누가 어떤 환경을 어떤 브랜치로 언제부터 점유 중인지, 그리고 지금 비어 있어 바로 쓸 수 있는 환경이 무엇인지 빠르게 파악하는 게 목적이다.

## 사용하는 MCP 도구

- `mcp__laftel-idp__get_deployment_status(service)` — 환경×role 전체 목록. 각 row에 `environment, env_label, role, branch, sha, subject, claim_user_email, last_deploy_at` 등이 들어 있다. **환경 universe와 (현재 실행 중인) 브랜치, 점유자**를 여기서 얻는다. `env_label`에 부가 설명이 붙기도 한다 (예: `qa-1 (store 전용)`).
- `mcp__laftel-idp__get_claims(env_filter)` — 점유 슬롯별 `environment, role, user_email, claimed_at`. **점유 날짜(claimed_at)**는 여기에만 있으므로 반드시 함께 호출해 조인한다.

`service` 기본값은 `ott`. 사용자가 store를 명시하면 `service="store"`로도 호출한다.

## 절차

1. `get_deployment_status`와 `get_claims`를 **한 턴에 같이 호출**한다 (서로 의존 없음).
2. 두 결과를 `(environment, role)` 키로 조인한다.
   - **점유 중**: `claim_user_email`이 있거나 `get_claims`에 대응 슬롯이 있는 row.
   - **점유 가능**: 점유자가 없는 row.
3. 아래 두 테이블로 출력한다.

## 출력 형식

환경과 role을 합쳐 `feature-3 (api)`처럼 한 칸에 표기한다. role을 구분해야 점유 슬롯이 정확해진다 (laftel-server는 환경마다 api/staff 슬롯이 따로 있다). `env_label`에 `(store 전용)` 같은 표시가 있으면 환경 칸에 함께 보여준다.

`claimed_at`은 UTC ISO로 오므로 **KST(UTC+9)로 변환**해 `YYYY-MM-DD HH:MM` 형식으로 보여준다.

**점유 중인 서버:**

| 점유 환경 | 점유자 | 브랜치 | 점유 날짜 |
|-----------|--------|--------|-----------|
| feature-3 (api) | bao@laftel.net | feature/LAFTEL-6478-... | 2026-05-29 09:15 |

**점유 가능한 서버:**

| 점유 환경 |
|-----------|
| feature-1 (staff) |
| qa-2 (api) |

## 주의

- 두 도구 결과가 어긋날 수 있다 (`get_deployment_status`엔 점유자 표시가 있는데 `get_claims`엔 슬롯이 없는 등). 이때 점유 여부는 **둘 중 하나라도 점유자가 있으면 점유 중**으로 본다. 점유 날짜를 못 구하면 그 칸은 `-`로 둔다.
- store는 IDP 미연동이라 결과가 비어 있을 수 있다. 비어 있으면 "store는 IDP에 점유/배포 기록이 없음"이라고 알린다.
- 점유 슬롯이 많으면 환경 번호 순으로 정렬해 보기 좋게 한다.
