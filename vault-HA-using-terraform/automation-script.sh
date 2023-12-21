#!/bin/sh
export VAULT_TOKEN="hvs.Eo0y023L2bcUk1d2U0PFHMEE"

vault policy write test-policy - <<EOF
    path "secret/data/*" {
      capabilities = ["create", "update"]
    }

    path "secret/data/foo" {
      capabilities = ["read"]
    }
EOF