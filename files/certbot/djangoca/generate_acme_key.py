#!/usr/bin/env python3
"""
generate_acme_key.py
====================
Generates an RSA key pair for a certbot ACME account and writes the three
certbot account files into the local accounts directory.

Prints the public key PEM to stdout, which should be piped to
provision_acme_account.py to register the account in django-ca.

Requirements
------------
  pip install cryptography josepy

Usage
-----
  python generate_acme_key.py \
      --server https://ca.example.com/django_ca/acme/directory/AB:CD:EF/ \
    | django_ca provision_acme_account --ca-serial <CA_SERIAL>
"""

import argparse
import base64
import hashlib
import json
import os
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

try:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey
except ImportError:
    sys.exit("Missing dependency: pip install cryptography")

try:
    import josepy as jose
except ImportError:
    sys.exit("Missing dependency: pip install josepy")


def generate_rsa_key(key_size: int) -> RSAPrivateKey:
    return rsa.generate_private_key(
        public_exponent=65537,
        key_size=key_size,
    )


def public_key_to_pem(private_key: RSAPrivateKey) -> str:
    return private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()



def private_key_to_jwk(private_key: RSAPrivateKey) -> jose.JWKRSA:
    return jose.JWKRSA(key=private_key)


def jwk_thumbprint(jwk: jose.JWKRSA) -> str:
    pub = jwk.public_key()
    pub_numbers = pub.key.public_numbers()

    def int_to_base64url(n: int) -> str:
        length = (n.bit_length() + 7) // 8
        return base64.urlsafe_b64encode(n.to_bytes(length, "big")).rstrip(b"=").decode()

    canonical = json.dumps(
        {
            "e": int_to_base64url(pub_numbers.e),
            "kty": "RSA",
            "n": int_to_base64url(pub_numbers.n),
        },
        separators=(",", ":"),
        sort_keys=True,
    )
    digest = hashlib.sha256(canonical.encode()).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode()


def certbot_account_id(private_key: RSAPrivateKey) -> str:
    pub_der = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return hashlib.md5(pub_der).hexdigest() # NOSONAR


def private_key_to_jwk_dict(private_key: RSAPrivateKey) -> dict:
    jwk = private_key_to_jwk(private_key)
    return json.loads(jwk.json_dumps())


def build_account_uri(acme_url: str, ca_serial: str, slug: str) -> str:
    serial_no_colons = ca_serial.replace(":", "").upper()
    base = acme_url.rstrip("/")
    return f"{base}/django_ca/acme/{serial_no_colons}/acct/{slug}/"


def write_certbot_files(
    output_dir: Path,
    private_key: RSAPrivateKey,
    account_uri: str,
    email: str,
    acme_server_url: str,
    tos_url: str = "",
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)

    key_dict = private_key_to_jwk_dict(private_key)

    # private_key.json — written with 0o600 so only the owner can read it
    private_key_path = output_dir / "private_key.json"
    fd = os.open(private_key_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(json.dumps(key_dict, indent=2))

    # regr.json
    pub_jwk_dict = {k: v for k, v in key_dict.items() if k in ("e", "kty", "n")}
    regr = {
        "body": {
            "contact": [f"mailto:{email}"] if email else [],
            "key": pub_jwk_dict,
            "status": "valid",
            "termsOfServiceAgreed": True,
        },
        "uri": account_uri,
        "terms_of_service": tos_url,
    }
    (output_dir / "regr.json").write_text(json.dumps(regr, indent=2))

    # meta.json
    meta = {
        "creation_dt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "creation_host": "provisioned-offline",
        "register_to_tos": tos_url,
        "server": acme_server_url,
    }
    (output_dir / "meta.json").write_text(json.dumps(meta, indent=2))

    # public_key.pem — alongside the JSON files for reuse (e.g. re-running provision)
    (output_dir / "public_key.pem").write_text(public_key_to_pem(private_key))

    print(f"  Wrote certbot account files to: {output_dir}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description="Generate an ACME key pair and certbot account files."
    )
    parser.add_argument("--server", required=True,
                        help="ACME directory URL, e.g. "
                             "https://ca.example.com/django_ca/acme/directory/ABCDEF/ "
                             "(serial with or without colons)")
    parser.add_argument("--email", default="",
                        help="Contact email for the ACME account")
    parser.add_argument("--output-dir", default="/etc/letsencrypt/accounts",
                        help="Certbot accounts directory (default: /etc/letsencrypt/accounts)")
    parser.add_argument("--key-size", type=int, default=4096,
                        help="RSA key size (default: 4096, minimum: 2048)")
    parser.add_argument("--tos-url", default="",
                        help="URL to the CA's Terms of Service (optional)")
    args = parser.parse_args()

    if args.key_size < 2048:
        parser.error("--key-size must be at least 2048")

    # Check for an existing account under --output-dir before generating a new key.
    existing = list(Path(args.output_dir).glob("**/public_key.pem"))
    if existing:
        if len(existing) > 1:
            print(
                f"  WARNING: Multiple existing accounts found under {args.output_dir}:",
                file=sys.stderr,
            )
            for p in existing:
                print(f"    {p}", file=sys.stderr)
            print("  Using the most recently modified one.", file=sys.stderr)
            existing.sort(key=lambda p: p.stat().st_mtime, reverse=True)
        found = existing[0]
        print(f"[reuse] Existing account found: {found}", file=sys.stderr)
        print("  Skipping key generation. Printing public key to stdout.", file=sys.stderr)
        print(found.read_text().strip())
        return

    # Parse base URL and serial from --server.
    # Accepts both https://ca.example.com/django_ca/acme/directory/AB:CD:EF/
    #          and https://ca.example.com/django_ca/acme/directory/ABCDEF/
    acme_directory_url = args.server.rstrip("/") + "/"
    parsed = urlparse(acme_directory_url)
    path_parts = [p for p in parsed.path.split("/") if p]
    serial_no_colons = path_parts[-1].replace(":", "").upper()
    acme_base_url = parsed.scheme + "://" + parsed.netloc

    print("[1/3] Generating RSA key pair...", file=sys.stderr)
    private_key = generate_rsa_key(args.key_size)
    jwk = private_key_to_jwk(private_key)
    thumbprint = jwk_thumbprint(jwk)
    slug = thumbprint[:22]
    account_id = certbot_account_id(private_key)
    public_pem = public_key_to_pem(private_key).strip()

    print(f"  Thumbprint : {thumbprint}", file=sys.stderr)
    print(f"  Slug       : {slug}", file=sys.stderr)
    print(f"  Account ID : {account_id}", file=sys.stderr)

    print("[2/3] Writing certbot account files...", file=sys.stderr)
    account_uri = build_account_uri(acme_base_url, serial_no_colons, slug)

    server_dir = parsed.netloc + parsed.path.rstrip("/")
    output_dir = Path(args.output_dir) / server_dir / account_id

    write_certbot_files(
        output_dir=output_dir,
        private_key=private_key,
        account_uri=account_uri,
        email=args.email,
        acme_server_url=acme_directory_url,
        tos_url=args.tos_url,
    )

    # Stable symlink at the root of --output-dir for Puppet and reuse
    symlink = Path(args.output_dir) / "public_key.pem"
    if symlink.is_symlink():
        symlink.unlink()
    symlink.symlink_to(output_dir / "public_key.pem")
    print(f"  Symlink: {symlink} -> {output_dir / 'public_key.pem'}", file=sys.stderr)

    print("[3/3] Public key PEM written to stdout for provision_acme_account.py.", file=sys.stderr)
    print(public_pem)


if __name__ == "__main__":
    main()
