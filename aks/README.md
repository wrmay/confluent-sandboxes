# Overview
A Confluent Platform sandbox on Azure Kubernetes Service

This folder contains Terraform definitions for the following:
- An AKS Cluster
- An Azure Container Registry
- Networking
  - All Ingress is via an Application Gateway running TLS (you will provide the server cert)
  - A VNet with 3 subnets: one for the App Gateway, one for the AKS cluster and one for future use
  - Each subnet is configured with appropriate Network Security Groups 


# Prerequisites

- Terraform
- The Azure CLI (brew install azure-cli)
- An Azure account

# Instructions  

## Provision the Azure Resources
Start by generating a self signed certificate.  This will be installed on the 
Application Gateway.

```bash
#
# Execute these commands in the "keys" directory.  The Terraform template 
# expects the PFX to live there and that directory is excluded from git so 
# no key material will be checked in
# 
# Private key + self-signed cert
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout c3.lab.local.key \
  -out c3.lab.local.crt \
  -subj "/CN=c3.lab.local"

# Build PFX (you'll be prompted for a password)
openssl pkcs12 -export \
  -out c3-frontend.pfx \
  -inkey c3.lab.local.key \
  -in c3.lab.local.crt

  # save the password in a TF_VAR environment variable
  export TF_VAR_app_gateway_ssl_pfx_password='YourPfxPasswordHere'
  ```

Next, copy _variables.tf.template_ to _variables.tf_ and edit _variables.tf_.
Be sure to at least change the _resource_name_prefix_ and the _location_.

Prepare to deploy. In the same directory as this README, run the following. 
Be sure you have exported `TF_VAR_app_gateway_ssl_pfx_password` as described 
above.

```bash
# Be sure your CLI is logged in to Azure.  Select the subscription you wish
# to use
azure login

# initialize terraform and do a dry run
terraform init
terraform plan 
```

If `terraform plan` does not succeed, troubleshoot and repeat.  You only need 
to run `terraform init` once.

When the output looks right to you, deploy the Azure resources.

```bash
terraform apply
```

