# mongodb-x509-certificates-gen

to read details of the certificate, use

`openssl x509 -text -noout -in cert.pem`

to validate client certificate using the CA-chain specified on the server 

`openssl verify -verbose -CAfile ca_chain.pem -purpose sslclient client.pem`
`gen/client.pem: OK`


## Certificate chain
A certificate chain is an ordered list of certificates, containing an SSL/TLS server certificate, intermediate certificate, and Certificate Authority (CA) Certificates, that enable the receiver to verify that the sender and all CA’s are trustworthy.

### Root Certificate. 
A root certificate is a digital certificate that belongs to the issuing Certificate Authority. It comes pre-downloaded in most browsers and is stored in what is called a “trust store.” The root certificates are closely guarded by CAs.

### Intermediate Certificate. 
Intermediate certificates branch off root certificates like branches of trees. They act as middle-men between the protected root certificates and the server certificates issued out to the public. There will always be at least one intermediate certificate in a chain, but there can be more than one.

### Server/Client Certificate. 
The server certificate is the one issued to the specific domain the user is needing coverage for.


## Source
**ca**

https://docs.mongodb.com/manual/appendix/security/appendixA-openssl-ca/


**server**

https://docs.mongodb.com/manual/appendix/security/appendixB-openssl-server


**client**

https://docs.mongodb.com/manual/appendix/security/appendixC-openssl-client/


