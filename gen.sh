##################################################################################
# x509 certificates generation for MongoDB
# this script will create a CA, server and client certificates
# do not use this in production environments!
##################################################################################
## CA ##
#genCA=true to implement
CAFILE="ca_chain.pem"


## INFOS ## 
C="IT" # country code
ST="Italy" # state
L="Milan"  # lieu
O="MongoDB" # company name

dn_prefix="/C=$C/ST=$ST/L=$L/O=$O"
ou_member="MongoDB-Server" #organization unit for mongod processes
ou_client="MongoDB-Client" #organization unit for client (drivers, agents)

## LIST OF THE CLIENTS IN NEED OF A CERTIFICATE
mongodb_client_hosts=( "mongodb-node1" "mongodb-node2" "mongodb-node3" "ilians-macbook" )

## SERVER LIST FOR CERTIFICATE GENERATION
## The configuration is JSON based in order to manage subject alternative names in a dynamic way
server_hosts_conf='{
        "servers":[
            {
                "server" : "mongodb-node1",
                "DNS.1" : "mongodb-node1.station",
                "IP.1" : "192.168.1.28"
            },
            {
                "server" : "mongodb-node2",
                "DNS.1" : "mongodb-node2.station",
                "IP.1" : "192.168.1.29"
            },
            {
                "server" : "mongodb-node3",
                "DNS.1" : "mongodb-node3.station",
                "IP.1" : "192.168.1.30"
            },
            {
                "server" : "mongodb-opsmanager",
                "DNS.1" : "mongodb-opsmanager.station",
                "IP.1" : "192.168.1.26"
            }
        ]
    }'




##################################################################################
mkdir gen
cd gen

echo "######################################################################################"
echo "##### STEP 1: Generate CA "

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
CN=MONGODB-CA

EOF

# ca key
openssl genrsa -out mongodb-ca.key 4096

# cert ca gen
openssl req -new -x509 -days 1826 -key mongodb-ca.key -out mongodb-ca.crt -config mongodb-ca.cfg -subj "$dn_prefix/CN=ROOTCA"

# intermediate key
openssl genrsa -out mongodb-ia.key 4096

# certificate signing request for the intermediate certificate
openssl req -new -key mongodb-ia.key -out mongodb-ia.csr -config mongodb-ca.cfg -subj "$dn_prefix/CN=CA-SIGNER"

# Create the intermediate certificate
openssl x509 -sha256 -req -days 730 -in mongodb-ia.csr -CA mongodb-ca.crt -CAkey mongodb-ca.key -set_serial 01 -out mongodb-ia.crt -extfile mongodb-ca.cfg -extensions v3_ca

# Create the CA PEM file
cat mongodb-ca.crt mongodb-ia.crt  > $CAFILE


echo "######################################################################################"
echo "##### STEP 4: Create server certificates"

# Now create & sign keys for each mongod server 
# Pay attention to the OU part of the subject in "openssl req" command
# You may want to use FQDNs instead of short hostname
mongodb_server_hosts=( $(jq -r '.servers[].server' <<< "$server_hosts_conf") )
mongodb_server_altNamesDNS1=( $(jq -r '.servers[]."DNS.1"' <<< "$server_hosts_conf") )
mongodb_server_altNamesIP1=( $(jq -r '.servers[]."IP.1"' <<< "$server_hosts_conf") )

length=${#mongodb_server_hosts[@]}
for (( idx = 0; idx < length; idx++ )); do
    echo "######################################################################################"
	host=${mongodb_server_hosts[$idx]}
	echo "Generating certificate for server $host"
  	
	cat > "csr_details_${host}.cfg" <<-EOF
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
		CN=${host}

		[ v3_req ]
		subjectKeyIdentifier  = hash
		basicConstraints = CA:FALSE
		keyUsage = critical, digitalSignature, keyEncipherment
		nsComment = "OpenSSL Generated Certificate for TESTING only.  NOT FOR PRODUCTION USE."
		extendedKeyUsage  = serverAuth, clientAuth
		subjectAltName=@alt_names

		[ alt_names ]
		DNS.1 = ${mongodb_server_altNamesDNS1[$idx]}
		DNS.2 = ${mongodb_server_hosts[$idx]}
		IP.1 = ${mongodb_server_altNamesIP1[$idx]}
	EOF

	
    # Create the key file mongodb-test-server1.key.
    openssl genrsa -out ${host}.server.key 4096

    # Create the  certificate signing request 
    openssl req -new -key ${host}.server.key -out ${host}.server.csr -config csr_details_${host}.cfg

    # Create the server certificate 
    openssl x509 -sha256 -req -days 365 -in ${host}.server.csr -CA mongodb-ia.crt -CAkey mongodb-ia.key -CAcreateserial -out ${host}.server.crt -extfile csr_details_${host}.cfg -extensions v3_req

    # combine all together
    cat ${host}.server.crt ${host}.server.key > ${host}.server.pem
done 



echo "##### STEP 5: Create client certificates"
# Now create & sign keys for each client
# Pay attention to the OU part of the subject in "openssl req" command
for host in "${mongodb_client_hosts[@]}"; do
	echo "Generating certificate for client $host"
	# key gen
  	openssl genrsa  -out ${host}.client.key 4096
	# cert signing request
	openssl req -new -key ${host}.client.key -out ${host}.client.csr -subj "$dn_prefix/OU=$ou_client/CN=${host}" 
	# sign the cert
    openssl x509 -sha256 -req -days 365 -in ${host}.client.csr  -CA mongodb-ia.crt -CAkey mongodb-ia.key -CAcreateserial -out ${host}.client.crt

	# combine all together
	cat ${host}.client.crt ${host}.client.key > ${host}.client.pem
done 
