# Hush 개발 규약

## 1. 도메인 우선 구조

단일 SPM 실행 타깃 `Hush` 안에서 도메인을 먼저 나누고, 각 도메인 안에 레이어를 둔다. 테스트 타깃 `HushTests`도 같은 도메인·레이어 구조를 따른다.

```text
Sources/Hush/
├── Hush.swift
├── Configuration/
│   └── HushConfig.swift
├── Presence/
│   ├── Domain/
│   │   ├── PeerPresence.swift
│   │   └── HeartbeatSchedule.swift
│   ├── Application/
│   ├── Infrastructure/
│   └── Presentation/
└── Messaging/
    ├── Domain/
    ├── Application/
    ├── Infrastructure/
    └── Presentation/

Tests/HushTests/
├── HushTests.swift
├── Presence/
│   ├── Domain/
│   │   ├── PeerPresenceTests.swift
│   │   └── HeartbeatScheduleTests.swift
│   ├── Application/
│   ├── Infrastructure/
│   └── Presentation/
└── Messaging/
    ├── Domain/
    ├── Application/
    ├── Infrastructure/
    └── Presentation/
```

위 트리는 코드 배치 기준이다. 도메인과 레이어 폴더는 해당 코드가 생길 때 만든다.

- `Presence`: heartbeat와 상대 온라인 상태
- `Messaging`: 메시지 송수신, 중복 판별, 대화 기록
- `Domain`: 도메인 상태와 규칙
- `Application`: 도메인 규칙과 송수신·저장 기능을 연결하는 유스케이스
- `Infrastructure`: UDP, 암호화, 기록 저장 등 외부 기술 구현
- `Presentation`: 터미널 입력과 화면 출력
- `Hush.swift`: 실행 진입점과 여러 도메인을 연결하는 객체 조립

도메인 상태 변화와 규칙은 도메인 객체가 책임진다. 네트워크, 파일 접근, 터미널 입출력은 각 도메인의 해당 레이어에 배치해 도메인 규칙을 외부 환경 없이 테스트할 수 있도록 한다.

## 2. 설정

설정 상수는 `Sources/Hush/Configuration/HushConfig.swift`에 둔다. 값은 Swift 코드로 정의하며, 변경 시 다시 빌드한다.

현재 `peerOfflineThreshold`는 마지막 heartbeat 수신 후 오프라인으로 판단하는 기준이며, 단위는 초이고 값은 12이다.

`heartbeatInterval`은 마지막 heartbeat 송신 후 다음 송신까지의 간격이며, 단위는 초이고 값은 3이다. 첫 heartbeat는 채팅 시작 즉시 송신한다.

## 3. TDD와 테스트 스타일

- 기존 Swift Testing을 사용하고 검증은 `#expect(...)`로 작성한다.
- 테스트 이름은 한국어로 행동과 기대 결과를 드러낸다.
- Given–When–Then 주석은 도메인 상황, 행동, 기대 결과를 한국어로 설명한다.
- 새 동작은 실패하는 테스트를 먼저 확인한 뒤 최소 구현을 추가하고, 테스트가 통과한 상태에서 리팩터링한다.
- 리팩터링은 변경 전후 테스트 통과로 기존 동작의 유지를 확인한다.
- 시간 판정은 시각을 명시적으로 전달해 실제 대기 없이 검증한다.

## 4. 작업 단위와 커밋

- 합의한 작업 단위가 끝나고 필요한 검증이 통과하면 해당 변경을 커밋한다.
- 커밋 메시지는 사전 검수 없이 작성하며, 한국어 Conventional Commits 형식을 따른다.
- 제목과 본문은 명사형으로 끝내고, 본문은 변경 이유를 `- ` 불렛으로 작성한다.

## 5. 현재 구현 범위

`Presence/Domain/PeerPresence.swift`와 대응하는 테스트에 heartbeat 수신 여부, 마지막 수신 후 12초 경계, 재수신 시 온라인 전환이 구현되어 있다.

`Presence/Domain/HeartbeatSchedule.swift`와 대응하는 테스트에 첫 heartbeat 즉시 송신 판단과 마지막 송신 후 3초 경계가 구현되어 있다. 송신 시점 조회는 기록을 바꾸지 않으며, 실제 송신 후 `recordHeartbeatSent(at:)`로 마지막 송신 시각을 기록한다.

현재 구현은 시각을 전달받아 상태와 송신 시점을 판단하는 도메인 규칙이다. 실제 heartbeat 송수신과 CLI 연결은 이후 단계에서 구현한다.
