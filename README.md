# Hush

같은 사내망(같은 공유기)에 있는 두 사람이 터미널에서 주고받는 1:1 암호화 채팅입니다. 채팅 서버 없이 메시지를 암호화해 네트워크에 브로드캐스트하고, 대화 기록은 각자의 Mac에 개인 비밀번호로 암호화해 저장합니다. 채팅 화면을 닫아도 백그라운드 수신기가 로그인해 있는 동안 메시지를 받아 둡니다.

macOS 13 이상, Apple Silicon과 Intel Mac에서 실행됩니다.

## 설치 (처음 한 번)

### 1. gitlab.local 접속 준비

Hush는 사내 GitLab(`gitlab.local`)에서 내려받고 업데이트합니다. 아래 두 가지를 먼저 해 두어야 합니다. 이미 gitlab.local을 쓰고 있다면 이미 되어 있을 수 있습니다.

**이름 등록.** 이 명령 출력에 `192.168.0.42`가 없으면 등록합니다. 관리자 비밀번호를 묻습니다.

```sh
grep gitlab.local /etc/hosts
echo '192.168.0.42 gitlab.local' | sudo tee -a /etc/hosts
```

**인증서 신뢰.** gitlab.local은 사내에서 만든 인증서를 사용합니다. 브라우저로 GitLab에 로그인해 이 저장소의 [`docs/gitlab.local-ca.pem`](docs/gitlab.local-ca.pem)을 내려받습니다. 이때 나오는 인증서 경고는 한 번만 무시합니다. 내려받은 파일의 지문이 아래 값과 같은지 확인한 뒤 시스템 키체인에 신뢰로 등록합니다.

```sh
cd ~/Downloads
openssl x509 -in gitlab.local-ca.pem -noout -fingerprint -sha256
# sha256 Fingerprint=C8:34:74:D8:EF:74:46:8F:00:18:F0:9A:57:1C:83:BA:41:0E:C6:FD:28:98:7E:12:F7:73:59:68:5C:F9:EC:67
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain gitlab.local-ca.pem
```

지문이 다르면 등록하지 말고 GitLab 관리자에게 확인합니다.

### 2. 내려받기

```sh
mkdir -p ~/.local/bin
curl -fL https://gitlab.local/api/v4/projects/11/packages/generic/hush/0.2.0/Hush -o ~/.local/bin/hush
chmod 755 ~/.local/bin/hush
```

브라우저가 아니라 `curl`로 받습니다. 브라우저로 받은 파일은 macOS가 "확인되지 않은 개발자"라며 실행을 막습니다. 이미 그렇게 받았다면 `xattr -d com.apple.quarantine ~/.local/bin/hush`로 풀 수 있습니다.

`~/.local/bin`이 PATH에 없으면 추가하고 터미널을 새로 엽니다.

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

마지막으로 최신 버전으로 올립니다. 위 주소는 0.2.0이며, 이 명령이 최신 버전을 받아 교체합니다.

```sh
hush update
```

## 처음 실행

```sh
hush
```

1. 개인 비밀번호를 정하고 한 번 더 입력합니다. 이 비밀번호로 대화 기록을 암호화하며, **잊으면 기록을 복구할 수 없습니다.** 상대와 같은 비밀번호일 필요는 없습니다.
2. 백그라운드 수신기가 로그인 항목으로 등록되어 바로 시작합니다. macOS가 "백그라운드 항목 추가" 알림을 띄울 수 있습니다.
3. 터미널 앱이 로컬 네트워크 접근을 물으면 **허용**합니다. 허용하지 않으면 메시지를 주고받을 수 없습니다.
4. 메뉴 상단에 사용하는 네트워크와 `수신기 켜짐`이 보이고, 화면 위 메뉴 막대에 말풍선 아이콘이 생기면 준비가 끝났습니다.

이후에는 `hush`를 실행할 때마다 비밀번호를 입력합니다.

## 사용법

메뉴에서는 키 하나만 누르면 됩니다.

| 키 | 동작 |
|---|---|
| `1` | 채팅 |
| `2` | 기록 보기 (생성 시각과 함께, 아무 키나 누르면 메뉴로) |
| `q` | 종료 |

채팅 화면에서는 다음 키를 씁니다.

| 키 | 동작 |
|---|---|
| Enter | 보내기 |
| Backspace | 마지막 글자 지우기 |
| Ctrl-U | 입력 전체 지우기 |
| `/help` | 명령 보기 |
| `/clear` | 화면 지우기 (대화 기록은 유지) |
| `/quit` 또는 빈 입력에서 Ctrl-D | 메뉴로 돌아가기 |
| `//내용` | `/`로 시작하는 메시지 보내기 |
| Ctrl-C | Hush 즉시 종료 |

- `/`로 시작하는 입력은 메시지로 보내지 않습니다. 모르는 명령은 안내만 하고 보내지 않으니, `/`로 시작하는 글은 `//`로 시작해 보냅니다.
- 메시지는 보낸 사람의 IP와 함께 표시되고, 내 메시지는 밝은 초록 굵은 글씨로 구분됩니다.
- 상대 채팅 화면이 열려 있으면 `상대 <IP>: 온라인`으로 표시됩니다. 오프라인이어도 보낼 수 있으며, 상대 수신기가 켜져 있으면 받아 둡니다.
- 받았다는 확인은 없습니다. 상대 Mac이 잠자기 중이거나 네트워크가 끊겨 있으면 메시지가 전달되지 않을 수 있습니다.
- 네트워크는 Wi-Fi를 먼저, 없으면 기본 유선 네트워크를 자동으로 고릅니다.

## 새 메시지 표시

채팅 화면을 닫아 두어도 수신기가 메시지를 받아 두고, 메뉴 막대의 말풍선으로 알려 줍니다.

| 메뉴 막대 | 뜻 |
|---|---|
| 흑백 테두리 말풍선 | 수신기 실행 중, 새 메시지 없음 |
| 채운 말풍선 + 빨간 숫자 배지 | 아직 읽지 않은 새 메시지 건수 (10건 이상은 `9+`) |

- 건수만 보이고 내용과 보낸 사람은 `hush`를 열어 비밀번호를 넣어야 보입니다.
- 아이콘을 누르고 `Hush 열기`를 고르면 터미널 새 창에서 `hush`가 열립니다. `hush`를 열면 배지가 사라집니다.
- 소리나 알림 배너는 없습니다.

## 업데이트

채팅 중에는 새 버전을 자동으로 확인해 설치하고 다시 시작합니다. 다시 시작하면 비밀번호를 한 번 더 입력합니다. 바로 받으려면 다음을 실행합니다. `hush upgrade`도 같습니다.

```sh
hush update
```

## 문제 해결

| 증상 | 확인할 것 |
|---|---|
| 메뉴에 `수신기 꺼짐` | `hush`를 다시 실행하면 등록을 다시 확인합니다. 로그는 `~/Library/Logs/Hush/receiver.log`에 있습니다. |
| 메뉴 막대에 말풍선이 없음 | `hush`를 한 번 실행해 등록을 갱신합니다. 그래도 없으면 시스템 설정의 메뉴 막대에서 `hush`가 허용되어 있는지 확인합니다. |
| `네트워크를 자동으로 정할 수 없습니다` | Wi-Fi나 유선 네트워크 연결을 확인합니다. |
| `업데이트 확인·적용 실패` 또는 `hush update` 실패 | 위 "gitlab.local 접속 준비" 두 가지를 확인합니다. |
| 상대 메시지가 오지 않음 | 두 Mac이 같은 공유기의 같은 네트워크에 있는지(게스트 네트워크 제외), 터미널의 로컬 네트워크 접근 허용과 macOS 방화벽 설정을 확인합니다. |
| 비밀번호를 잊음 | 기록을 복구할 수 없습니다. 아래 "삭제"의 기록 삭제 후 새로 시작합니다. |

## 삭제

```sh
launchctl bootout gui/$(id -u)/local.hush.receiver
rm -f ~/Library/LaunchAgents/local.hush.receiver.plist
rm -f ~/.local/bin/hush ~/.local/bin/hush.previous ~/.local/bin/hush.update.lock
```

대화 기록과 로그까지 지우려면 다음을 실행합니다. 되돌릴 수 없습니다.

```sh
rm -rf ~/Library/Application\ Support/Hush ~/Library/Logs/Hush
```

## 개발자 문서

- [요구사항](docs/requirements.md)
- [개발 규약과 구조](docs/development.md)
- [빌드·실행·테스트](docs/running.md)
- [배포와 새 버전 게시](docs/deployment.md)
