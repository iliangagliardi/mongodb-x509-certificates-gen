# MongoDB TLS Certificates

This repo is meant to give a series of tool that makes possible the generation of self signed certificates for on-premise versions of MongoDB. This will also generate a CA certificate, which is not meant to serve production environment. Use it only in case it's not possible to use your own CA. 


# mongodb-x509-certificates-gen

to read details of the certificate, use

`openssl x509 -text -noout -in cert.pem`

to validate client certificate using the CA-chain specified on the server 

`openssl verify -verbose -CAfile gen/ca-chain.pem -purpose sslclient gen/ilians-macbook.client.pem`

`gen/client.pem: OK`


## Certificate chain
A certificate chain is an ordered list of certificates, containing an SSL/TLS server certificate, intermediate certificate, and Certificate Authority (CA) Certificates, that enable the receiver to verify that the sender and all CA’s are trustworthy.

### Root Certificate
A root certificate is a digital certificate that belongs to the issuing Certificate Authority. It comes pre-downloaded in most browsers and is stored in what is called a “trust store.” The root certificates are closely guarded by CAs.

### Intermediate Certificate 
Intermediate certificates branch off root certificates like branches of trees. They act as middle-men between the protected root certificates and the server certificates issued out to the public. There will always be at least one intermediate certificate in a chain, but there can be more than one.

### Server/Client Certificate
The server or client certificate is the one issued to the specific domain the user is needing coverage for.


## Source
**ca**

https://docs.mongodb.com/manual/appendix/security/appendixA-openssl-ca/


**server**

https://docs.mongodb.com/manual/appendix/security/appendixB-openssl-server


**client**

https://docs.mongodb.com/manual/appendix/security/appendixC-openssl-client/


