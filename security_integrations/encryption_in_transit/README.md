# Encryption in Transit (EiT)

YugabyteDB Anywhere allows you to protect data in transit by using the following:
- Node-to-Node TLS to encrypt inter-node communication between YB-Master and YB-TServer nodes.
- Client-to-Node TLS to encrypt communication between a universe and clients. This includes applications, shells (ysqlsh, ycqlsh, psql, and so on), and other tools, using the YSQL and YCQL APIs.

Refer to the following guides:
- [EiT docs](https://docs.yugabyte.com/stable/yugabyte-platform/security/enable-encryption-in-transit/)
- Enable EiT by following [these steps](https://docs.yugabyte.com/stable/yugabyte-platform/security/enable-encryption-in-transit/#enable-encryption-in-transit)
- Rotate certs by following [these steps](https://docs.yugabyte.com/stable/yugabyte-platform/security/enable-encryption-in-transit/rotate-certificates/#rotate-certificates)
- Disable EiT by following [these steps](https://docs.yugabyte.com/stable/yugabyte-platform/security/enable-encryption-in-transit/rotate-certificates/#enable-or-disable-encryption-in-transit)