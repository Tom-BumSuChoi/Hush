"""실제 Hush 두 버전·HTTP·PTY로 자동 교체와 재인증 검증."""
import argparse
import json
import os
import select
import shutil
import socket
import subprocess
import tempfile
import threading
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
            configured = original.replace('static let updateManifestURL: URL? = nil',
                f'static let updateManifestURL: URL? = URL(string: "http://127.0.0.1:{server.server_port}/manifest.json")')
            configured = configured.replace('static let updateSigningPublicKeyBase64: String? = nil',
                f'static let updateSigningPublicKeyBase64: String? = "{public_key}"')

            def build(version):
                config.write_text(configured.replace('static let version = "0.1.0"', f'static let version = "{version}"'))
                result = subprocess.run(["swift", "build", "--package-path", str(source)], capture_output=True)
                assert result.returncode == 0, result.stderr.decode()
                path = subprocess.check_output(["swift", "build", "--package-path", str(source), "--show-bin-path"]).decode().strip()
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

            # Given: 서명한 새 버전의 HTTP 응답을 기다리며 기존 두 역할이 실행 중입니다.
            receiver = launch("receive")
            receiver.unlock(password, first=True)
            receiver.expect("수신 중")
            chat = launch()
            chat.unlock(password)
            chat.expect("내 IP")
            chat.send("업데이트 이전 기록\r")
            chat.expect("업데이트 이전 기록")
            saved = subprocess.check_output([fixture, "history", str(history_directory), password])
            assert len(json.loads(saved)) == 1
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
            chat.send(password + "\n")
            receiver.send(password + "\n")
            chat.expect("Hush 0.2.0")
            chat.expect("업데이트 이전 기록")
            receiver.expect("수신 중")
            assert password.encode() not in chat.output
            assert password.encode() not in receiver.output
            chat.send("/quit\r")
            assert chat.wait() == 0
            receiver.close()
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
            print("PASS: HTTP 대기 중 채팅·서명 다운로드·동시 역할 자동 재시작·키 재인증·소켓 정리·기록 유지·변조 거부")
    finally:
        server.ready.set()
        for app in apps:
            app.close()
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
