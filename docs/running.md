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
| `3` | 수신기 실행. `hush receive`와 같다 |
| `q` | 종료 |

메뉴와 채팅·수신 중 Ctrl-C는 프로그램 전체를 즉시 종료한다. 메뉴 상단에는 사용할 네트워크가 표시되며, 메뉴로 돌아올 때마다 네트워크를 다시 확인한다. 네트워크를 정하지 못해도 기록 보기는 사용할 수 있다.

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

Hush의 출력은 초록색으로 표시하고, 내 메시지는 밝은 초록색과 굵기로 구분한다. 배경색은 터미널 설정을 따른다. 새 상대 메시지는 `새 메시지`라는 텍스트로 알린다. 소리와 시스템 배너는 사용하지 않는다. iTerm2와 VS Code에서는 이 새 출력을 통해 확인할 수 있다. 터미널을 보고 있지 않을 때의 탭 표시 방식은 각 터미널 설정에 따른다.

Enter로 송신하며, Backspace로 마지막 글자를 지우고 Ctrl-U로 입력을 지운다. `/quit` 또는 빈 입력에서 Ctrl-D로 채팅을 종료하면 진행 중인 세 번 송신을 마친 뒤 종료한다. Ctrl-C는 즉시 종료하며 대기 중인 송신이 중단될 수 있다. 메시지 한 건의 입력 한도는 UTF-8 기준 8192바이트이며 초과 입력은 송신하지 않고 안내한다.

## 화면 종료 후 수신

별도 터미널에서 수신기를 실행하고 비밀번호를 입력한다. 메뉴에서 `3`을 선택해도 된다.

```sh
hush receive
```

수신기는 메시지를 표시하지 않고 같은 개인 기록에 암호화 저장한다. 채팅과 수신 역할은 각각 한 번만 실행할 수 있으며, 둘을 함께 실행할 수 있다. 채팅만 종료해도 수신기는 유지된다. 인증을 마친 수신기는 터미널을 닫아 발생하는 SIGHUP을 무시하므로 해당 프로세스가 계속 실행 중이면 수신을 유지한다. 재부팅·잠자기·네트워크 단절 중의 수신은 보장하지 않는다.

수신기 터미널이 열려 있으면 Ctrl-C로 종료한다. 터미널을 닫은 뒤에는 시작 시 표시된 PID로 `kill -TERM <PID>`를 실행한다. 수신기를 다시 실행할 때도 비밀번호 입력이 필요하다. 자동 시작이나 비밀번호 자동 제공은 구현하지 않는다.

## 테스트

```sh
swift test
```

실제 CLI 통합 테스트는 임시 디렉터리와 임시 UDP 포트를 사용한다. `Tools/PacketFixture.swift`는 제품의 암호화 코덱과 기록 저장을 사용해 테스트 패킷 생성과 저장 결과 조회를 담당한다.

```sh
swift build
swiftc -parse-as-library Sources/Hush/Configuration/HushConfig.swift \
  Sources/Hush/Messaging/Domain/MessageIdentity.swift \
  Sources/Hush/Messaging/Domain/ChatMessage.swift \
  Sources/Hush/Messaging/Domain/RecordedMessage.swift \
  Sources/Hush/Messaging/Application/ConversationStore.swift \
  Sources/Hush/Messaging/Infrastructure/PacketCodec.swift \
  Sources/Hush/Messaging/Infrastructure/HistoryStore.swift \
  Sources/Hush/Messaging/Infrastructure/UDPTransport.swift \
  Tools/PacketFixture.swift -o .build/PacketFixture
python3 Tools/test_cli.py --binary "$(swift build --show-bin-path)/Hush" \
  --fixture .build/PacketFixture --interface en0
```

이 검증은 실제 PTY의 비밀번호 숨김·재인증, UDP 반복 송신과 수신 중복 제거, heartbeat 경계, 터미널 종료 후 저장, 기록 복원, 잘못된 비밀번호·중복 실행·파이프 입력 거부, 터미널 입력 모드 복원을 확인한다. 실제 사내망 두 Mac 사이의 브로드캐스트와 iTerm2·VS Code에서의 사용 검증은 별도로 수행해야 한다.

## 자동 업데이트

`HushConfig.updateManifestURL`에 사내 GitLab 패키지 저장소의 매니페스트 주소, `updateSigningPublicKeyBase64`에 서명 공개키가 설정되어 있으므로 개발 빌드를 포함한 모든 빌드가 자동 확인을 수행한다. 서명 개인키는 프로그램에 포함하지 않는다. 배포 서버와 게시 절차는 [배포](deployment.md)를 따른다. 매니페스트가 아직 게시되지 않았거나 `gitlab.local`에 접근할 수 없으면 실행은 유지되며 채팅 화면에 확인 실패 안내가 표시된다. 개발 빌드도 게시된 더 높은 버전을 발견하면 빌드 경로의 실행 파일을 교체한다.

비밀번호 입력 후 처음 한 번, 이후 10분마다 확인하며 새 버전은 검증 후 즉시 교체·재시작한다. 주기를 기다리지 않고 바로 확인·설치하려면 `hush update`를 실행한다. 채팅과 수신기가 같은 실행 파일을 사용하면 두 역할 모두 새 버전으로 재시작하고 각자 비밀번호를 다시 요청한다. 닫힌 터미널의 수신기는 재인증할 수 없으므로 새 터미널에서 다시 실행해야 한다. 재인증 전에는 기록을 저장하지 않으며 이 구간의 메시지는 누락될 수 있다. 실행 파일이 있는 디렉터리는 사용자가 쓸 수 있어야 하며 이전 파일은 `Hush.previous`에 보관한다.

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
