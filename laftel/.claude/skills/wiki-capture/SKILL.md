---
name: wiki-capture
description: 현재 세션(대화 컨텍스트)에서 LLM 위키(~/ryu-mg/wiki, repo ryu-mg/llm-wiki)에 남길 가치가 있는 내용을 판단해 스키마대로 ingest 하고 commit/push 한다. 또한 SessionEnd 훅이 쌓아둔 인박스(notes/_inbox.md) 후보를 검토·정식 파일링하는 데도 쓴다. "위키에 기록", "이 세션 위키에 넣어줘", "세션 요약 위키에", "wiki capture", "캡처해줘", "인박스 정리", "위키 인박스 처리" 등에 반응.
---

# 위키 캡처 (세션 → LLM 위키)

현재 대화에서 **위키에 남길 가치가 있는 것**만 골라 위키 스키마대로 파일링한다. 위키 위치: `~/ryu-mg/wiki` (private repo `ryu-mg/llm-wiki`).

## 0. 항상 먼저

위키 스키마를 읽고 그 규칙을 따른다: `~/ryu-mg/wiki/CLAUDE.md`. (디렉토리·frontmatter·파일명·Ingest 절차·금기.)

## 1. 두 가지 진입점

### (a) 현재 세션 캡처 — 기본
이 대화 컨텍스트를 검토한다.

### (b) 인박스 처리 — "인박스 정리/처리" 라고 하면
`~/ryu-mg/wiki/notes/_inbox.md` 를 읽어 각 후보를 아래 2단계(판단→파일링)로 처리하고, 파일링한 항목은 인박스에서 제거한다.

## 2. 위키감 판단 (엄격하게)

**남길 것** (신호):
- 중요 기술 결정·아키텍처 선택과 그 근거
- 장애/버그 원인과 해결 (재발 방지 포함)
- 재사용 가능한 runbook·절차
- 외부 소스(URL/글/영상)에서 얻은 지식 → `raw/`+`sources/` ingest 대상
- 깨달음·패턴·개념 정리

**버릴 것** (노이즈 — 파일링 금지):
- 일상 코딩·단순 수정·리뷰 왕복
- 이미 코드/git/CLAUDE.md 에 남는 것
- 일회성 잡담, 이 세션에서만 의미 있는 것
- 위키에 이미 있는 내용 (먼저 `index.md` 로 중복 확인 — 중복이면 기존 페이지 **업데이트**)

판단 결과 남길 게 없으면 **"위키감 없음"** 한 줄 보고하고 끝낸다. 억지로 만들지 않는다.

## 3. 파일링 (사용자 승인 후)

1. 남길 후보를 **먼저 제안**한다: 제목 / 분류(notes·concepts·entities·sources) / 1–2줄 요약 / 근거. 사용자 확인을 받는다 (스키마 원칙: 무단 구조 변경 금지).
2. 승인 시 스키마대로 작성:
   - 외부 소스면 `raw/NNN-slug.md`(원본 보존, 시퀀스 max+1) + `sources/NNN-slug.md`(요약)
   - 저널·결정·runbook 이면 `notes/YYYY-MM-DD-slug.md`
   - 개념·인물·제품이면 `concepts/`·`entities/` 생성 **또는 기존 업데이트** (고아 생성 금지 — 최소 1개 inbound link)
   - frontmatter 필수, wikilink 로 연결, 한국어 기본·기술용어 원문
3. `index.md` 갱신 (해당 카테고리 항목 추가/수정)
4. `log.md` append (맨 아래, append-only): `## [YYYY-MM-DD] <op> | <title>` + 생성/수정 페이지 리스트
5. **commit + push**:
   ```bash
   cd ~/ryu-mg/wiki && git add -A && git commit -m "<op>: <title>" && git push
   ```
6. 무엇을 어디에 넣었는지 한 줄 요약 보고.

## 금기
- `raw/` 수정/삭제 금지. 사용자 승인 없는 페이지 삭제 금지. 중복 페이지 금지(먼저 확인). 불확실한 사실 단정 금지("추정"·"확인 필요" 명시).
