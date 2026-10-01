"""실제 Hush 두 버전·HTTP·PTY로 자동 교체와 재인증 검증."""
import argparse
import base64
import json
import os
import re
import select
import shutil
import socket
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from test_cli import App


class Server(ThreadingHTTPServer):
    def __init__(self):
        super().__init__(("127.0.0.1", 0), Handler)
        self.ready = threading.Event()
        self.manifest = b""
        self.binary = b""
        self.requests = []


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.server.requests.append(self.path)
        if self.path == "/manifest.json":
            self.server.ready.wait(10)
            data = self.server.manifest
        elif self.path == "/Hush":
            data = self.server.binary
        else:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-tool", required=True)
    parser.add_argument("--fixture", required=True)
    parser.add_argument("--interface", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    release_tool = str(Path(args.release_tool).resolve())
    fixture = str(Path(args.fixture).resolve())
    server = Server()
    threading.Thread(target=server.serve_forever, daemon=True).start()
    apps = []
    password = "hush-update-test-password"
    try:
        with tempfile.TemporaryDirectory(prefix="hush-update-") as temporary:
            directory = Path(temporary)
            source = directory / "source"
            source.mkdir()
            shutil.copy(root / "Package.swift", source)
            shutil.copytree(root / "Sources", source / "Sources")
            shutil.copytree(root / "Tests", source / "Tests")
            public_key = subprocess.check_output([release_tool, "keygen", str(directory / "keys")]).decode().strip()
            config = source / "Sources/Hush/Configuration/HushConfig.swift"
            original = config.read_text()

            def setting(contents, name, value):
                pattern = rf"(?m)^([ \t]*static let {name}[^=\n]*= ).*$"
                updated, count = re.subn(pattern, lambda match: match[1] + value, contents)
                assert count == 1, f"테스트 설정을 찾을 수 없음: {name}"
                return updated

            configured = setting(original, "updateManifestURL",
                f'URL(string: "http://127.0.0.1:{server.server_port}/manifest.json")')
            configured = setting(configured, "updateSigningPublicKeyBase64", json.dumps(public_key))

            def build(version):
                config.write_text(setting(configured, "version", json.dumps(version)))
                result = subprocess.run(["swift", "build", "-c", "release", "--package-path", str(source)], capture_output=True)
                assert result.returncode == 0, result.stderr.decode()
                path = subprocess.check_output(["swift", "build", "-c", "release", "--package-path", str(source), "--show-bin-path"]).decode().strip()
                target = directory / ("Hush-" + version)
                shutil.copy2(Path(path) / "Hush", target)
                return target

            old = build("0.1.0")
            new = build("0.2.0")
            manifest = directory / "manifest.json"
            subprocess.check_call([release_tool, "manifest", str(new), "0.2.0", f"http://127.0.0.1:{server.server_port}/Hush",
                                   str(directory / "keys/signing-private-key"), str(manifest)])
            server.manifest = manifest.read_bytes()
            server.binary = new.read_bytes()
            installed = directory / "Hush"
            shutil.copy2(old, installed)
            history_directory = directory / "history"
            reservation = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            reservation.bind(("0.0.0.0", 0))
            port = reservation.getsockname()[1]
            reservation.close()

            def launch(role="chat"):
                app = App(str(installed), [role, "--interface", args.interface, "--port", str(port),
                                          "--history-directory", str(history_directory)])
                apps.append(app)
                return app

            def history():
                return json.loads(subprocess.check_output([fixture, "history", str(history_directory), password]))

            def wait_for_history(count):
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    records = history()
                    if len(records) == count:
                        return records
                    time.sleep(0.05)
                raise AssertionError(f"기록 수 대기 실패: {count}")

            # Given: 서명한 새 버전의 HTTP 응답을 기다리며 기존 두 역할이 실행 중입니다.
            receiver = launch("receive")
            receiver.unlock(password, first=True)
            receiver.expect("수신 중")
            chat = launch()
            chat.unlock(password)
            chat.expect("내 IP")
            chat.send("업데이트 이전 기록\r")
            chat.expect("업데이트 이전 기록")
            wait_for_history(1)
            before = (history_directory / "history.json").read_bytes()
            chat.output = b""
            receiver.output = b""
            # When: 새 버전 응답을 제공하면 두 역할이 같은 실행 파일로 즉시 재시작합니다.
            server.ready.set()
            chat.expect("개인 비밀번호: ", timeout=25)
            receiver.expect("개인 비밀번호: ", timeout=25)
            assert subprocess.check_output([str(installed), "--version"]).decode().strip() == "0.2.0"
            assert subprocess.check_output([str(installed) + ".previous", "--version"]).decode().strip() == "0.1.0"
            # Then: 이전 키로 잠금을 유지하지 않으며 인증 전에는 UDP·기록 저장을 진행하지 않습니다.
            assert (history_directory / "history.json").read_bytes() == before
            probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            probe.bind(("0.0.0.0", port))
            probe.close()
            incoming = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            incoming.bind(("127.0.0.1", 0))
            try:
                locked_packet = base64.b64decode(subprocess.check_output([fixture, "message", "재인증 이전 수신", "2000"]))
                incoming.sendto(locked_packet, ("127.0.0.1", port))
            finally:
                incoming.close()
            chat.send(password + "\n")
            receiver.send(password + "\n")
            chat.expect("Hush 0.2.0")
            chat.expect("업데이트 이전 기록")
            receiver.expect("수신 중")
            assert password.encode() not in chat.output
            assert password.encode() not in receiver.output
            chat.send("/quit\r")
            assert chat.wait() == 0
            # When: 재인증한 새 버전 수신기에 기존 형식의 메시지를 반복 송신합니다.
            incoming = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            incoming.bind(("127.0.0.1", 0))
            try:
                packet = base64.b64decode(subprocess.check_output([fixture, "message", "업데이트 이후 수신", "2001"]))
                for _ in range(3):
                    incoming.sendto(packet, ("127.0.0.1", port))
                records = wait_for_history(2)
            finally:
                incoming.close()
            # Then: 수신기 단독으로 저장을 재개하며 잠금 중 패킷은 저장되지 않습니다.
            assert [record["message"]["content"] for record in records] == ["업데이트 이전 기록", "업데이트 이후 수신"]
            assert records[-1]["message"]["identity"]["senderIP"] == "127.0.0.1"
            assert records[-1]["isOutgoing"] is False
            receiver.close()
            before = (history_directory / "history.json").read_bytes()
            assert server.requests.count("/Hush") >= 1

            # Given: 파일이 변조된 배포 응답과 기존 실행 버전이 있습니다.
            shutil.copy2(old, installed)
            server.binary = b"tampered executable"
            tampered = launch()
            tampered.unlock(password)
            tampered.expect("내 IP")
            # When: 변조된 다운로드 파일을 실제로 검증합니다.
            tampered.expect("업데이트 확인·적용 실패", timeout=15)
            # Then: 파일을 교체하거나 재시작하지 않고 기존 대화를 유지합니다.
            assert subprocess.check_output([str(installed), "--version"]).decode().strip() == "0.1.0"
            assert (history_directory / "history.json").read_bytes() == before
            tampered.send("/quit\r")
            assert tampered.wait() == 0
            print("PASS: release 버전 교체·HTTP 대기 중 채팅·동시 역할 재시작·키 재인증·소켓 정리·수신 재개·변조 거부")
    finally:
        server.ready.set()
        for app in apps:
            app.close()
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
