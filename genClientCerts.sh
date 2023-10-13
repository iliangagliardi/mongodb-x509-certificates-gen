##################################################################################
# x509 certificates generation for MongoDB
# this script will create a CA, server and client certificates
# do not use this in production environments!
##################################################################################
## CA ##
#genCA=true to implement
CAFILE="ca-chain.pem"
DEST="gen-client"

DAYS_CLIENT_CERTS=365

## INFOS ## 
C="IT" # country code
ST="Italy" # state
L="Milan"  # lieu
O="MongoDB" # company name

ou_member="MongoDB-Server" #organization unit for mongod processes
ou_client="MongoDB-Client" #organization unit for client (drivers, agents)

## LIST OF THE CLIENTS IN NEED OF A CERTIFICATE
mongodb_client_hosts=( "opsmanager.523b.net" "mongo1.523b.net" "mongo2.523b.net" "mongo3.523b.net" "M-MWYKVQ4VJM.523b.net" )

mkdir ${DEST}
cd ${DEST}

echo "##### Create client certificates"
# Now create & sign keys for each client
# Pay attention to the OU part of the subject in "openssl req" command
for host in "${mongodb_client_hosts[@]}"; do
	echo "Generating certificate for client $host"
	# key gen
	openssl genrsa  -out ${host}.client.key 4096
	# cert signing request
	openssl req -new -key ${host}.client.key -out ${host}.client.csr -subj "$dn_prefix/OU=$ou_client/CN=${host}" 
	# sign the cert
    openssl x509 -sha256 -req -days 365 -in ${host}.client.csr  -CA ../ca/mongodb-ia.crt -CAkey ../ca/mongodb-ia.key -CAcreateserial -out ${host}.client.crt

	# combine all together
	cat ${host}.client.crt ${host}.client.key > ${host}.client.pem
done 


