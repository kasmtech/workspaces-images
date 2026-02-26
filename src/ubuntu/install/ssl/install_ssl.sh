#!/usr/bin/env bash
set -ex

# ============================================================================
# Coeadapt Workspace SSL Certificate Generator
# Generates a local CA + server certificate at Docker build time so
# KasmVNC serves HTTPS that browsers trust (after CA installation on host).
#
# Replaces the default self-signed "snakeoil" certs with a proper
# CA-signed certificate for localhost / 127.0.0.1.
# ============================================================================

SSL_DIR="/etc/ssl/coeadapt"
CA_DIR="${SSL_DIR}/ca"
CERT_DIR="${SSL_DIR}/server"
EXPORT_DIR="/usr/share/coeadapt"

mkdir -p "${CA_DIR}" "${CERT_DIR}" "${EXPORT_DIR}"

# --- Generate Certificate Authority (10-year validity) ---
openssl genrsa -out "${CA_DIR}/ca.key" 2048

openssl req -x509 -new -nodes \
  -key "${CA_DIR}/ca.key" \
  -sha256 -days 3650 \
  -out "${CA_DIR}/ca.crt" \
  -subj "/C=US/ST=Local/L=Localhost/O=Coeadapt/OU=Workspace/CN=Coeadapt Workspace CA"

# --- Generate Server Certificate signed by the CA (5-year validity) ---
openssl genrsa -out "${CERT_DIR}/server.key" 2048

openssl req -new \
  -key "${CERT_DIR}/server.key" \
  -out "${CERT_DIR}/server.csr" \
  -subj "/C=US/ST=Local/L=Localhost/O=Coeadapt/OU=Workspace/CN=localhost"

# SAN extension — browsers require Subject Alternative Names
cat > "${CERT_DIR}/server.ext" << 'EXTEOF'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EXTEOF

openssl x509 -req \
  -in "${CERT_DIR}/server.csr" \
  -CA "${CA_DIR}/ca.crt" \
  -CAkey "${CA_DIR}/ca.key" \
  -CAcreateserial \
  -out "${CERT_DIR}/server.crt" \
  -days 1825 \
  -sha256 \
  -extfile "${CERT_DIR}/server.ext"

# --- Replace KasmVNC default snakeoil certs ---
cp "${CERT_DIR}/server.crt" /etc/ssl/certs/ssl-cert-snakeoil.pem
cp "${CERT_DIR}/server.key" /etc/ssl/private/ssl-cert-snakeoil.key
chmod 644 /etc/ssl/certs/ssl-cert-snakeoil.pem
chmod 640 /etc/ssl/private/ssl-cert-snakeoil.key

# --- Export CA cert for host trust-store installation ---
cp "${CA_DIR}/ca.crt" "${EXPORT_DIR}/ca.crt"
chmod 644 "${EXPORT_DIR}/ca.crt"

# --- Cleanup intermediate files ---
rm -f "${CERT_DIR}/server.csr" "${CERT_DIR}/server.ext" "${CA_DIR}/ca.srl"

echo "=== Coeadapt SSL setup complete ==="
echo "  CA cert (export to host): ${EXPORT_DIR}/ca.crt"
echo "  Server cert: /etc/ssl/certs/ssl-cert-snakeoil.pem"
echo "  Server key:  /etc/ssl/private/ssl-cert-snakeoil.key"
