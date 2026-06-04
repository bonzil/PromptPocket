#!/usr/bin/env bash
set -euo pipefail

IDENTITY="${PROMPTPOCKET_SIGN_IDENTITY:-PromptPocket Local Code Signing}"
KEYCHAIN="${PROMPTPOCKET_SIGN_KEYCHAIN:-}"

if [[ -n "$KEYCHAIN" ]]; then
    mkdir -p "$(dirname "$KEYCHAIN")"
    if [[ ! -f "$KEYCHAIN" ]]; then
        # Empty password by design: this keychain stores only a local throwaway
        # code-signing identity. Avoid generating a secret that would have to be
        # passed through command-line arguments to Apple's security tools.
        security create-keychain -p "" "$KEYCHAIN" >/dev/null
    fi

    security unlock-keychain -p "" "$KEYCHAIN" >/dev/null
    security set-keychain-settings -lut 21600 "$KEYCHAIN" >/dev/null

    python3 - "$KEYCHAIN" <<'PY'
import subprocess
import sys
keychain = sys.argv[1]
out = subprocess.check_output(['security', 'list-keychains', '-d', 'user'], text=True)
items = [line.strip().strip('"') for line in out.splitlines() if line.strip()]
if keychain not in items:
    items.insert(0, keychain)
    subprocess.check_call(['security', 'list-keychains', '-d', 'user', '-s', *items])
PY
fi

FIND_IDENTITY_COMMAND=(security find-identity -v -p codesigning)
if [[ -n "$KEYCHAIN" ]]; then
    FIND_IDENTITY_COMMAND+=("$KEYCHAIN")
fi

if "${FIND_IDENTITY_COMMAND[@]}" 2>/dev/null | grep -Fq "\"$IDENTITY\""; then
    echo "Using existing signing identity: $IDENTITY"
    if [[ -n "$KEYCHAIN" ]]; then
        echo "Keychain: $KEYCHAIN"
    else
        echo "Keychain: default user keychains"
    fi
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OPENSSL_CONFIG="$TMP_DIR/openssl.cnf"
cat > "$OPENSSL_CONFIG" <<CONFIG
[ req ]
default_bits = 2048
prompt = no
distinguished_name = dn
x509_extensions = v3_codesign

[ dn ]
CN = $IDENTITY

[ v3_codesign ]
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, keyCertSign
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
CONFIG

openssl req \
    -new \
    -newkey rsa:2048 \
    -nodes \
    -keyout "$TMP_DIR/key.pem" \
    -x509 \
    -days 3650 \
    -out "$TMP_DIR/cert.pem" \
    -config "$OPENSSL_CONFIG" >/dev/null 2>&1

# Import the temporary unencrypted key and certificate directly instead of
# creating a PKCS#12 bundle. This avoids generated passwords in argv and avoids
# PKCS#12 empty-password compatibility issues on macOS.
IMPORT_KEY_COMMAND=(security import "$TMP_DIR/key.pem")
IMPORT_CERT_COMMAND=(security import "$TMP_DIR/cert.pem")
if [[ -n "$KEYCHAIN" ]]; then
    IMPORT_KEY_COMMAND+=(-k "$KEYCHAIN")
    IMPORT_CERT_COMMAND+=(-k "$KEYCHAIN")
fi
IMPORT_KEY_COMMAND+=(-T /usr/bin/codesign)
"${IMPORT_KEY_COMMAND[@]}" >/dev/null
"${IMPORT_CERT_COMMAND[@]}" >/dev/null

if [[ "${PROMPTPOCKET_TRUST_LOCAL_SIGNING_CERT:-0}" == "1" && -n "$KEYCHAIN" ]]; then
    security add-trusted-cert \
        -r trustRoot \
        -p codeSign \
        -k "$KEYCHAIN" \
        "$TMP_DIR/cert.pem" >/dev/null 2>&1 || true
fi

if [[ -n "$KEYCHAIN" ]]; then
    security set-key-partition-list \
        -S apple-tool:,apple:,codesign: \
        -s \
        -k "" \
        "$KEYCHAIN" >/dev/null 2>&1 || true
fi

"${FIND_IDENTITY_COMMAND[@]}"
echo "Created signing identity: $IDENTITY"
if [[ -n "$KEYCHAIN" ]]; then
    echo "Keychain: $KEYCHAIN"
else
    echo "Keychain: default user keychains"
fi
