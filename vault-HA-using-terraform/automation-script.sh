#!/bin/sh
export VAULT_TOKEN="hvs.Z7gtDBSfwHO0rvRFMqrNl1Qf"

vault policy list | grep -i test-policy-1

#if [ "$?" -eq 0 ]; then
#    echo "Vault Policy available"
#else
#    vault policy write test-policy-1 - <<EOF
#    path "secret/data/*" {
#      capabilities = ["create", "update"]
#    }
#
#    path "secret/data/foo" {
#      capabilities = ["read"]
#    }
#EOF
#fi

vault policy write test-policy - <<EOF
    path "secret/data/*" {
      capabilities = ["create", "update"]
    }

    path "secret/data/foo" {
      capabilities = ["read"]
    }
EOF

vault policy write test-policy - <<EOF
    path "secret/data/*" {
      capabilities = ["create", "update"]
    }

    path "secret/data/foo" {
      capabilities = ["read"]
    }
EOF