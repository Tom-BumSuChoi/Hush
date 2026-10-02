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
│   │   └── PresenceService.swift
│   ├── Infrastructure/
│   └── Presentation/
└── Messaging/
    ├── Domain/
    │   ├── MessageIdentity.swift
    │   ├── MessageDeduplicator.swift
    │   ├── MessageTransmissionPlan.swift
    │   ├── ChatMessage.swift
    │   └── Conversation.swift
    ├── Application/
    │   └── MessagingService.swift
    ├── Infrastructure/
    └── Presentation/

Tests/HushTests/
├── HushTests.swift
├── Presence/
│   ├── Domain/
│   │   ├── PeerPresenceTests.swift
│   │   └── HeartbeatScheduleTests.swift
│   ├── Application/
│   │   └── PresenceServiceTests.swift
│   ├── Infrastructure/
│   └── Presentation/
└── Messaging/
    ├── Domain/
    │   ├── MessageIdentityTests.swift
    │   ├── MessageDeduplicatorTests.swift
    │   ├── MessageTransmissionPlanTests.swift
    │   └── ConversationTests.swift
    ├── Application/
    │   └── MessagingServiceTests.swift
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
- 새 동작은 최소 구현 → 테스트 작성·실행 → 결과 확인 → 커밋 순서로 진행한다. 실패하는 테스트를 먼저 실행해 확인하는 절차는 생략하며, 테스트가 통과한 상태에서 리팩터링한다.
- 리팩터링은 변경 전후 테스트 통과로 기존 동작의 유지를 확인한다.
- 시간 판정은 시각을 명시적으로 전달해 실제 대기 없이 검증한다.

## 4. 작업 단위와 커밋

- 합의한 작업 단위가 끝나고 필요한 검증이 통과하면 해당 변경을 커밋한다.
- 커밋 메시지는 사전 검수 없이 작성하며, 한국어 Conventional Commits 형식을 따른다.
- 제목과 본문은 명사형으로 끝내고, 본문은 변경 이유를 `- ` 불렛으로 작성한다.

## 5. 현재 구현 범위

`Presence/Domain/PeerPresence.swift`와 대응하는 테스트에 heartbeat 수신 여부, 마지막 수신 후 12초 경계, 재수신 시 온라인 전환이 구현되어 있다.

`Presence/Domain/HeartbeatSchedule.swift`와 대응하는 테스트에 첫 heartbeat 즉시 송신 판단과 마지막 송신 후 3초 경계가 구현되어 있다. 송신 시점 조회는 기록을 바꾸지 않으며, 실제 송신 후 `recordHeartbeatSent(at:)`로 마지막 송신 시각을 기록한다.

`Presence/Application/PresenceService.swift`는 `HeartbeatSchedule`과 `PeerPresence`를 연결한다. 시작 시 지정하는 `Role.chat`은 heartbeat 송신 시점을 판단하고, `Role.backgroundReceiver`는 heartbeat를 송신하지 않도록 판단한다. 역할은 요구사항의 논리적 역할을 나타내며, 실제 프로세스 구성이나 실행 관리를 구현한 것은 아니다.

`shouldSendHeartbeat(at:)`로 송신 여부를 조회하고 실제 송신 후 `recordHeartbeatSent(at:)`로 송신 시각을 기록한다. `receiveHeartbeat(at:)`는 복호화·검증을 마친 상대 heartbeat의 수신 시각을 반영하며, `isPeerOnline(at:)`로 상대 상태를 조회한다. 내 송신 시각과 상대 수신 시각은 독립적으로 관리한다. 역할별 송신 여부와 3초·12초 경계 및 송수신 상태의 독립성은 `Presence/Application/PresenceServiceTests.swift`에서 검증한다.

`Messaging/Domain/MessageIdentity.swift`와 대응하는 테스트에 메시지 식별값 비교가 구현되어 있다. 발신 IP, 최초 생성 시각, 내용 해시를 불변 값으로 보관하며, 세 값이 모두 같아야 같은 메시지로 판별한다. IP와 내용 해시는 문자열로, 생성 시각은 `Date`로 전달받는다.

`Messaging/Domain/MessageDeduplicator.swift`는 식별값을 `Set`으로 관리하며, `register(_:)`는 처음 등록한 식별값에만 `true`를 반환한다. `MessageIdentity`는 세 필드의 동등성을 유지하면서 `Hashable`을 따른다.

중복 판별 정보는 대화 기록을 보관하는 동안 유지한다. 재시작 시 비밀번호로 기록을 연 뒤 기존 메시지 식별값으로 중복 판별 상태를 복원한다. 도메인 테스트와 아래의 암호화 기록·CLI 통합 테스트에서 각각 복원을 검증한다.

내용 해시 생성, 전송 시각 표현과 동일 시각·동일 내용의 별도 메시지 구분은 아래의 암호화 통신 구현을 따른다.

`Messaging/Domain/MessageTransmissionPlan.swift`와 대응하는 테스트에 메시지 한 건의 세 번 반복 송신 계획이 구현되어 있다. 송신 시작 시각을 기준으로 1초 동안 균등한 간격으로 세 전송 항목을 만들며, 각 항목은 같은 메시지 식별값을 유지한다. 이 객체는 예정 시각을 계산하며, 실제 대기나 패킷 송신은 수행하지 않는다.

`Messaging/Domain/ChatMessage.swift`는 메시지 식별값과 내용을 불변 값으로 묶는다. `Messaging/Domain/Conversation.swift`는 `MessageDeduplicator`를 사용해 메시지를 중복 없이 메모리에 보관한다. `record(_:)`는 새 메시지를 추가했을 때만 `true`를 반환하며, 기록 목록은 외부에서 조회할 수 있고 수정은 대화 객체가 담당한다.

기존 메시지 목록으로 대화를 복원할 때도 같은 기록 규칙을 적용한다. 복원할 목록 안의 중복과 이후 재수신한 기존 메시지는 추가되지 않으며, 복원 이후 새 메시지를 기록할 수 있다. 이 동작은 `Messaging/Domain/ConversationTests.swift`에서 검증한다.

`Messaging/Application/MessagingService.swift`는 하나의 `Conversation`으로 송신 준비와 수신 처리를 연결한다. `prepareSend(_:at:)`는 새 메시지를 한 번 기록하고 세 번의 전송 계획을 반환하며, 이미 기록된 식별값에는 추가 계획을 만들지 않는다. `receive(_:)`는 새 메시지만 기록하고 표시 대상으로 반환하며, 중복에는 `nil`을 반환한다.

송신과 수신은 같은 중복 판별 상태를 사용하므로 내 메시지를 다시 수신해도 기록과 표시 대상이 늘어나지 않는다. 기존 기록을 전달해 서비스를 시작하면 복원한 대화에도 같은 규칙이 적용된다. 수신 입력은 복호화·검증을 마친 `ChatMessage`를 전제로 하며, 현재 서비스는 네트워크 입출력이나 암호화를 수행하지 않는다.

현재 도메인·애플리케이션 계층에 메시지 송신 준비·수신 처리와 역할별 heartbeat 판단이 구현되어 있다. 암호화 통신·기록 저장 및 CLI 연결은 아래 작업 단위를 따른다.

## 6. 암호화 통신과 기록 저장

최소 macOS 버전은 13이다. 외부 패키지 없이 Darwin POSIX UDP 소켓, CryptoKit의 AES-GCM 인증 암호화와 SHA-256 내용 해시를 사용한다. 패킷은 버전 1 JSON으로 메시지와 heartbeat를 구분하며, 생성 시각은 `Date`의 JSON 숫자 표현으로 정밀도를 유지한다. 수신 메시지 식별값의 발신 IP는 UDP 출발 주소에서 얻고 내용 해시는 복호화한 내용으로 다시 계산한다.

`MessageFactory`는 마지막 생성 시각보다 최소 1마이크로초 뒤의 시각을 사용해 동일 시각·동일 내용의 새 작성을 구분한다. 재시작 시 기존 내 메시지의 마지막 생성 시각을 복원한다.

`HistoryStore`는 무작위 16바이트 salt와 PBKDF2-HMAC-SHA256 600,000회로 개인 비밀번호에서 256비트 기록용 키를 유도한다. 대화와 내 메시지 여부는 통신용 키와 별도의 키로 AES-GCM 암호화하며, 파일 권한은 0600이다. 같은 기록을 사용하는 프로세스는 별도 잠금 파일의 `flock`으로 최신 기록 조회·중복 판별·원자적 파일 교체를 묶어 처리한다. 잘못된 비밀번호나 손상된 기록은 기존 파일을 덮어쓰지 않는다.

`ChatSession`은 저장 포트 `ConversationStore`와 Presence·Messaging 규칙을 연결한다. 오프라인 상태에서도 송신 준비를 허용하고, 내 IP의 heartbeat를 상대 상태에 반영하지 않는다. 수신기가 이미 저장한 메시지는 채팅에서 기록을 새로 조회해 한 번 표시할 수 있다.

`MessageSender`는 도메인의 세 번 송신 계획을 시스템 단조 시각 기준의 실제 패킷 송신으로 연결한다. 동일 패킷을 시작 시점, 0.5초 후, 1초 후에 송신하며 수신 확인이나 추가 재전송은 수행하지 않는다. 실제 로컬 UDP 수신으로 세 번의 경계와 송신 종료를 검증한다.

## 7. CLI 실행 연결

`Hush.swift`는 실행 옵션에 따라 `CLIApplication`을 조립한다. 실제 채팅·수신 역할은 터미널에서 숨김 입력한 비밀번호로 기록을 연 뒤 UDP 소켓을 사용한다. 최초 기록 생성 시 비밀번호 확인을 받으며 잘못된 비밀번호·비터미널 입력에는 기록을 덮어쓰거나 생성하지 않는다. 도움말과 버전 조회는 기록·소켓을 열지 않는다.

`CLIApplication`의 `poll` 이벤트 루프는 UDP 수신, 터미널 입력, 반복 송신과 heartbeat를 연결한다. 채팅과 수신기는 각각 비밀번호로 자신의 메모리 내 기록용 키를 얻고, 암호화 파일만 공유한다. `RoleLease`는 같은 기록에 같은 역할이 중복 실행되는 것을 막는다. 수신 역할은 SIGHUP을 무시하며 heartbeat를 송신하지 않는다. 채팅의 새 출력에는 작성 중인 입력을 다시 표시하고, 종료 시 터미널 입력 상태를 복원한다.

명령 없이 실행하면 `CLIApplication.runMenu`가 비밀번호로 기록을 한 번 연 뒤 `MainMenu`를 표시한다. 메뉴는 번호 키 하나로 채팅·기록 보기·수신기·종료를 고르며, 채팅과 수신기는 `chat`·`receive` 명령과 같은 실행 경로를 같은 프로세스에서 사용한다. `/quit`·Ctrl-D로 끝난 역할은 메뉴로 돌아오고, 종료 신호로 끝난 역할은 프로세스를 종료한다. 메뉴의 키 입력은 화면을 그리기 전에 입력 모드를 바꿔 화면을 본 직후의 입력을 버리지 않는다. `TerminalHistoryView`는 저장된 기록을 생성 시각과 함께 표시한다. 업데이트 재시작은 같은 실행 인자를 사용하므로 메뉴에서 시작한 프로세스는 메뉴로 다시 시작해 비밀번호를 요청한다.

`--interface`가 없으면 `NetworkPreference`가 SystemConfiguration으로 Wi-Fi 인터페이스와 기본 경로 인터페이스를 조회하고, `CLIOptions`가 연결된 네트워크 하나, Wi-Fi, 기본 경로 순으로 선택한다. 정할 수 없으면 임의로 송신하지 않고 선택을 요구한다.

Hush의 터미널 출력은 `TerminalChatView.styled`로 초록색을 적용하고, 내 메시지는 밝은 초록색과 굵기로 구분한다. 원격 내용은 색을 적용하기 전에 제어 문자를 제거한다.

실행 방법과 실제 PTY·UDP 통합 검증 명령은 [실행과 검증](running.md)을 따른다.

## 8. 업데이트 규칙

`Updates/Domain/ReleaseVersion`은 안정 버전의 `주.부.패치` 세 숫자를 비교하며, 선행 0과 prerelease 등 지원하지 않는 형식을 거부한다. `UpdateSchedule`은 실행 시 최초 확인과 마지막 확인 이후 600초 경계를 시스템 단조 시각으로 판단한다. 확인 주기는 `HushConfig.updateCheckInterval`에 둔다.

`ReleaseManifest`는 JSON 안의 base64 `payload`와 `signature`를 받아 신뢰한 Curve25519 서명 공개키로 원본 payload의 서명을 검증한다. 서명한 payload에는 형식 버전 1, 프로그램 버전, HTTP(S) 다운로드 주소와 파일 SHA-256을 담는다. 서명 검증 후에만 정보를 해석하고, 다운로드한 파일의 해시를 별도로 검증한다. 다른 서명자·변조된 정보·해시가 다른 파일은 교체 대상으로 받아들이지 않는다.

`UpdateChecker`는 `UpdateSource` 포트로 검증된 배포 정보를 조회하고 현재보다 새 버전일 때만 파일을 받는다. `HTTPUpdateSource`는 실제 HTTP(S) 상태 코드, 요청 제한 시간, 버전 정보 1MiB·실행 파일 100MiB 크기 한도를 검사하고 파일 해시를 검증한다. 로컬 HTTP 서버 테스트로 새 버전 다운로드, 같은 버전에서 파일 조회 생략, 변조된 실제 응답 파일 거부를 확인한다.

`ExecutableInstaller`는 파일 해시와 Mach-O 형식을 확인하고, 임시 실행 파일의 `--version` 결과와 실행 가능 여부를 검사한 뒤 같은 디렉터리에서 원자적 `rename`으로 교체한다. 검증 실행에는 제한 시간을 둔다. 프로세스 간 업데이트 잠금으로 교체를 직렬화하며 더 최신 파일이 이미 설치되었으면 낮은 버전으로 바꾸지 않는다. 기존 실행 파일은 `.previous`에 보관하고 재시작 실패 시 되돌릴 수 있다. 실제 Mach-O 후보 파일로 교체·버전 불일치 거부·복원을 검증한다.

`Tools/ReleaseTool.swift`는 배포 서명 키 생성, 실행 파일의 해시를 포함한 매니페스트 서명, 공개키와 파일의 검증을 수행한다. 서명 개인키는 별도 0600 파일로 만들며 기존 키 파일을 덮어쓰지 않는다. 프로그램에 배포할 신뢰 정보는 공개키이며 서명 개인키를 내장하지 않는다. `Tools/test_release_tool.py`로 실제 키 생성·서명·검증 및 변조 거부 사이클을 확인한다.

`UpdateRuntime`은 인증을 마친 CLI 이벤트 루프에서 최초·주기 확인을 시작하며 HTTP 작업을 별도 작업으로 수행한다. 검증한 새 버전은 즉시 설치하고 `ProcessRestart`의 `execv`로 같은 실행 인자를 유지해 재시작한다. 다른 역할이 실행 파일을 먼저 바꿔도 파일 식별값과 버전을 확인해 재시작한다. 터미널 입력 모드는 복원하고 소켓·역할 잠금은 exec 시 닫으며, 기존 메모리의 기록용 키는 새 프로세스에 전달하지 않는다.

배포 URL과 서명 공개키는 `HushConfig.updateManifestURL`·`updateSigningPublicKeyBase64`에 함께 설정해 다시 빌드한다. 현재 사내 GitLab `bfit-daily/hush` 프로젝트의 범용 패키지 저장소 주소와 배포 서명 공개키가 설정되어 있으며, 배포 서버 구성은 [배포](deployment.md)를 따른다. `Tools/test_updates.py`는 임시 설정과 실제 두 버전의 release 실행 파일로 다운로드 대기 중 채팅, 서명 다운로드, 두 역할 재시작, 비밀번호 재입력 전 저장 중단, 기록 유지, 소켓 정리와 변조 거부를 검증한다. 재인증 후 수신기만 실행 중인 상태에서 기존 형식의 메시지를 받아 저장을 재개하고 반복 패킷은 한 건으로 남기는 것도 확인한다.

터미널을 닫은 수신기에 업데이트가 도착하면 새 파일로 재시작하지만 비터미널 입력으로 재인증할 수 없어 종료한다. 위 통합 테스트는 이 종료가 기존 기록을 바꾸지 않으며 새 터미널에서 비밀번호를 다시 입력한 수신기가 중복 없이 저장을 재개하는 것까지 확인한다.
