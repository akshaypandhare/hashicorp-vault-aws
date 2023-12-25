#!/bin/sh
export VAULT_TOKEN="hvs.EzQ5DNPoYx3jLX6zSX4BzKLR"

vault policy write test-policy - <<EOF
    path "secret/data/*" {
      capabilities = ["create", "update"]
    }

    path "secret/data/foo" {
      capabilities = ["read"]
    }
EOF