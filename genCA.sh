##################################################################################
# x509 certificates generation for MongoDB
# this script will create a CA, server and client certificates
# do not use this in production environments!
##################################################################################
## CA ##
#genCA=true to implement
CAFILE="ca-chain.pem"
CA_NAME="ILIANS-ROOT-CA"
DEST="ca2"
DAYS_ROOT_CA=1826
DAYS_INTERMEDIATE_CA=730
DAYS_SERVER_CERTS=365
DAYS_CLIENT_CERTS=365

## INFOS ## 
C="IT" # country code
ST="Italy" # state
L="Milan"  # lieu
O="MongoDB" # company name

dn_prefix="/C=$C/ST=$ST/L=$L/O=$O"



##################################################################################
mkdir ${DEST}
cd ${DEST}

echo "######################################################################################"
echo "##### STEP 1: Generate ROOT CA & INTERMEDIATE CA "

# Generate CA config
cat >> mongodb-ca.cfg <<EOF
[ policy_match ]
countryName = match
stateOrProvinceName = match
organizationName = match
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[ req ]
default_bits = 4096
default_keyfile = myTestCertificateKey.pem    ## The default private key file name.
default_md = sha256                           ## Use SHA-256 for Signatures
req_extensions = v3_req
x509_extensions = v3_ca # The extentions to add to the self signed cert
distinguished_name = req_dn

[ v3_req ]
subjectKeyIdentifier  = hash
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
nsComment = "OpenSSL Generated Certificate for TESTING only.  NOT FOR PRODUCTION USE."
extendedKeyUsage  = serverAuth, clientAuth

[ v3_ca ]
subjectKeyIdentifier=hash
basicConstraints = critical,CA:true
authorityKeyIdentifier=keyid:always,issuer:always

[ req_dn ] 
C=${C}
ST=${ST}
L=${L}
O=${O}
OU=MONGODB-CA
EOF

# ca key
openssl genrsa -out mongodb-ca.key 4096

# cert ca gen
openssl req -new -x509 -days $DAYS_ROOT_CA -key mongodb-ca.key -out mongodb-ca.crt -config mongodb-ca.cfg -subj "$dn_prefix/CN=$CA_NAME"

# intermediate key
openssl genrsa -out mongodb-ia.key 4096

# certificate signing request for the intermediate certificate
openssl req -new -key mongodb-ia.key -out mongodb-ia.csr -config mongodb-ca.cfg -subj "$dn_prefix/CN=INTERMEDIATE-CA"

# Create the intermediate certificate
openssl x509 -sha256 -req -days $DAYS_INTERMEDIATE_CA -in mongodb-ia.csr -CA mongodb-ca.crt -CAkey mongodb-ca.key -set_serial 01 -out mongodb-ia.crt -extfile mongodb-ca.cfg -extensions v3_ca

# Create the CA PEM file
cat mongodb-ca.crt mongodb-ia.crt  > $CAFILE


