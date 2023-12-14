#!/bin/sh
vault secrets enable -path=akshay kv
vault kv put akshay/secret name=akshay
vault namespace create education

vault policy write test-policy - <<EOF
path "secret/data/*" {
  capabilities = ["create", "update"]
}

path "secret/data/foo" {
  capabilities = ["read"]
}
EOF