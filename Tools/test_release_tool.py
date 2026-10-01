"""실제 배포 도구의 키 생성·서명·검증 사이클 검증."""
import argparse
import os
import subprocess
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tool", required=True)
    args = parser.parse_args()
    tool = str(Path(args.tool).resolve())
    with tempfile.TemporaryDirectory(prefix="hush-signing-") as temporary:
        directory = Path(temporary)
        keys = directory / "keys"
        public_key = subprocess.check_output([tool, "keygen", str(keys)]).decode().strip()
        private_key = keys / "signing-private-key"
        assert os.stat(private_key).st_mode & 0o777 == 0o600
        original = private_key.read_bytes()
        duplicate = subprocess.run([tool, "keygen", str(keys)], capture_output=True)
        assert duplicate.returncode != 0
        assert private_key.read_bytes() == original
        binary = directory / "Hush"
        binary.write_bytes(b"test release")
        manifest = directory / "manifest.json"
        # Given: 키와 배포 파일이 있습니다.
        # When: 버전 정보를 서명하고 배포한 파일을 검증합니다.
        subprocess.check_call([tool, "manifest", str(binary), "0.2.0", "https://updates.example.test/Hush", str(private_key), str(manifest)])
        version = subprocess.check_output([tool, "verify", str(manifest), public_key, str(binary)]).decode().strip()
        # Then: 같은 공개키와 원본 파일만 검증에 성공합니다.
        assert version == "0.2.0"
        binary.write_bytes(b"tampered release")
        tampered = subprocess.run([tool, "verify", str(manifest), public_key, str(binary)], capture_output=True)
        assert tampered.returncode != 0
        other_public = subprocess.check_output([tool, "keygen", str(directory / "other")]).decode().strip()
        other = subprocess.run([tool, "verify", str(manifest), other_public, str(binary)], capture_output=True)
        assert other.returncode != 0
    print("PASS: 서명 키 권한·기존 키 보존·배포 서명·공개키 검증·변조 거부")


if __name__ == "__main__":
    main()
