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
    │   ├── MessageIdentity.swift
    │   ├── MessageDeduplicator.swift
    │   └── MessageTransmissionPlan.swift
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
    │   ├── MessageIdentityTests.swift
    │   ├── MessageDeduplicatorTests.swift
    │   └── MessageTransmissionPlanTests.swift
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

`messageTransmissionCount`는 메시지 한 건의 송신 횟수이며 값은 3이다. `messageTransmissionDuration`은 첫 송신부터 마지막 송신까지의 기간이며, 단위는 초이고 값은 1이다. 세 번의 송신은 시작 시점, 0.5초 후, 1초 후에 계획한다.

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

`Messaging/Domain/MessageIdentity.swift`와 대응하는 테스트에 메시지 식별값 비교가 구현되어 있다. 발신 IP, 최초 생성 시각, 내용 해시를 불변 값으로 보관하며, 세 값이 모두 같아야 같은 메시지로 판별한다. IP와 내용 해시는 문자열로, 생성 시각은 `Date`로 전달받는다.

`Messaging/Domain/MessageDeduplicator.swift`는 식별값을 `Set`으로 관리하며, `register(_:)`는 처음 등록한 식별값에만 `true`를 반환한다. `MessageIdentity`는 세 필드의 동등성을 유지하면서 `Hashable`을 따른다.

중복 판별 정보는 대화 기록을 보관하는 동안 유지한다. 재시작 시 비밀번호로 기록을 연 뒤 기존 메시지 식별값을 `knownIdentities`에 전달해 중복 판별 상태를 복원한다. 현재 테스트는 식별값을 직접 전달하는 도메인 복원을 검증하며, 실제 파일 저장과 재시작 흐름은 이후 단계에서 연결한다.

내용 해시 생성, 전송 타임스탬프 형식, 동일 시각·동일 내용의 별도 메시지 구분은 아직 결정하지 않았다.

`Messaging/Domain/MessageTransmissionPlan.swift`와 대응하는 테스트에 메시지 한 건의 세 번 반복 송신 계획이 구현되어 있다. 송신 시작 시각을 기준으로 1초 동안 균등한 간격으로 세 전송 항목을 만들며, 각 항목은 같은 메시지 식별값을 유지한다. 이 객체는 예정 시각을 계산하며, 실제 대기나 패킷 송신은 수행하지 않는다.

현재 구현은 온라인 상태, heartbeat 송신 시점, 메시지 식별값과 중복 여부, 반복 송신 계획을 다루는 도메인 규칙이다. 실제 송수신과 암호화 저장, CLI 연결은 이후 단계에서 구현한다.
