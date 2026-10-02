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

            def udp_sockets(pid):
                return subprocess.run(["lsof", "-a", "-n", "-P", "-p", str(pid), "-iUDP"], capture_output=True).stdout

            def send(content, created_at, count=3):
                incoming = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                incoming.bind(("127.0.0.1", 0))
                try:
                    packet = base64.b64decode(subprocess.check_output([fixture, "message", content, created_at]))
                    for _ in range(count):
                        incoming.sendto(packet, ("127.0.0.1", port))
                finally:
                    incoming.close()

            inbox = history_directory / "inbox.jsonl"

            def wait_for_inbox():
                deadline = time.monotonic() + 5
                while not (inbox.exists() and inbox.stat().st_size > 0):
                    assert time.monotonic() < deadline, "수신함 저장 대기 실패"
                    time.sleep(0.05)

            # Given: 서명한 새 버전의 HTTP 응답을 기다리며 채팅과 비밀번호 없는 수신기가 실행 중입니다.
            chat = launch()
            chat.unlock(password, first=True)
            chat.expect("내 IP")
            receiver = launch("receive")
            receiver.expect("수신 중")
            chat.send("업데이트 이전 기록\r")
            chat.expect("업데이트 이전 기록")
            wait_for_history(1)
            before = (history_directory / "history.json").read_bytes()
            chat.output = b""
            receiver.output = b""
            # When: 새 버전 응답을 제공하면 두 역할이 같은 실행 파일로 즉시 재시작합니다.
            server.ready.set()
            chat.expect("개인 비밀번호: ", timeout=25)
            receiver.expect("수신 중", timeout=25)
            assert subprocess.check_output([str(installed), "--version"]).decode().strip() == "0.2.0"
            assert subprocess.check_output([str(installed) + ".previous", "--version"]).decode().strip() == "0.1.0"
            # Then: 채팅은 이전 키를 유지하지 않고 인증 전에는 소켓·기록을 열지 않으며, 수신기는 비밀번호 없이 수신을 이어갑니다.
            assert (history_directory / "history.json").read_bytes() == before
            assert udp_sockets(chat.pid) == b"", "인증 전 채팅의 UDP 소켓"
            assert "비밀번호".encode() not in receiver.output, "재시작한 수신기의 비밀번호 요청"
            send("재인증 이전 수신", "2000", count=1)
            wait_for_inbox()
            chat.send(password + "\n")
            chat.expect("Hush 0.2.0")
            chat.expect("업데이트 이전 기록")
            chat.expect("재인증 이전 수신")
            assert password.encode() not in chat.output
            chat.send("/quit\r")
            assert chat.wait() == 0
            # When: 수신기만 실행 중일 때 기존 형식의 메시지를 반복 송신합니다.
            send("업데이트 이후 수신", "2001")
            records = wait_for_history(3)
            # Then: 채팅 재인증을 기다리는 동안의 메시지까지 수신기가 한 건씩 저장합니다.
            assert [record["message"]["content"] for record in records] == ["업데이트 이전 기록", "재인증 이전 수신", "업데이트 이후 수신"]
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

            # Given: 비밀번호 없이 실행한 수신기가 터미널을 닫은 채 새 버전 응답을 기다립니다.
            server.ready.clear()
            server.binary = new.read_bytes()
            detached = launch("receive")
            detached.expect("수신 중")
            os.close(detached.fd)
            detached.fd = None
            assert os.waitpid(detached.pid, os.WNOHANG)[0] == 0
            # When: 터미널이 없는 수신기에 업데이트를 제공합니다.
            server.ready.set()
            deadline = time.monotonic() + 25
            while subprocess.check_output([str(installed), "--version"]).decode().strip() != "0.2.0":
                assert time.monotonic() < deadline, "터미널 없는 수신기의 업데이트 대기 실패"
                time.sleep(0.2)
            # Then: 새 파일로 교체한 뒤 비밀번호 없이 같은 프로세스로 수신을 이어가고 기존 기록을 유지합니다.
            assert (history_directory / "history.json").read_bytes() == before
            deadline = time.monotonic() + 10
            while len(history()) != 4:
                assert time.monotonic() < deadline, "업데이트 후 수신 재개 대기 실패"
                send("터미널 없이 업데이트 후 수신", "2002", count=1)
                time.sleep(0.5)
            assert history()[-1]["message"]["content"] == "터미널 없이 업데이트 후 수신"
            assert os.waitpid(detached.pid, os.WNOHANG)[0] == 0
            detached.close()
            print("PASS: release 버전 교체·HTTP 대기 중 채팅·동시 역할 재시작·채팅 재인증·비밀번호 없는 수신 유지·소켓 정리·변조 거부·터미널 없는 수신기 업데이트")
    finally:
        server.ready.set()
        for app in apps:
            app.close()
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
