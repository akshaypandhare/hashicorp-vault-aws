import requests
import os

# Vault server address
vault_addr = "http://a62389b7fad614da2b1159645cade134-5908869.ap-southeast-1.elb.amazonaws.com:8200"
# Vault token
vault_token = "hvs.CAESIO4qqywD1riqN8EjP4zxVIo6gpoh6mRdpKK37YAzqz2LGh4KHGh2cy56cTNtaWpOYjhHUklJcG0ycTRwQzJNQjQ"

# Path to the secret in Vault
secret_path = "akshay/secret"  # Update this with your secret path

# URL for Vault's API
url = f"{vault_addr}/v1/{secret_path}"

# Vault API request headers with the token
headers = {
    "X-Vault-Token": vault_token,
    "Content-Type": "application/json"
}

# Send GET request to Vault
response = requests.get(url, headers=headers)

# Check if request was successful (status code 200)
if response.status_code == 200:
    secret_data = response.json()["data"]
    print("Secret Retrieved Successfully:")
    print(secret_data)
else:
    print("Failed to retrieve secret from Vault")
    print(response.text)
