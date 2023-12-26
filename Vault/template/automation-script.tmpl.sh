#!/bin/sh
export VAULT_TOKEN="hvs.vh0dKUAojPqI7QnaGlmY9toS"

vault policy write test-policy - <<EOF
    path "secret/data/*" {
      capabilities = ["create", "update"]
    }

    path "secret/data/foo" {
      capabilities = ["read"]
    }
EOF
