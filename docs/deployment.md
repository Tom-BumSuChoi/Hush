# Hush 배포

## 대상과 산출물

macOS 13 이상을 대상으로 Apple Silicon과 Intel 실행 코드를 한 파일에 담는다. Swift 6.4 개발 환경에서 다음 명령을 실행한다.

```sh
bash Tools/build_release.sh
```

산출물은 `.build/distribution/Hush`이다. 스크립트는 두 아키텍처의 release 빌드, universal 파일 생성, 로컬 실행을 위한 ad-hoc 코드 서명과 서명 검증, 버전 출력을 수행한다. ad-hoc 서명은 배포자를 인증하는 서명이 아니며, 업데이트의 신뢰 검증은 아래의 별도 배포 서명 키로 수행한다. 두 Mac에 동일한 통신용 공유키가 포함된 파일을 전달한다.

## 업데이트 신뢰 설정

사내망 주소가 아직 없으므로 현재 기본 설정의 자동 업데이트는 비활성이다. 주소가 정해지면 [실행과 검증](running.md)의 명령으로 `.build/ReleaseTool`을 빌드한 뒤, 최초 한 번 배포 서명 키를 생성한다.

```sh
.build/ReleaseTool keygen "$HOME/.hush-release-keys"
```

표준 출력의 base64 공개키를 보관한다. 개인키는 해당 디렉터리의 `signing-private-key` 파일이며 프로그램·공유 배포 디렉터리·Git 저장소에 포함하지 않는다. 이후 배포에도 같은 키를 사용한다.

`Sources/Hush/Configuration/HushConfig.swift`에서 다음 값을 설정한 뒤 배포 파일을 다시 빌드한다.

- `version`: 배포할 `주.부.패치` 버전
- `updateManifestURL`: 사내 서버에서 제공할 `manifest.json`의 HTTP(S) 주소
- `updateSigningPublicKeyBase64`: 생성 도구가 출력한 공개키

두 업데이트 설정은 함께 지정한다. 각 새 버전에도 같은 매니페스트 주소와 공개키를 포함한다. 기록 형식·통신 형식은 현재 모두 버전 1이며, 형식 변경이나 키 교체가 필요한 배포는 별도 호환성 설계가 필요하다.

## 새 버전 게시

예를 들어 `HushConfig.version`을 `0.2.0`으로 변경해 빌드했다면, 실제 서버 주소를 사용해 다음 명령을 실행한다. `release_download_url`과 `release_public_key`는 실제 배포 값으로 바꾼다.

```sh
release_download_url='https://실제-사내-서버/releases/0.2.0/Hush'
release_public_key='키 생성 도구가 출력한 base64 공개키'
.build/ReleaseTool manifest .build/distribution/Hush 0.2.0 \
  "$release_download_url" "$HOME/.hush-release-keys/signing-private-key" \
  .build/distribution/manifest.json
.build/ReleaseTool verify .build/distribution/manifest.json \
  "$release_public_key" .build/distribution/Hush
```

검증 출력이 `0.2.0`인지 확인한다. 실행 파일을 버전별 다운로드 주소에 먼저 게시하고, 설정한 주소의 매니페스트를 마지막으로 교체한다. 파일은 압축하지 않은 Mach-O 실행 파일이며 파일을 변경했다면 매니페스트도 다시 서명한다. 채팅을 중계하는 서버는 필요하지 않으며 이 서버는 업데이트 파일만 제공한다.

## 최초 설치와 복구

각 사용자가 쓸 수 있는 디렉터리에 `Hush`를 복사하고 실행 권한을 부여한다. 예시는 다음과 같으며, 채팅과 수신기는 모두 같은 경로의 파일을 실행한다.

```sh
mkdir -p "$HOME/.local/bin"
cp .build/distribution/Hush "$HOME/.local/bin/Hush"
chmod 755 "$HOME/.local/bin/Hush"
"$HOME/.local/bin/Hush" chat --interface en0
```

최초 설치 파일은 신뢰한 경로로 두 사용자에게 전달한다. 시스템 소유 디렉터리처럼 업데이트를 쓸 수 없는 위치에서는 자동 교체가 실패한다. 개발 중인 SPM 빌드 경로는 재빌드로 파일이 바뀔 수 있으므로 실제 사용에는 별도 설치 경로를 사용한다.

업데이트 후에는 각 프로세스가 비밀번호를 다시 요청한다. 터미널을 닫은 수신기가 업데이트로 종료되면 새 터미널에서 `receive`를 다시 실행해 인증한다. 이때까지 메시지가 누락될 수 있다.

교체 전 실행 파일은 설치 경로에 `.previous`를 붙인 파일로 남는다. 새 파일로의 `execv` 실패 시 자동으로 되돌린다. 새 버전 실행 이후 문제가 발견되면 두 역할을 종료한 뒤 `.previous` 파일을 복원하고 문제 버전 매니페스트를 내려야 한다. 그렇지 않으면 복원한 프로그램이 같은 새 버전을 다시 발견한다. 실행 파일 복원은 개인 기록을 변경하지 않으며, 기록 형식을 변경한 미래 버전의 역호환을 보장하지 않는다.

## 실제 환경 확인

로컬 PTY·UDP·HTTP 통합 검증과 실제 사내망 검증은 구분한다. 두 Mac에서 같은 UDP 포트와 배포 파일을 사용해 다음을 확인한다.

1. iTerm2와 VS Code에서 한글 입력, 상대 IP, 내 메시지 하이라이트와 조용한 새 메시지 표시
2. 양방향 메시지 한 번 표시·저장, 같은 내용을 새로 보냈을 때 별도 기록
3. 채팅 종료 후 12초 오프라인 전환, 수신기만 실행 중인 상태에서 저장, 채팅 재실행 후 기록 조회
4. 새 배포 발견 후 두 역할의 자동 재시작과 각각의 비밀번호 재입력

현재 개발 Mac에서 두 아키텍처 빌드를 검증하더라도 실제 Intel Mac·macOS 13·사내 네트워크·두 터미널의 결과는 해당 환경에서 확인해야 한다.
