#!/bin/bash
: ${1?'missing CN'}
cn="$1"

secret_dir="helm/ssl"
expiration="3650"
mkdir -p helm/ssl

chmod 0700 "$secret_dir"
cd "$secret_dir"

rm -rf *

cat <<END > san.cnf
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
[ req_distinguished_name ]
countryName                 = Country Name (2 letter code)
stateOrProvinceName         = State or Province Name (full name)
localityName               = Locality Name (eg, city)
organizationName           = Organization Name (eg, company)
commonName                 = Common Name (e.g. server FQDN or YOUR name)
[ req_ext ]
subjectAltName = @alt_names
[alt_names]
DNS.1   = ${cn}
END

cat <<END > v3.ext
subjectAltName         = DNS:${cn}
issuerAltName          = issuer:copy
END
# Generate the CA cert and private key
openssl req -nodes -new -x509 -days $expiration -keyout ca.key -out ca.crt -subj "/CN=Admission Controller Webhook Server CA"

cat ca.key > server.pem
cat ca.crt >> server.pem

# Generate the private key for the webhook server
openssl genrsa -out tls.key 2048
# Generate a Certificate Signing Request (CSR) for the private key, and sign it with the private key of the CA.
openssl req -new -key tls.key -subj "/CN=$cn" -config san.cnf \
    | openssl x509 -days "${expiration}" -extfile v3.ext -req -CA ca.crt -CAkey ca.key -CAcreateserial -out tls.crt
