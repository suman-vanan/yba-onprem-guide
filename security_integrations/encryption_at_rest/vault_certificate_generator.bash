#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

CONFIG_FILE="vault-cert.cnf"

# Check if the configuration file exists before starting
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Configuration file '$CONFIG_FILE' not found in the current directory!"
    echo "Please create '$CONFIG_FILE' with the necessary SANs (IPs/DNS) before running this script."
    exit 1
fi

echo "🚀 Starting Vault Certificate Generation..."
echo "=================================================="

# Step 2: Create Your Own Root CA
echo -e "\n⏳ [Step 2] Creating Root CA (rootCA.key, rootCA.crt)..."
openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout rootCA.key -out rootCA.crt -days 3650 \
  -subj "/CN=My-Internal-Vault-Root-CA" \
  2>/dev/null
echo "✅ Root CA generated successfully."

# Step 3: Generate the Vault Server Private Key and CSR
echo -e "\n⏳ [Step 3] Generating Vault Server Private Key and CSR (tls.key, vault.csr)..."
openssl req -new -nodes -newkey rsa:2048 \
  -keyout tls.key -out vault.csr \
  -config "$CONFIG_FILE" \
  2>/dev/null
echo "✅ Server Private Key and CSR generated successfully."

# Step 4: Sign the Server Certificate with the Root CA
echo -e "\n⏳ [Step 4] Signing the Server Certificate with the Root CA (tls.crt)..."
openssl x509 -req -in vault.csr \
  -CA rootCA.crt -CAkey rootCA.key -CAcreateserial \
  -out tls.crt -days 825 \
  -extfile "$CONFIG_FILE" -extensions v3_req \
  2>/dev/null
echo "✅ Server Certificate generated and signed successfully."

# Step 5: Verify the Final Certificate
echo -e "\n🔍 [Step 5] Verifying Subject Alternative Names in the final certificate:"
echo "--------------------------------------------------"
openssl x509 -in tls.crt -text -noout | grep -A 2 "Subject Alternative Name"
echo "--------------------------------------------------"

# Step 6: Summary and instructions
echo -e "\n🎉 Certificate Generation Complete!"
echo "=================================================="
echo "Generated Files:"
echo "  • rootCA.key   (KEEP SECRET - Root CA Private Key)"
echo "  • rootCA.crt   (SHARE - Add to your application's trust store)"
echo "  • tls.key      (Vault Server Private Key)"
echo "  • tls.crt      (Vault Server Public Certificate)"
echo "  • vault.csr    (Certificate Signing Request - safe to delete)"
echo "  • rootCA.srl   (CA Serial file - safe to ignore/delete)"
echo ""
echo "Next Steps:"
echo "1. Move 'tls.crt' and 'tls.key' to /opt/vault/tls/ on your Vault server."
echo "2. Ensure the 'vault' user has read permissions for those files."
echo "3. Distribute 'rootCA.crt' to your applications/clients."