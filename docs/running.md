# Hush 실행과 검증

## 빌드

macOS 13 이상에서 실행하며, 개발에는 Swift 6.4 도구 체인을 사용한다. Swift Testing을 실행하는 개발 환경은 macOS 14 이상을 사용한다.

```sh
swift build -c release
swift build -c release --show-bin-path
```

두 Mac에는 동일한 `HushConfig.communicationKey`가 포함된 실행 파일을 배포한다. Apple Silicon·Intel 공용 파일과 서명 배포 절차는 [배포](deployment.md)를 따른다. 아래 명령은 빌드 경로의 실행 파일을 직접 사용한다.

## 메뉴

설치한 실행 파일은 `hush`로 실행한다([배포](deployment.md)의 최초 설치 참고). 개발 중에는 `swift run Hush`를 사용한다.

```sh
hush
```

비밀번호를 한 번 입력하면 메뉴가 표시된다. 번호 키 하나로 선택하며 Enter는 필요하지 않다.

| 키 | 동작 |
|---|---|
| `1` | 채팅. `/quit` 또는 Ctrl-D로 끝내면 메뉴로 돌아온다 |
| `2` | 기록 보기. 저장된 대화를 생성 시각과 함께 표시하며 아무 키나 누르면 메뉴로 돌아온다 |
| `q` | 종료 |

메뉴와 채팅 중 Ctrl-C는 프로그램 전체를 즉시 종료한다. 메뉴 상단에는 사용할 네트워크와 백그라운드 수신기 상태(`수신기 켜짐`·`꺼짐`)가 표시되며, 메뉴로 돌아올 때마다 네트워크를 다시 확인한다. 네트워크를 정하지 못해도 기록 보기는 사용할 수 있다.

## 명령

사용자에게 안내하는 명령은 다음 세 가지뿐이다.

| 명령 | 동작 |
|---|---|
| `hush` | 메뉴 |
| `hush update` | 새 버전을 확인하고 있으면 받아 검증한 뒤 설치 |
| `hush upgrade` | `hush update`와 같음 |

`hush update`는 기록과 소켓을 열지 않으므로 비밀번호를 요구하지 않는다. 설치 후 실행 중인 Hush는 실행 파일 교체를 감지해 새 버전으로 재시작한다.

`chat`, `receive`, `--interface`, `--port`, `--history-directory`, `--help`, `--version`은 도움말과 오류 안내에 표시하지 않는 업데이트 검증·테스트용 옵션이다. 업데이트 설치 시 새 실행 파일의 `--version` 출력을 확인하고, 통합 테스트는 임시 기록 위치와 포트로 각 역할을 직접 실행한다.

## 네트워크 선택

다음 순서로 네트워크를 선택한다.

1. 연결된 IPv4 브로드캐스트 네트워크가 하나뿐이면 그 네트워크
2. 연결된 Wi-Fi
3. 기본 경로 네트워크

Wi-Fi 여부와 기본 경로는 macOS SystemConfiguration으로 확인한다. 이 순서로도 정할 수 없으면 연결된 네트워크 목록을 안내하고 채팅을 시작하지 않는다. 숨김 옵션 `--interface`로 네트워크를 직접 지정할 수 있다.

## 채팅

메뉴에서 `1`을 선택한다. 최초 실행에는 개인 비밀번호와 확인 값을 입력하고, 이후에는 실행할 때마다 비밀번호를 다시 입력한다. 비밀번호를 인자나 환경 변수로 전달하는 방식은 지원하지 않는다.

기본 기록 위치는 `~/Library/Application Support/Hush/history.json`이며 기본 UDP 포트는 49000이다. 두 Mac은 같은 포트를 사용해야 한다.

Hush의 출력은 고른 글자 색으로 표시하고, 내 메시지는 같은 계열의 밝은 색과 굵기로 구분한다. 기본은 초록이며 배경색은 터미널 설정을 따른다. 새 상대 메시지는 `새 메시지`라는 텍스트로 알린다. 소리와 시스템 배너는 사용하지 않는다. iTerm2와 VS Code에서는 이 새 출력을 통해 확인할 수 있다. 터미널을 보고 있지 않을 때의 탭 표시 방식은 각 터미널 설정에 따른다.

글자 색은 메뉴 막대 수신기의 `글자 색`에서 고른다. 초록·노랑·청록·흰색은 터미널 테마의 기본 색을 사용하고 내 메시지는 같은 계열의 밝은 색으로 표시한다. `터미널 기본색`은 색 없이 내 메시지만 굵게 표시하므로 밝은 테마에 적합하다. `직접 고르기…`는 macOS 색상 팔레트를 열며, 고른 색은 `COLORTERM`이 `truecolor`·`24bit`이거나 iTerm2·VS Code 터미널이면 그대로, 그 밖에는 가장 가까운 256색으로 표시한다. 내 메시지는 고른 색을 흰색 쪽으로 35% 밝힌 색에 굵게 표시한다. 고른 색은 기록 위치의 `settings.json`(권한 0600)에 평문으로 저장한다. 열려 있는 채팅은 0.5초마다 설정을 확인해 새로 나오는 줄과 입력 줄부터 새 색을 사용하며, 이미 출력한 줄은 다시 칠하지 않는다.

Enter로 송신하며, Backspace로 마지막 글자를 지운다. `/quit` 또는 빈 입력에서 Ctrl-D로 채팅을 종료하면 진행 중인 세 번 송신을 마친 뒤 종료한다. Ctrl-C는 즉시 종료하며 대기 중인 송신이 중단될 수 있다. 메시지 한 건의 입력 한도는 UTF-8 기준 8192바이트이며 초과 입력은 송신하지 않고 안내한다.

채팅 중 `/`로 시작하는 입력은 전송하지 않고 명령으로 처리한다.

| 명령 | 동작 |
|---|---|
| `/help` | 명령과 단축키 목록 표시 |
| `/clear` | 터미널의 `clear`처럼 화면과 스크롤 기록을 지우고 상대 상태를 다시 표시. 저장된 대화 기록은 유지 |
| `/quit` | 메뉴로 돌아가기 |
| `//내용` | `/내용`이라는 메시지 보내기 |

그 밖의 `/명령`은 전송하지 않고 알 수 없는 명령이라고 안내한다. 오타로 명령이 메시지로 전송되는 것을 막기 위해서이다.

상대가 메시지를 쓰는 동안 입력 줄 바로 위에 `상대 입력 중…`을 표시한다. 상대가 키를 멈추고 5초가 지나거나, 메시지를 보내거나, 입력을 다 지우면 사라진다. 내가 메시지를 쓸 때는 입력이 바뀔 때 최대 2초에 한 번 입력 중 신호를 보내며, `/`로 시작하는 명령 입력은 알리지 않는다. 두 사람 모두 0.8.0 이상이어야 표시된다.

## 백그라운드 수신

처음 `hush`를 실행해 비밀번호로 기록을 열면 수신기를 사용자 LaunchAgent `local.hush.receiver`로 등록한다. 수신기는 로그인할 때부터 로그아웃·종료할 때까지 실행되며, 종료되면 launchd가 다시 실행한다. 등록할 때 macOS가 백그라운드 항목 추가 알림을 표시할 수 있다. 이후 `hush`를 실행할 때마다 같은 실행 파일로 등록되어 있는지 확인하고, 설치 경로가 바뀌었으면 다시 등록한다. 기록 위치를 따로 지정한 실행과 `.build` 안의 개발 빌드는 등록하지 않는다.

수신기는 비밀번호를 묻지 않으며 메시지를 표시하지 않는다. 출력은 `~/Library/Logs/Hush/receiver.log`에 남는다.

로그인 항목으로 실행한 수신기는 숨김 옵션 `--menu-bar`로 메뉴 막대에 표시를 둔다. 평소에는 흑백 말풍선, 읽지 않은 메시지가 1.5초 넘게 남아 있으면 빨간 배지로 건수를 보여 준다. 열 건 이상은 `9+`로 표시한다. 읽음 상태는 메시지 식별자의 해시를 담은 `unread.json`에 별도로 저장하며 수신함이 기록에 합쳐져도 유지된다. 포커스 보고(DECSET 1004)를 받은 채팅 터미널에서는 입력 포커스가 있는 동안 화면에 표시된 메시지만 읽음 처리한다. 보고가 없는 터미널에서는 키 입력 시 표시된 메시지를 읽음 처리한다. 메뉴·기록 보기만 열면 배지는 유지된다. 메뉴의 `Hush 열기`는 기록 위치에 `Hush.command`를 만들어 기본 터미널에서 연다. 기존 등록은 `hush`를 한 번 실행하면 `--menu-bar`가 들어간 내용으로 바뀐다.

수신기는 기록을 열지 않고 받은 메시지를 수신함 `inbox.jsonl`에 암호화해 쌓는다. 수신함 열쇠는 비밀번호로 기록을 처음 열 때 `inbox-key.json`에 만들어지며, 공개키만 수신기가 사용하고 개인키는 기록용 키로 봉인한다. 비밀번호로 기록을 열면 메뉴·기록 보기·채팅이 수신함을 기록에 중복 없이 합치고 비운다. 수신함 열쇠가 없으면 수신기는 시작하지 않는다.

채팅과 수신 역할은 각각 한 번만 실행할 수 있으며, 둘을 함께 실행할 수 있다. 수신기는 터미널을 닫아 발생하는 SIGHUP을 무시하고, 특정 네트워크를 고르지 않고 모든 네트워크에서 받는다. 내 IP 목록은 5초마다 다시 읽어 내 메시지를 거른다. 재부팅·잠자기·네트워크 단절 중의 수신은 보장하지 않는다. 등록을 해제하려면 다음 명령을 실행한다. 다음에 `hush`를 실행하면 다시 등록된다.

```sh
launchctl bootout gui/$(id -u)/local.hush.receiver
rm ~/Library/LaunchAgents/local.hush.receiver.plist
```

수신기가 스스로 업데이트를 확인하지 못해도 브로드캐스트 수신은 동작하며, 터미널에서 실행한 채팅의 자동 업데이트나 `hush update`가 실행 파일을 교체하면 수신기는 파일 교체를 감지해 새 버전으로 재시작한다. 실패 내용은 로그에 요약해 남긴다.

## 테스트

```sh
swift test
```

실제 CLI 통합 테스트는 임시 디렉터리와 임시 UDP 포트를 사용한다. `Tools/PacketFixture.swift`는 제품의 암호화 코덱과 기록 저장을 사용해 테스트 패킷 생성과 저장 결과 조회를 담당한다.

```sh
swift build
swiftc -parse-as-library Sources/Hush/Configuration/HushConfig.swift \
  Sources/Hush/Presence/Domain/TypingSignal.swift \
  Sources/Hush/Messaging/Domain/MessageIdentity.swift \
  Sources/Hush/Messaging/Domain/ChatMessage.swift \
  Sources/Hush/Messaging/Domain/RecordedMessage.swift \
  Sources/Hush/Messaging/Application/ConversationStore.swift \
  Sources/Hush/Messaging/Infrastructure/PacketCodec.swift \
  Sources/Hush/Messaging/Infrastructure/HistoryStore.swift \
  Sources/Hush/Messaging/Infrastructure/InboxStore.swift \
  Sources/Hush/Messaging/Infrastructure/UnreadStore.swift \
  Sources/Hush/Messaging/Infrastructure/UDPTransport.swift \
  Tools/PacketFixture.swift -o .build/PacketFixture
python3 Tools/test_cli.py --binary "$(swift build --show-bin-path)/Hush" \
  --fixture .build/PacketFixture --interface en0
```

이 검증은 실제 PTY의 비밀번호 숨김·재인증, UDP 반복 송신과 수신 중복 제거, heartbeat 경계, 입력 중·정지 신호 송신과 입력 중 줄 표시·해제, 터미널 종료 후 저장, 기록 복원, 잘못된 비밀번호·중복 실행·파이프 입력 거부, 터미널 입력 모드 복원을 확인한다. 실제 사내망 두 Mac 사이의 브로드캐스트와 iTerm2·VS Code에서의 사용 검증은 별도로 수행해야 한다.

## 자동 업데이트

`HushConfig.updateManifestURL`에 GitHub 릴리스의 매니페스트 주소, `updateSigningPublicKeyBase64`에 서명 공개키가 설정되어 있으므로 개발 빌드를 포함한 모든 빌드가 자동 확인을 수행한다. 서명 개인키는 프로그램에 포함하지 않는다. 배포 서버와 게시 절차는 [배포](deployment.md)를 따른다. 매니페스트가 아직 게시되지 않았거나 `github.com`에 접근할 수 없으면 실행은 유지되며 채팅 화면에 확인 실패 안내가 표시된다. 개발 빌드도 게시된 더 높은 버전을 발견하면 빌드 경로의 실행 파일을 교체한다.

비밀번호 입력 후 처음 한 번, 이후 10분마다 확인하며 새 버전은 검증 후 즉시 교체·재시작한다. 주기를 기다리지 않고 바로 확인·설치하려면 `hush update`를 실행한다. 채팅과 수신기가 같은 실행 파일을 사용하면 두 역할 모두 새 버전으로 재시작한다. 채팅은 비밀번호를 다시 요청하고 재인증 전에는 기록을 저장하지 않는다. 수신기는 비밀번호 없이 바로 수신을 이어가므로 채팅 재인증을 기다리는 동안의 메시지도 수신함에 저장한다. 실행 파일이 있는 디렉터리는 사용자가 쓸 수 있어야 하며 이전 파일은 `Hush.previous`에 보관한다.

배포 도구와 실제 업데이트 통합 테스트는 다음 명령으로 실행한다. 위의 `PacketFixture`를 먼저 빌드한다.

```sh
swiftc -parse-as-library Sources/Hush/Updates/Domain/ReleaseVersion.swift \
  Sources/Hush/Updates/Domain/ReleaseDescriptor.swift \
  Sources/Hush/Updates/Infrastructure/ReleaseManifest.swift \
  Tools/ReleaseTool.swift -o .build/ReleaseTool
python3 Tools/test_release_tool.py --tool .build/ReleaseTool
python3 Tools/test_updates.py --release-tool .build/ReleaseTool \
  --fixture .build/PacketFixture --interface en0
```

업데이트 테스트는 임시 소스 복사본에 로컬 HTTP 주소와 임시 공개키를 설정해 두 버전을 빌드한다. 실제 작업 소스의 배포 설정과 개인 기록은 변경하지 않는다.
