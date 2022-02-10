##################################################################################
# x509 certificates generation for MongoDB
# this script will create a CA, server and client certs
##################################################################################

## LIST OF SERVER AND CLIENTS FOR CERTIFICATE GENERATION
mongodb_server_hosts=( "mongodb-node1" "mongodb-node2" "mongodb-node3" )
mongodb_client_hosts=( "mongodb-node1" "mongodb-node2" "mongodb-node3", "ilians-macbook" )

## VARIABLES ## 
rootCAName="ca.pem"

admin_email="ilian.gagliardi@mongodb.com"
C="IT" # country code
ST="Italy" # state
L="Milan"  # lieu
O="MongoDB" # company name

dn_prefix="/C=$C/ST=$ST/L=$L/O=$O"
ou_member="MongoDB-Server" #organization unit server
ou_client="MongoDB-Client" #organization unit client


##################################################################################

mkdir gen && cd gen

echo "######################################################################################"
echo "##### STEP 1: Generate root CA "
openssl genrsa -out root-ca.key 2048
# !!! In production you will want to use -aes256 to password protect the keys
# openssl genrsa -aes256 -out root-ca.key 2048

openssl req -new -x509 -days 3650 -key root-ca.key -out root-ca.crt -subj "$dn_prefix/CN=ROOTCA"

mkdir -p RootCA/ca.db.certs
echo "01" >> RootCA/ca.db.serial
touch RootCA/ca.db.index
echo $RANDOM >> RootCA/ca.db.rand
mv root-ca* RootCA/

echo "######################################################################################"
echo "##### STEP 2: Create CA config"
# Generate CA config
cat >> root-ca.cfg <<EOF
[ RootCA ]
dir             = ./RootCA
certs           = \$dir/ca.db.certs
database        = \$dir/ca.db.index
new_certs_dir   = \$dir/ca.db.certs
certificate     = \$dir/root-ca.crt
serial          = \$dir/ca.db.serial
private_key     = \$dir/root-ca.key
RANDFILE        = \$dir/ca.db.rand
default_md      = sha256
default_days    = 365
default_crl_days= 30
email_in_dn     = no
unique_subject  = no
policy          = policy_match

[ SigningCA ]
dir             = ./SigningCA
certs           = \$dir/ca.db.certs
database        = \$dir/ca.db.index
new_certs_dir   = \$dir/ca.db.certs
certificate     = \$dir/signing-ca.crt
serial          = \$dir/ca.db.serial
private_key     = \$dir/signing-ca.key
RANDFILE        = \$dir/ca.db.rand
default_md      = sha256
default_days    = 365
default_crl_days= 30
email_in_dn     = no
unique_subject  = no
policy          = policy_match
 
[ policy_match ]
countryName     = match
stateOrProvinceName = match
localityName            = match
organizationName    = match
organizationalUnitName  = optional
commonName      = supplied
emailAddress        = optional

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment

[ v3_ca ]
basicConstraints = CA:true
EOF
echo "######################################################################################"
echo "##### STEP 3: Generate signing key"
# We do not use root key to sign certificate, instead we generate a signing key
openssl genrsa -out signing-ca.key 2048
# !!! In production you will want to use -aes256 to password protect the keys
# openssl genrsa -aes256 -out signing-ca.key 2048

openssl req -new -days 365 -key signing-ca.key -out signing-ca.csr -subj "$dn_prefix/CN=CA-SIGNER"
openssl ca -batch -name RootCA -config root-ca.cfg -extensions v3_ca -out signing-ca.crt -infiles signing-ca.csr 

mkdir -p SigningCA/ca.db.certs
echo "01" >> SigningCA/ca.db.serial
touch SigningCA/ca.db.index
# Should use a better source of random here..
echo $RANDOM >> SigningCA/ca.db.rand
mv signing-ca* SigningCA/

# Create ca.pem
cat RootCA/root-ca.crt SigningCA/signing-ca.crt > $rootCAName

echo "######################################################################################"
echo "##### STEP 4: Create server certificates"
# Now create & sign keys for each mongod server 
# Pay attention to the OU part of the subject in "openssl req" command
# You may want to use FQDNs instead of short hostname
for host in "${mongodb_server_hosts[@]}"; do
    echo "######################################################################################"
	echo "Generating certificate for server $host"
  	
	cat > "csr_details_${host}.cfg" <<-EOF
		[req]
		default_bits = 2048
		prompt = no
		default_md = sha256
		req_extensions = req_ext
		distinguished_name = dn

		[ dn ] 
		C=${C}
		ST=${ST}
		L=${L}
		O=${O}
		OU=${ou_member}
		emailAddress=${admin_email}
		CN=${host}

		[ req_ext ]
		extendedKeyUsage=serverAuth, clientAuth
		subjectAltName=@alt_names

		[ alt_names ]
		DNS.1 = ${host}.station
		DNS.2 = ${host}
	EOF
	
    # Create the test key file mongodb-test-server1.key.
    openssl genrsa -out ${host}.server.key 2048

    # Create the  certificate signing request 
    openssl req -new -key ${host}.server.key -out ${host}.server.csr -config csr_details_${host}.cfg

    # Create the server certificate 
    openssl x509 -sha256 -req -days 365 -in ${host}.server.csr  -CA ./SigningCA/signing-ca.crt -CAkey ./SigningCA/signing-ca.key -CAcreateserial -out ${host}.server.crt -extfile csr_details_${host}.cfg -extensions req_ext

    # combine all together
    cat ${host}.server.crt ${host}.server.key > ${host}.server.pem
done 



# echo "##### STEP 5: Create client certificates"
# # Now create & sign keys for each client
# # Pay attention to the OU part of the subject in "openssl req" command
for host in "${mongodb_client_hosts[@]}"; do
	echo "Generating certificate for client $host"
	# key gen
  	openssl genrsa  -out ${host}.client.key 2048
	# cert signing request
	openssl req -new -key ${host}.client.key -out ${host}.client.csr -subj "$dn_prefix/OU=$ou_client/CN=${host}" 
	# sign the cert
    openssl x509 -sha256 -req -days 365 -in ${host}.client.csr  -CA ./SigningCA/signing-ca.crt -CAkey ./SigningCA/signing-ca.key -CAcreateserial -out ${host}.client.crt

	# combine all together
	cat ${host}.client.crt ${host}.client.key > ${host}.client.pem
done 
