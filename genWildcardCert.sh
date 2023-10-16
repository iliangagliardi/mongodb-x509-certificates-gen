##################################################################################
# x509 certificates generation for MongoDB
# this script will create a 
# do not use this in production environments!
##################################################################################
CAFILE="ca-chain.pem"
DEST="wildcardCerts"
CERTIFICATE_FILENAME="wildcard_server"
WILDCARD_DOMAIN="*.523b.net"
DAYS_SERVER_CERTS=365
DAYS_CLIENT_CERTS=365

## INFOS ## 
C="IT" # country code
ST="Italy" # state
L="Milan"  # lieu
O="MongoDB" # company name

ou_member="MongoDB-Server" #organization unit for mongod processes

##################################################################################
mkdir ${DEST}
cd ${DEST}

echo "######################################################################################"
echo "##### STEP 2: Create server certificates"
# Now create & sign keys for each mongod server 
# Pay attention to the OU part of the subject in "openssl req" command
# You may want to use FQDNs instead of short hostname

echo "######################################################################################"
echo "Generating wildcard certificate"
cat > "csr_details_wildcard.cfg" <<-EOF
    [req]
    default_bits = 2048
    prompt = no
    default_md = sha256
    distinguished_name = req_dn
    req_extensions = v3_req

    [ req_dn ] 
    C=${C}
    ST=${ST}
    L=${L}
    O=${O}
    OU=${ou_member}
    CN=${WILDCARD_DOMAIN}

    [ v3_req ]
    subjectKeyIdentifier  = hash
    basicConstraints = CA:FALSE
    keyUsage = critical, digitalSignature, keyEncipherment
    nsComment = "OpenSSL Generated Certificate for TESTING only.  NOT FOR PRODUCTION USE."
    extendedKeyUsage  = serverAuth, clientAuth
    subjectAltName=@alt_names

    [ alt_names ]
    DNS.1 = ${WILDCARD_DOMAIN}
EOF

# Create the key file mongodb-test-server1.key.
openssl genrsa -out ${CERTIFICATE_FILENAME}.key 4096

# Create the  certificate signing request 
openssl req -new -key ${CERTIFICATE_FILENAME}.key -out ${CERTIFICATE_FILENAME}.csr -config csr_details_wildcard.cfg

# Create the server certificate 
openssl x509 -sha256 -req -days 365 -in ${CERTIFICATE_FILENAME}.csr -CA ../ca/mongodb-ia.crt -CAkey ../ca/mongodb-ia.key -CAcreateserial -out ${CERTIFICATE_FILENAME}.crt -extfile csr_details_wildcard.cfg -extensions v3_req

# combine all together
cat ${CERTIFICATE_FILENAME}.crt ${CERTIFICATE_FILENAME}.key > ${CERTIFICATE_FILENAME}.pem