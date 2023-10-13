##################################################################################
# x509 certificates generation for MongoDB
# this script will create a CA, server and client certificates
# do not use this in production environments!
##################################################################################
## CA ##
#genCA=true to implement
CAFILE="ca-chain.pem"
DEST="gen-kms"

DAYS_SERVER_CERTS=365
DAYS_CLIENT_CERTS=365


## INFOS ## 
C="IT" # country code
ST="Italy" # state
L="Milan"  # lieu
O="MongoDB" # company name

ou_member="MongoDB-Server" #organization unit for mongod processes
ou_client="MongoDB-Client" #organization unit for client (drivers, agents)

## LIST OF THE CLIENTS IN NEED OF A CERTIFICATE
# mongodb_client_hosts=( "mongodb-node1" "mongodb-node2" "mongodb-node3" "ilians-macbook" )

## SERVER LIST FOR CERTIFICATE GENERATION
## The configuration is JSON based in order to manage subject alternative names in a dynamic way, modify it accordingly to your needs
server_hosts_conf='{
        "servers":[
            {
                "server" : "kms",
                "DNS.1" : "kms.523b.net"
            }
        ]
    }'



##################################################################################
mkdir ${DEST}
cd ${DEST}



echo "######################################################################################"
echo "##### STEP 2: Create server certificates"

# Now create & sign keys for each mongod server 
# Pay attention to the OU part of the subject in "openssl req" command
# You may want to use FQDNs instead of short hostname
mongodb_server_hosts=( $(jq -r '.servers[].server' <<< "$server_hosts_conf") )
mongodb_server_altNamesDNS1=( $(jq -r '.servers[]."DNS.1"' <<< "$server_hosts_conf") )

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
	EOF

	
    # Create the key file mongodb-test-server1.key.
    openssl genrsa -out ${host}.server.key 4096

    # Create the  certificate signing request 
    openssl req -new -key ${host}.server.key -out ${host}.server.csr -config csr_details_${host}.cfg

    # Create the server certificate 
    openssl x509 -sha256 -req -days 365 -in ${host}.server.csr -CA ../ca/mongodb-ia.crt -CAkey ../ca/mongodb-ia.key -CAcreateserial -out ${host}.server.crt -extfile csr_details_${host}.cfg -extensions v3_req

    # combine all together
    cat ${host}.server.crt ${host}.server.key > ${host}.server.pem
done  
