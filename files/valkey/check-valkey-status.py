#!/usr/bin/env python3
# pylint: disable=line-too-long
# pylint:disable=invalid-name
# pylint:enable=invalid-name
"""
check_valkey.py - Nagios/NRPE health check for Valkey cluster nodes on local VM.

Checks all Valkey nodes running on the local VM and returns a Nagios-compatible
exit code and status message.

Exit codes:
  0 - OK
  1 - WARNING
  2 - CRITICAL
  3 - UNKNOWN

Usage:
  check_valkey.py [--ports 6379 6380 6381] [--host 127.0.0.1]
                  [--cert /opt/valkey/cert/cert.pem]
                  [--key /opt/valkey/cert/privkey.pem]
                  [--ca /etc/ssl/certs/infra-2-prod.crt]
                  [--eyaml-file /etc/hiera/data/local.eyaml]
                  [--eyaml-private-key /etc/hiera/eyaml/private_key.pkcs7.pem]
                  [--eyaml-public-key /etc/hiera/eyaml/public_certkey.pkcs7.pem]
                  [--eyaml-password-key valkey_password]
                  [--timeout 5]

NRPE command definition example (/etc/nrpe.d/valkey.cfg):
  command[check_valkey]=/usr/bin/python3 /usr/lib/nagios/plugins/check_valkey.py \
    --eyaml-file /etc/hiera/data/local.eyaml \
    --eyaml-private-key /etc/hiera/eyaml/private_key.pkcs7.pem \
    --eyaml-public-key /etc/hiera/eyaml/public_certkey.pkcs7.pem \
    --cert /opt/valkey/cert/cert.pem \
    --key /opt/valkey/cert/privkey.pem \
    --ca /etc/ssl/certs/infra-2-test.crt
"""

import argparse
import os
import shutil
import socket
import ssl
import subprocess
import sys
from dataclasses import dataclass, field
from enum import IntEnum


class NagiosState(IntEnum):
    OK = 0
    WARNING = 1
    CRITICAL = 2
    UNKNOWN = 3


def get_password_from_eyaml(
    eyaml_file: str,
    private_key: str,
    public_key: str,
    password_key: str = "valkey_password",
) -> str:
    """Decrypt and extract a password from an eyaml file using the eyaml CLI."""
    eyaml_bin = shutil.which("eyaml")
    if not eyaml_bin:
        print("VALKEY UNKNOWN - eyaml binary not found in PATH")
        sys.exit(int(NagiosState.UNKNOWN))

    try:
        proc = subprocess.run(
            [
                eyaml_bin,
                "decrypt",
                "-f",
                eyaml_file,
                f"--pkcs7-private-key={private_key}",
                f"--pkcs7-public-key={public_key}",
            ],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except subprocess.TimeoutExpired:
        print("VALKEY UNKNOWN - eyaml decrypt timed out")
        sys.exit(int(NagiosState.UNKNOWN))

    if proc.returncode != 0:
        print(f"VALKEY UNKNOWN - eyaml decrypt failed: {proc.stderr.strip()}")
        sys.exit(int(NagiosState.UNKNOWN))

    for line in proc.stdout.splitlines():
        if line.startswith(f"{password_key}:"):
            parts = line.split(":", 1)
            if len(parts) == 2:
                return parts[1].strip()

    print(f"VALKEY UNKNOWN - key '{password_key}' not found in eyaml output")
    sys.exit(int(NagiosState.UNKNOWN))


@dataclass
class NodeResult:
    port: int
    state: NagiosState = NagiosState.UNKNOWN
    role: str = "unknown"
    cluster_state: str = "unknown"
    connected_replicas: int = 0
    issues: list[str] = field(default_factory=list)
    commandlog_slow: int = -1
    memory_used: int = -1
    memory_max: int = -1
    memory_pct: float = -1.0


class ValkeyClient:
    """Minimal Valkey client using raw RESP protocol over TLS."""

    def __init__(
        self,
        host: str,
        port: int,
        password: str | None,
        certfile: str | None,
        keyfile: str | None,
        cafile: str | None,
        timeout: float = 5.0,
    ):
        self.host = host
        self.port = port
        self.password = password
        self.certfile = certfile
        self.keyfile = keyfile
        self.cafile = cafile
        self.timeout = timeout
        self._sock = None

    def connect(self):
        raw = socket.create_connection((self.host, self.port), timeout=self.timeout)
        if self.certfile and self.keyfile:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            ctx.minimum_version = ssl.TLSVersion.TLSv1_2
            ctx.load_cert_chain(certfile=self.certfile, keyfile=self.keyfile)
            if self.cafile:
                ctx.load_verify_locations(cafile=self.cafile)
            else:
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
            self._sock = ctx.wrap_socket(raw, server_hostname=self.host)
        else:
            self._sock = raw

        if self.password:
            self._command("AUTH", self.password)

    def _encode(self, *args: str) -> bytes:
        parts = [f"*{len(args)}\r\n".encode()]
        for arg in args:
            encoded = arg.encode()
            parts.append(f"${len(encoded)}\r\n".encode())
            parts.append(encoded)
            parts.append(b"\r\n")
        return b"".join(parts)

    def _read_line(self) -> str:
        buf = b""
        while not buf.endswith(b"\r\n"):
            chunk = self._sock.recv(1)
            if not chunk:
                raise ConnectionError("Connection closed unexpectedly")
            buf += chunk
        return buf[:-2].decode()

    def _read_response(self):
        line = self._read_line()
        prefix, data = line[0], line[1:]

        if prefix == "+":
            return data
        elif prefix == "-":
            raise RuntimeError(f"Valkey error: {data}")
        elif prefix == ":":
            return int(data)
        elif prefix == "$":
            length = int(data)
            if length == -1:
                return None
            payload = b""
            while len(payload) < length + 2:
                payload += self._sock.recv(length + 2 - len(payload))
            return payload[:-2].decode()
        elif prefix == "*":
            count = int(data)
            if count == -1:
                return None
            return [self._read_response() for _ in range(count)]
        else:
            raise ValueError(f"Unknown RESP prefix: {prefix!r}")

    def _command(self, *args: str):
        self._sock.sendall(self._encode(*args))
        return self._read_response()

    def ping(self) -> bool:
        return self._command("PING") == "PONG"

    def info(self, section: str = "all") -> dict[str, str]:
        raw = self._command("INFO", section)
        result = {}
        for line in raw.splitlines():
            if ":" in line and not line.startswith("#"):
                key, _, value = line.partition(":")
                result[key.strip()] = value.strip()
        return result

    def commandlog_len(self, log_type: str = "SLOW") -> int:
        return self._command("COMMANDLOG", "LEN", log_type)

    def cluster_info(self) -> dict[str, str]:
        raw = self._command("CLUSTER", "INFO")
        result = {}
        for line in raw.splitlines():
            if ":" in line:
                key, _, value = line.partition(":")
                result[key.strip()] = value.strip()
        return result

    def close(self):
        if self._sock:
            try:
                self._sock.close()
            except Exception:
                pass


def _fmt_bytes(b: int) -> str:
    """Format bytes as a human-readable string."""
    for unit in ("B", "KB", "MB", "GB"):
        if b < 1024:
            return f"{b:.1f}{unit}"
        b //= 1024
    return f"{b:.1f}TB"


def check_node(
    host: str,
    port: int,
    password: str | None,
    certfile: str | None,
    keyfile: str | None,
    cafile: str | None,
    timeout: float,
) -> NodeResult:
    result = NodeResult(port=port)
    client = ValkeyClient(host, port, password, certfile, keyfile, cafile, timeout)

    try:
        client.connect()

        if not client.ping():
            result.state = NagiosState.CRITICAL
            result.issues.append("PING failed")
            return result

        # Replication / role info
        info = client.info("replication")
        result.role = info.get("role", "unknown")
        result.connected_replicas = int(info.get("connected_slaves", 0))

        if result.role == "master" and result.connected_replicas == 0:
            result.issues.append("master has no connected replicas")
            result.state = NagiosState.WARNING

        # Cluster info
        cinfo = client.cluster_info()
        result.cluster_state = cinfo.get("cluster_state", "unknown")

        if result.cluster_state != "ok":
            result.issues.append(f"cluster_state={result.cluster_state}")
            result.state = NagiosState.CRITICAL

        slots_fail = int(cinfo.get("cluster_slots_fail", 0))
        if slots_fail > 0:
            result.issues.append(f"{slots_fail} slot(s) in FAIL state")
            result.state = NagiosState.CRITICAL

        nodes_fail = int(cinfo.get("cluster_nodes_fail", 0))
        if nodes_fail > 0:
            result.issues.append(f"{nodes_fail} cluster node(s) in FAIL state")
            # Only escalate to CRITICAL if not already set
            if result.state < NagiosState.CRITICAL:
                result.state = NagiosState.WARNING

        # Commandlog slow entries
        try:
            result.commandlog_slow = client.commandlog_len("SLOW")
            if result.commandlog_slow > 0:
                result.issues.append(
                    f"{result.commandlog_slow} slow command log entries"
                )
                result.state = max(result.state, NagiosState.WARNING)
        except Exception:
            # Older Valkey without COMMANDLOG support — not a failure
            result.commandlog_slow = -1

        # Memory usage relative to maxmemory
        minfo = client.info("memory")
        memory_used = int(minfo.get("used_memory", 0))
        memory_max = int(minfo.get("maxmemory", 0))
        if memory_max > 0:
            memory_pct = (memory_used / memory_max) * 100
            result.memory_used = memory_used
            result.memory_max = memory_max
            result.memory_pct = round(memory_pct, 1)
            if memory_used > memory_max:
                result.issues.append(
                    f"memory CRITICAL: {result.memory_pct}% of maxmemory "
                    f"({_fmt_bytes(memory_used)}/{_fmt_bytes(memory_max)})"
                )
                result.state = NagiosState.CRITICAL
            elif memory_pct >= 80:
                result.issues.append(
                    f"memory WARNING: {result.memory_pct}% of maxmemory "
                    f"({_fmt_bytes(memory_used)}/{_fmt_bytes(memory_max)})"
                )
                result.state = max(result.state, NagiosState.WARNING)

        if result.state == NagiosState.UNKNOWN:
            result.state = NagiosState.OK

    except ConnectionRefusedError:
        result.state = NagiosState.CRITICAL
        result.issues.append("connection refused")
    except TimeoutError:
        result.state = NagiosState.CRITICAL
        result.issues.append(f"connection timed out after {timeout}s")
    except ssl.SSLError as e:
        result.state = NagiosState.CRITICAL
        result.issues.append(f"TLS error: {e.reason}")
    except RuntimeError as e:
        result.state = NagiosState.CRITICAL
        result.issues.append(str(e))
    except Exception as e:
        result.state = NagiosState.UNKNOWN
        result.issues.append(f"unexpected error: {type(e).__name__}: {e}")
    finally:
        client.close()

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Nagios/NRPE health check for Valkey cluster nodes"
    )
    parser.add_argument(
        "--host",
        default=socket.getfqdn(),
        help="Valkey host (default: system FQDN via socket.getfqdn())",
    )
    parser.add_argument(
        "--ports",
        nargs="+",
        type=int,
        default=[6379, 6380, 6381],
        help="TLS ports to check (default: 6379 6380 6381)",
    )
    parser.add_argument(
        "--cert",
        default="/opt/valkey/cert/cert.pem",
        help="Path to TLS client certificate (default: /opt/valkey/cert/cert.pem)",
    )
    parser.add_argument(
        "--key",
        default="/opt/valkey/cert/privkey.pem",
        help="Path to TLS client key (default: /opt/valkey/cert/privkey.pem)",
    )
    parser.add_argument(
        "--ca",
        default="/etc/ssl/certs/infra-2-prod.crt",
        help="Path to CA certificate (default: /etc/ssl/certs/infra-2-prod.crt)",
    )
    parser.add_argument(
        "--eyaml-file",
        default="/etc/hiera/data/local.eyaml",
        help="Path to eyaml file (default: /etc/hiera/data/local.eyaml)",
    )
    parser.add_argument(
        "--eyaml-private-key",
        default="/etc/hiera/eyaml/private_key.pkcs7.pem",
        help="Path to eyaml PKCS7 private key",
    )
    parser.add_argument(
        "--eyaml-public-key",
        default="/etc/hiera/eyaml/public_certkey.pkcs7.pem",
        help="Path to eyaml PKCS7 public key",
    )
    parser.add_argument(
        "--eyaml-password-key",
        default="valkey_password",
        help="Key name in eyaml file to extract (default: valkey_password)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="Connection timeout in seconds (default: 5)",
    )
    args = parser.parse_args()

    # Validate all file paths up front for clear error messages
    missing = []
    for label, path in [
        ("--cert", args.cert),
        ("--key", args.key),
        ("--ca", args.ca),
        ("--eyaml-file", args.eyaml_file),
        ("--eyaml-private-key", args.eyaml_private_key),
        ("--eyaml-public-key", args.eyaml_public_key),
    ]:
        if path and not os.path.isfile(path):
            missing.append(f"{label}: {path}")

    if missing:
        print("VALKEY UNKNOWN - missing files:\n  " + "\n  ".join(missing))
        sys.exit(int(NagiosState.UNKNOWN))

    password = get_password_from_eyaml(
        eyaml_file=args.eyaml_file,
        private_key=args.eyaml_private_key,
        public_key=args.eyaml_public_key,
        password_key=args.eyaml_password_key,
    )

    results: list[NodeResult] = []
    for port in args.ports:
        r = check_node(
            host=args.host,
            port=port,
            password=password,
            certfile=args.cert,
            keyfile=args.key,
            cafile=args.ca,
            timeout=args.timeout,
        )
        results.append(r)

    # Overall state is the worst of all nodes
    overall = max(r.state for r in results)

    # Build output message
    state_label = {
        NagiosState.OK: "OK",
        NagiosState.WARNING: "WARNING",
        NagiosState.CRITICAL: "CRITICAL",
        NagiosState.UNKNOWN: "UNKNOWN",
    }[overall]

    summaries = []
    for r in results:
        slow = f", slow_cmds={r.commandlog_slow}" if r.commandlog_slow >= 0 else ""
        mem = f", mem={r.memory_pct}%" if r.memory_pct >= 0 else ""
        summary = f":{r.port}[{r.role},{r.cluster_state}{slow}{mem}]"
        if r.issues:
            summary += f"({'; '.join(r.issues)})"
        summaries.append(summary)

    print(f"VALKEY {state_label} -", ", ".join(summaries))

    # Performance data
    perf_parts = []
    for r in results:
        if r.commandlog_slow >= 0:
            perf_parts.append(f"slow_{r.port}={max(r.commandlog_slow, 0)}")
        if r.memory_pct >= 0:
            perf_parts.append(f"mem_pct_{r.port}={r.memory_pct}%;80;100")
    if perf_parts:
        print(f"|{' '.join(perf_parts)}")

    sys.exit(int(overall))


if __name__ == "__main__":
    main()
