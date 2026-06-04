---
name: calendar-meeting
version: 1.0.0
description: |
  Google Calendar로 라프텔 팀 회의를 잡는다.
  참석자 가용 시간과 회의실 현황을 병렬 조회 후 표로 제시하고, 확인 후 이벤트 생성.
  "회의 잡아줘", "미팅 잡아줘", "일정 잡아줘", "calendar-meeting" 등에 반응.
triggers:
  - 회의 잡아줘
  - 미팅 잡아줘
  - 일정 잡아줘
  - calendar meeting
allowed-tools:
  - mcp__claude_ai_Google_Calendar__list_events
  - mcp__claude_ai_Google_Calendar__create_event
  - AskUserQuestion
---

# calendar-meeting 스킬

Google Calendar MCP를 사용해 라프텔 팀 회의 일정을 잡는다.

## 고정 설정

- **주최자 calendarId**: `c_aut454qfjiafj2mncg47qa082o@group.calendar.google.com` (라프텔)
- **타임존**: `Asia/Seoul`

### 회의실 목록

| 회의실 | 수용 인원 | calendarId |
|--------|-----------|------------|
| IFC-13-미팅룸 A | 12명 | `c_1888onp7pna1qhkokac7s8d9b3ogs@resource.calendar.google.com` |
| IFC-13-미팅룸 B | 6명 | `c_188fimc2c8h6ggibk2gq03f4ctn5g@resource.calendar.google.com` |
| IFC-13-미팅룸 C | 6명 | `c_18801u2fqh22chrrhr2u7g7s78b1i@resource.calendar.google.com` |
| IFC-13-미팅룸 D | 4명 | `c_188bffo2bd6bgifllul7c4esacttc@resource.calendar.google.com` |

---

## Step 1. 정보 수집

다음 항목이 모두 확보될 때까지 AskUserQuestion으로 **한 번에** 물어본다. 이미 언급된 항목은 다시 묻지 않는다.

| 항목 | 기본값 | 비고 |
|------|--------|------|
| 참석자 | (필수) | 이름만 있으면 `{이름}@laftel.net`으로 추론. 불확실하면 확인 |
| 날짜/시간 범위 | (필수) | 예: "오늘 오후", "내일 2~5시" |
| 소요 시간 | 30분 | 언급 없으면 자동 적용 |
| 회의실 필요 여부 | Google Meet | "회의실 필요" 언급 시 회의실 조회 추가 |
| 회의 제목 | (필수) | 없으면 함께 수집 |

---

## Step 2. 가용 시간 병렬 조회

모든 `list_events` 호출을 **동시에** 실행한다 (순차 실행 금지).

- **참석자**: 각자의 이메일 주소를 calendarId로 사용해 해당 날짜 일정 조회
- **회의실**: 필요한 경우 4개 회의실 calendarId 모두 동시 조회
- **조회 범위**: 해당 날짜 `09:00~19:00` (Asia/Seoul)

---

## Step 3. 가용 시간 표 제시

### 참석자 가용 시간표

시간대별로 각 참석자의 가용 여부를 표시한다.

- ✅ 가능
- ❌ 불가 (일정명 표시)

예시:
| 시간 | 참석자A | 참석자B | 참석자C |
|------|---------|---------|---------|
| 10:00 | ✅ | ❌ 팀 스탠드업 | ✅ |
| 10:30 | ✅ | ✅ | ✅ |
| 11:00 | ✅ | ✅ | ❌ 1:1 미팅 |

### 회의실 가용 현황표 (회의실 필요 시)

참석자 수에 맞는 회의실(수용 인원 ≥ 참석자 수)을 우선 추천한다.

| 시간 | 미팅룸 A (12명) | 미팅룸 B (6명) | 미팅룸 C (6명) | 미팅룸 D (4명) |
|------|-----------------|----------------|----------------|----------------|
| 10:30 | ✅ | ✅ | ❌ 예약됨 | ✅ |

> **Google Meet만 사용하는 경우 회의실 표는 생략한다.**

### 전원 가능 시간이 없을 경우

"요청 범위 내에 전원 가능한 시간이 없습니다. 범위를 확장할까요?" 라고 제안한다.

---

## Step 4. 최종 확인

**반드시 사용자 확인을 받은 후에만 이벤트를 생성한다. 확인 없이 `create_event` 호출 금지.**

다음 형식으로 확인 메시지를 제시한다:

```
📅 이렇게 잡을까요?
- 제목: {회의 제목}
- 일시: {날짜} {시작시간} ~ {종료시간}
- 참석자: {참석자 목록}
- 장소: {회의실 이름 또는 Google Meet}
- 주최자: 라프텔

잡을까요?
```

---

## Step 5. 이벤트 생성

사용자가 확인하면 `create_event`를 호출한다.

- `calendarId`: `c_aut454qfjiafj2mncg47qa082o@group.calendar.google.com`
- `attendeeEmails`: 참석자 이메일 목록
- `addGoogleMeetUrl`: Google Meet 사용 시 `true`, 회의실 사용 시 `false`
- `notificationLevel`: `ALL`
- `timeZone`: `Asia/Seoul`

회의실을 사용하는 경우 해당 회의실의 calendarId도 `attendeeEmails`에 포함시킨다.

이벤트 생성 완료 후 생성된 이벤트 링크를 사용자에게 알려준다.
