---
name: las-status
description: Change the user's LAS (Laftel Attendance System) work status via the laftel-las MCP — 출근/근무지 변경, 복귀, 자리비움, 식사, 퇴근. Use this whenever the user says things like "출근", "여의도 출근", "재택 시작", "복귀", "복귀하자", "자리비움", "잠깐 자리 비울게", "식사", "점심 먹으러", "밥 먹고 올게", "퇴근", "퇴근하자", "상태 변경", or otherwise signals a change to their attendance/presence state. Trigger even when the user only names the state with no verb (e.g. just "퇴근").
---

# LAS 근무 상태 변경

laftel-las MCP를 통해 본인 근무 상태를 변경한다. 의도가 명확하면 **즉시 도구를 호출**하고, 호출 결과를 한 줄로 보고한다.

## 의도 → 도구 매핑

| 사용자 의도 | 도구 | 비고 |
|-------------|------|------|
| 출근 / 근무 시작 / 근무지 변경 | `mcp__laftel-las__check_in` | `location` 필수 |
| **복귀** (자리비움·식사 종료 후 직전 근무지 복귀) | `mcp__laftel-las__resume_work` | ⚠️ check_in 아님 |
| 자리비움 / 잠깐 자리 비움 | `mcp__laftel-las__start_break` | |
| 식사 / 점심 / 저녁 / 밥 | `mcp__laftel-las__start_meal` | |
| 퇴근 | `mcp__laftel-las__check_out` | |

### 복귀 vs 출근 — 헷갈리지 말 것

`resume_work`는 **휴식(BREAK)·식사(MEAL)를 끝내고 직전 근무지로 돌아오는** 동작이다. 근무지는 직전 WORKING 로그에서 자동 복원되며 인자로 줄 수 없다. "복귀", "돌아왔다", "다시 일한다"는 항상 `resume_work`다.

`check_in`은 **신규 출근 또는 근무지 변경**이다. 반드시 `location`을 지정해야 한다. "출근", "여의도로 옮긴다", "재택으로 전환"이 여기 해당한다.

## location 매핑 (check_in 전용)

`check_in`의 `location`은 enum이다:

| 사용자 표현 | location |
|-------------|----------|
| 여의도 | `YEOUIDO` |
| 샛강 | `SAETGANG` |
| 재택 / 원격 / 집 | `REMOTE` |
| 외근 / 외부 | `AWAY` |

**출근인데 근무지가 불명확하면 호출하지 말고 먼저 물어본다.** (예: "출근"만 말했을 때 → "여의도/샛강/재택/외근 중 어디로 출근?") 추측해서 임의 location으로 호출하지 않는다.

## message 인자

모든 도구는 선택적 `message`를 받아 Slack에 함께 보낸다. 사용자가 한마디 덧붙이면(예: "점심 먹고 2시에 올게") 그 내용을 `message`로 전달한다. 별도 메시지가 없으면 생략한다.

## 실행 원칙

- 의도와 (출근의 경우) 근무지가 명확하면 **확인 없이 즉시** 도구 호출. 상태 변경은 되돌리기 쉬운 동작이라 매번 확인하면 번거롭다.
- 호출 후 MCP 응답을 한 줄로 보고한다 (예: "상태 → 자리비움 변경 완료").
- 모호한 경우(출근 근무지 누락, 복귀인지 신규 출근인지 불분명)에만 한 번 되묻는다.

## 예시

**예시 1 — 복귀:**
입력: "복귀하자"
동작: `resume_work()` 호출 → "복귀 완료 (여의도)"

**예시 2 — 근무지 명시 출근:**
입력: "재택으로 출근"
동작: `check_in(location='REMOTE')` 호출

**예시 3 — 근무지 누락 출근:**
입력: "출근"
동작: 호출하지 않고 "여의도/샛강/재택/외근 중 어디로?" 되물음

**예시 4 — 메시지 동반 식사:**
입력: "점심 먹고 1시에 올게"
동작: `start_meal(message='점심 먹고 1시에 복귀 예정')` 호출
