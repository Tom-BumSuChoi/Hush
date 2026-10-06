# Hush 배포

## 대상과 산출물

macOS 13 이상을 대상으로 Apple Silicon과 Intel 실행 코드를 한 파일에 담는다. Swift 6.4 개발 환경에서 다음 명령을 실행한다.

```sh
bash Tools/build_release.sh
```

산출물은 `.build/distribution/Hush`이다. 스크립트는 두 아키텍처의 release 빌드, universal 파일 생성, 로컬 실행을 위한 ad-hoc 코드 서명과 서명 검증, 버전 출력을 수행한다. ad-hoc 서명은 배포자를 인증하는 서명이 아니며, 업데이트의 신뢰 검증은 아래의 별도 배포 서명 키로 수행한다. 두 Mac에 동일한 통신용 공유키가 포함된 파일을 전달한다.

## 배포 서버

업데이트 파일은 GitHub 공개 저장소 [`Tom-BumSuChoi/Hush`](https://github.com/Tom-BumSuChoi/Hush)의 릴리스로 제공한다. 버전마다 `v<버전>` 태그의 릴리스를 만들고 실행 파일 `Hush`와 서명한 `manifest.json`을 첨부한다. Hush는 로그인 없이 파일을 받으며, 저장소와 릴리스가 공개이므로 누구나 실행 파일을 받을 수 있고 실행 파일에는 통신용 공유키가 포함된다.

| 대상 | 주소 |
|---|---|
| 매니페스트 | `https://github.com/Tom-BumSuChoi/Hush/releases/latest/download/manifest.json` |
| 실행 파일 | `https://github.com/Tom-BumSuChoi/Hush/releases/download/v<버전>/Hush` |

매니페스트 주소의 `latest`는 GitHub가 가장 최근의 정식 릴리스(초안·사전 릴리스 제외)로 리다이렉트하며, Hush는 리다이렉트를 따라 파일을 받는다. 사용자용 설치 절차는 저장소의 [README](../README.md)에 있으며, README는 `latest` 주소로 내려받으므로 새 버전을 게시할 때 고치지 않아도 된다. GitHub에 접속할 수 없으면 실행은 유지되지만 채팅 화면에 업데이트 확인 실패 안내가 확인 주기마다 표시된다.

0.6.0 이하는 사내 GitLab `gitlab.local`의 패키지 저장소 주소를 매니페스트 주소로 내장했다. 해당 프로젝트가 없어져 자동 업데이트로는 GitHub 주소로 옮길 수 없으므로, README의 "0.6.0 이하에서 옮기기" 명령으로 한 번 직접 교체한다.

## 업데이트 신뢰 설정

배포 서명 키는 `$HOME/.hush-release-keys`에 생성했으며, 공개키와 매니페스트 주소는 `Sources/Hush/Configuration/HushConfig.swift`의 `updateSigningPublicKeyBase64`·`updateManifestURL`에 설정되어 있다. 키는 [실행과 검증](running.md)의 명령으로 `.build/ReleaseTool`을 빌드한 뒤 다음 명령으로 만들었다.

```sh
.build/ReleaseTool keygen "$HOME/.hush-release-keys"
```

개인키는 해당 디렉터리의 `signing-private-key` 파일이며 프로그램·공유 배포 디렉터리·Git 저장소에 포함하지 않고 별도로 백업한다. 개인키를 잃으면 설치된 프로그램에 새 버전을 배포할 수 없어 다시 설치해야 한다. 이후 배포에도 같은 키를 사용한다.

새 버전은 `HushConfig.version`에 배포할 `주.부.패치` 버전을 설정한 뒤 다시 빌드한다. 두 업데이트 설정은 함께 지정하며, 각 새 버전에도 같은 매니페스트 주소와 공개키를 포함한다. 기록 형식·통신 형식은 현재 모두 버전 1이며, 형식 변경이나 키 교체가 필요한 배포는 별도 호환성 설계가 필요하다. 0.8.0에서 더한 입력 중 신호는 패킷 종류만 늘린 것이라 버전 1을 유지하며, 0.7.0 이하는 이 신호만 버리고 메시지는 그대로 주고받는다.

## 새 버전 게시

예를 들어 `HushConfig.version`을 `0.7.0`으로 변경해 빌드했다면 다음 명령으로 매니페스트를 서명하고 검증한다.

```sh
release_version='0.7.0'
release_base='https://github.com/Tom-BumSuChoi/Hush/releases/download'
release_public_key='2Nh7R0TJAide4WVjaU4rVFvfSpaO5vwLDQTjur04Kvg='
.build/ReleaseTool manifest .build/distribution/Hush "$release_version" \
  "$release_base/v$release_version/Hush" "$HOME/.hush-release-keys/signing-private-key" \
  .build/distribution/manifest.json
.build/ReleaseTool verify .build/distribution/manifest.json \
  "$release_public_key" .build/distribution/Hush
```

검증 출력이 `0.7.0`인지 확인한다. 버전 커밋을 GitHub `main`에 올린 뒤, `gh`로 GitHub에 로그인한 상태에서 실행 파일과 매니페스트를 첨부한 릴리스를 만든다. `gh`는 파일을 모두 올린 뒤 릴리스를 공개하므로 `latest` 매니페스트가 아직 올라가지 않은 실행 파일을 가리키는 순간이 없다.

```sh
gh release create "v$release_version" -R Tom-BumSuChoi/Hush --target main \
  --title "$release_version" --notes '<변경 내용>' \
  .build/distribution/Hush .build/distribution/manifest.json
```

실행 중인 Hush는 10분 이내에 새 버전을 받으며, 사용자는 `hush update`로 바로 받을 수 있다. 파일은 압축하지 않은 Mach-O 실행 파일이며 파일을 변경했다면 매니페스트도 다시 서명한다. 채팅을 중계하는 서버는 필요하지 않으며 GitHub은 업데이트 파일만 제공한다.

## 최초 설치와 복구

각 사용자가 쓸 수 있는 PATH의 디렉터리에 `hush`라는 이름으로 복사하고 실행 권한을 부여한다. 대소문자를 구분하는 볼륨에서도 `hush`로 실행할 수 있도록 설치 이름은 소문자로 둔다. 예시는 다음과 같으며, 메뉴·채팅·수신기는 모두 같은 경로의 파일을 실행한다.

```sh
mkdir -p "$HOME/.local/bin"
cp .build/distribution/Hush "$HOME/.local/bin/hush"
chmod 755 "$HOME/.local/bin/hush"
hush
```

`$HOME/.local/bin`이 PATH에 없으면 zsh 설정(`~/.zshrc`)에 `export PATH="$HOME/.local/bin:$PATH"`를 추가한다.

처음 `hush`를 실행해 비밀번호를 정하면 백그라운드 수신기가 로그인 항목으로 등록되어 바로 시작한다. 이후 설치 경로를 옮겼다면 `hush`를 한 번 실행해 등록을 갱신한다.

최초 설치 파일은 신뢰한 경로로 두 사용자에게 전달한다. 시스템 소유 디렉터리처럼 업데이트를 쓸 수 없는 위치에서는 자동 교체가 실패한다. 개발 중인 SPM 빌드 경로는 재빌드로 파일이 바뀔 수 있으므로 실제 사용에는 별도 설치 경로를 사용한다.

업데이트 후 채팅은 비밀번호를 다시 요청하고, 수신기는 터미널이 닫혀 있어도 비밀번호 없이 새 버전으로 수신을 이어간다.

교체 전 실행 파일은 설치 경로에 `.previous`를 붙인 파일로 남는다. 새 파일로의 `execv` 실패 시 자동으로 되돌린다. 새 버전 실행 이후 문제가 발견되면 두 역할을 종료한 뒤 `.previous` 파일을 복원하고 문제가 된 릴리스를 삭제하거나 초안으로 되돌려 이전 릴리스가 `latest`가 되게 해야 한다. 그렇지 않으면 복원한 프로그램이 같은 새 버전을 다시 발견한다. 실행 파일 복원은 개인 기록을 변경하지 않으며, 기록 형식을 변경한 미래 버전의 역호환을 보장하지 않는다.

## 실제 환경 확인

로컬 PTY·UDP·HTTP 통합 검증과 실제 사내망 검증은 구분한다. 두 Mac에서 같은 UDP 포트와 배포 파일을 사용해 다음을 확인한다.

1. iTerm2와 VS Code에서 한글 입력, 상대 IP, 내 메시지 하이라이트와 조용한 새 메시지 표시
2. 양방향 메시지 한 번 표시·저장, 같은 내용을 새로 보냈을 때 별도 기록
3. 채팅 종료 후 12초 오프라인 전환, 로그인 후 자동 실행된 수신기의 상대 브로드캐스트 저장, 채팅 재실행 후 기록 조회
4. 새 배포 발견 후 두 역할의 자동 재시작과 각각의 비밀번호 재입력

현재 개발 Mac에서 두 아키텍처 빌드를 검증하더라도 실제 Intel Mac·macOS 13·사내 네트워크·두 터미널의 결과는 해당 환경에서 확인해야 한다.
