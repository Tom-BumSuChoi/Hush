"""실제 PTY·UDP·암호화 기록을 사용하는 CLI 통합 검증."""
import argparse
import base64
import json
import os
import pty
import select
import signal
import socket
import subprocess
import tempfile
import termios
import time
from pathlib import Path


class App:
    def __init__(self, binary, arguments):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execv(binary, [binary, *arguments])
        self.output = b""
        self.status = None

    def expect(self, text, timeout=5):
        expected = text.encode()
        end = time.monotonic() + timeout
        while expected not in self.output:
            if time.monotonic() >= end:
                raise AssertionError(f"출력 대기 실패: {text!r}")
            if select.select([self.fd], [], [], 0.1)[0]:
                try:
                    chunk = os.read(self.fd, 65536)
                except OSError:
                    chunk = b""
                if not chunk:
                    raise AssertionError(f"프로세스가 출력 전에 종료됨: {text!r}")
                self.output += chunk

    def send(self, text):
        os.write(self.fd, text.encode())

    def unlock(self, password, first=False):
        self.expect("새 개인 비밀번호: " if first else "개인 비밀번호: ")
        self.send(password + "\n")
        if first:
            self.expect("비밀번호 확인: ")
            self.send(password + "\n")

    def wait(self, timeout=5):
        end = time.monotonic() + timeout
        while self.status is None and time.monotonic() < end:
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid:
                self.status = os.waitstatus_to_exitcode(status)
                return self.status
            if self.fd is not None and select.select([self.fd], [], [], 0.05)[0]:
                try:
                    self.output += os.read(self.fd, 65536)
                except OSError:
                    pass
            else:
                select.select([], [], [], 0.05)
        assert self.status is not None, "프로세스 종료 대기 실패"
        return self.status

    def close(self):
        if self.status is None:
            try:
                os.kill(self.pid, signal.SIGTERM)
                self.wait()
            except ProcessLookupError:
                pass
            except AssertionError:
                os.kill(self.pid, signal.SIGKILL)
                self.status = os.waitstatus_to_exitcode(os.waitpid(self.pid, 0)[1])
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True)
    parser.add_argument("--fixture", required=True)
    parser.add_argument("--interface", required=True)
    args = parser.parse_args()
    binary = str(Path(args.binary).resolve())
    fixture = str(Path(args.fixture).resolve())
    password = "hush-local-test-password"

    def fixture_run(*arguments):
        return subprocess.check_output([fixture, *arguments])

    def history(directory):
        return json.loads(fixture_run("history", str(directory), password))

    def packet(kind, *arguments):
        return base64.b64decode(fixture_run(kind, *arguments))

    def launch(directory, port, role="chat"):
        return App(binary, [role, "--interface", args.interface, "--port", str(port), "--history-directory", str(directory)])

    with tempfile.TemporaryDirectory(prefix="hush-cli-") as temporary:
        directory = Path(temporary) / "history"
        observer = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        observer.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        observer.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        observer.bind(("0.0.0.0", 0))
        port = observer.getsockname()[1]
        apps = []
        try:
            # Given: 새 기록으로 시작한 실제 채팅 프로세스가 있습니다.
            chat = launch(directory, port)
            apps.append(chat)
            chat.unlock(password, first=True)
            chat.expect("내 IP")
            assert password.encode() not in chat.output, "비밀번호 출력 노출"
            # When: 새 메시지를 작성해 실제 UDP 브로드캐스트를 관찰합니다.
            chat.send("실제 송신 테스트\r")
            observed = []
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                ready = select.select([observer, chat.fd], [], [], max(0.01, deadline - time.monotonic()))[0]
                if chat.fd in ready:
                    chat.output += os.read(chat.fd, 65536)
                if observer not in ready:
                    continue
                data, _ = observer.recvfrom(65535)
                observed.append((data, time.monotonic()))
            packets = []
            times = []
            for data, received_at in observed:
                text = fixture_run("decode", base64.b64encode(data).decode()).decode().strip()
                if text == "실제 송신 테스트":
                    packets.append(data)
                    times.append(received_at)
            # Then: 같은 암호화 패킷을 약 0.5초 간격으로 정확히 세 번 보내고 한 번 기록합니다.
            assert len(packets) == 3, f"메시지 송신 횟수: {len(packets)}"
            assert packets[0] == packets[1] == packets[2]
            assert 0.3 <= times[1] - times[0] <= 0.8, f"첫 간격: {times[1] - times[0]:.3f}초"
            assert 0.3 <= times[2] - times[1] <= 0.8, f"두 번째 간격: {times[2] - times[1]:.3f}초"
            assert len(history(directory)) == 1
            observer.close()

            # Given: 채팅만 실행 중이며 상대 heartbeat와 메시지를 보내는 로컬 UDP가 있습니다.
            incoming = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            incoming.bind(("127.0.0.1", 0))
            # When: 상대 heartbeat와 동일한 메시지 세 패킷을 수신합니다.
            incoming.sendto(packet("heartbeat"), ("127.0.0.1", port))
            chat.expect("상대 127.0.0.1: 온라인")
            encrypted = packet("message", "상대 중복 테스트", "1000.123456")
            for _ in range(3):
                incoming.sendto(encrypted, ("127.0.0.1", port))
            chat.expect("새 메시지 [127.0.0.1] 상대 중복 테스트")
            incoming.sendto(b"invalid packet", ("127.0.0.1", port))
            chat.output = b""
            chat.expect("상대 127.0.0.1: 오프라인", timeout=14)
            # Then: heartbeat와 손상 패킷은 기록하지 않고 메시지는 한 건만 저장합니다.
            assert len(history(directory)) == 2
            chat.send("/quit\r")
            assert chat.wait() == 0
            assert termios.tcgetattr(chat.fd)[3] & (termios.ECHO | termios.ICANON) == (termios.ECHO | termios.ICANON)

            # Given: 비밀번호로 연 기록이 있고 수신기만 비밀번호 없이 실행 중입니다.
            receiver = launch(directory, port, role="receive")
            apps.append(receiver)
            receiver.expect("수신 중")
            assert "비밀번호".encode() not in receiver.output, "수신기의 비밀번호 요청"
            silence = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            silence.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            silence.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
            silence.bind(("0.0.0.0", port))
            assert not select.select([silence], [], [], 3.2)[0], "수신기 단독 실행의 heartbeat 송신"
            silence.close()
            # When: 수신기의 터미널을 닫은 뒤 새 메시지를 반복 수신합니다.
            os.close(receiver.fd)
            receiver.fd = None
            encrypted = packet("message", "화면 종료 뒤 수신", "1001")
            for _ in range(3):
                incoming.sendto(encrypted, ("127.0.0.1", port))
            inbox = directory / "inbox.jsonl"
            end = time.monotonic() + 3
            while not (inbox.exists() and inbox.stat().st_size > 0) and time.monotonic() < end:
                select.select([], [], [], 0.05)
            select.select([], [], [], 0.3)
            # Then: 터미널이 없어도 실행 중인 수신기가 평문 없이 한 건을 수신함에 쌓고, 비밀번호로 열면 기록에 합칩니다.
            assert len(inbox.read_bytes().splitlines()) == 1
            assert "화면 종료 뒤 수신".encode() not in inbox.read_bytes()
            assert len(history(directory)) == 3
            assert inbox.read_bytes() == b""
            assert os.waitpid(receiver.pid, os.WNOHANG)[0] == 0

            # Given: 채팅 화면을 다시 실행했습니다.
            restored = launch(directory, port)
            apps.append(restored)
            # When: 비밀번호를 다시 입력합니다.
            restored.unlock(password)
            restored.expect("[127.0.0.1] 화면 종료 뒤 수신")
            # Then: 새 인증 뒤 기존 내 메시지와 화면 종료 후 받은 메시지를 조회합니다.
            restored.expect("실제 송신 테스트")
            assert b"\x1b[1;92m" in restored.output
            duplicate = launch(directory, port)
            apps.append(duplicate)
            duplicate.unlock(password)
            duplicate.expect("chat 프로세스가 이미 실행 중입니다")
            assert duplicate.wait() == 1
            restored.send("/quit\r")
            assert restored.wait() == 0
            before = (directory / "history.json").read_bytes()
            wrong = launch(directory, port)
            apps.append(wrong)
            wrong.unlock("wrong-password")
            wrong.expect("비밀번호가 올바르지 않거나 기록이 손상되었습니다")
            assert wrong.wait() == 1
            assert (directory / "history.json").read_bytes() == before
            mismatch_directory = Path(temporary) / "mismatch"
            mismatch = launch(mismatch_directory, port)
            apps.append(mismatch)
            mismatch.expect("새 개인 비밀번호: ")
            mismatch.send(password + "\n")
            mismatch.expect("비밀번호 확인: ")
            mismatch.send("different-password\n")
            mismatch.expect("비밀번호 확인이 일치하지 않습니다")
            assert mismatch.wait() == 1
            assert not (mismatch_directory / "history.json").exists()
            pipe_directory = Path(temporary) / "pipe"
            piped = subprocess.run([binary, "chat", "--interface", args.interface, "--history-directory", str(pipe_directory)],
                                   input=password.encode(), capture_output=True)
            assert piped.returncode == 1
            assert "터미널에서 직접 실행하세요" in piped.stderr.decode()
            assert not (pipe_directory / "history.json").exists()
            incoming.close()
            print("PASS: 비밀번호 숨김·재인증·실제 3회 송신·중복 제거·heartbeat·비밀번호 없는 수신기의 암호화 수신함·복원·중복 실행 방지·터미널 복원")
        finally:
            for app in apps:
                app.close()
            observer.close()


if __name__ == "__main__":
    main()
