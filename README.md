# Vault IAM Auth Playground

## Intro

The purpose of this repo is to provide a playground for Vault in IAM Authentication mode.  The project consists of 
two separate terraform config sets.  One to build the AWS infrastructure and one to setup the vault config, auth methods,
policies, and some test secrets.

## Getting started

Review the variables in variables.tf at the root to ensure that the default settings will be ok for your purposes.
Most importantly, ensure that you specify a key name that you have access to so you can access the vault nodes to unseal
them.  If you dont have a key for the account you are building in, then create one.  Here is some documentation how
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html

Pull this repo to your local machine, change to the repo, then run:

```bash
cd example
terraform init
terraform apply
``` 

After apply is complete, you will need to unseal the vault node.  We use an ASG in this case, but there should only be 
one node. Log into your AWS console and get the IP address of the node from the output of the 
terraform apply.  

```bash
ssh -i ${path_to_key} ec2-user@${VAULT_IP}
```

After SSH connect, the first thing you want to do is set your vault target to local like this

```bash
export VAULT_ADDR="http://127.0.0.1:8200/"
```

Then initialize Vault.  In our example, we are using DynamoDB as a backend so Vault is going to create that table itself. 
You'll want to ensure that the instance profile has write access to DynamoDB.

```bash
vault operator init
```

The output of this will be the unseal keys and the root key.  Record these values for later.  After init is complete,
we want to unseal Vault.  Do this with 'vault unseal'.  It will ask you for an unseal key, use one from the above output.  Enter one key at a time 
until it unseals, you should have to enter 3 different keys.  When you are successful, you will see
something like this.  Take note of the seal status, we want it to be false.

```
Key                    Value
---                    -----
Seal Type              shamir
Sealed                 false
Total Shares           5
Threshold              3
Version                0.10.1
Cluster Name           vault-cluster-840fe594
Cluster ID             5ea61114-87f0-dda0-4976-d7d939eac70a
HA Enabled             true
HA Cluster             n/a
HA Mode                standby
Active Node Address    <none>
```

Once this is complete we need to switch back to our terraform directory.  Under the examples directory, 
there is a folder called vault_resources.  There are some resources here to provision Vault with 
a base configuration.  First we need to fill in some parameters.  In vault.tf, you'll see a provider block

```hcl
provider "vault" {
  address = "http://vault-1140138079.us-east-1.elb.amazonaws.com:80"
  token   = "928d684a-3985-eb32-3933-80e168fda36c"
}
```

Replace the values here with the output of the initial terraform apply (vault_address), and the root token from the
vault init command you ran (you did save that didn't you?).

The next block enables AWS as a vault auth backend.

```hcl
resource "vault_auth_backend" "aws" {
  type = "aws"
}
```

Next we have a block to build the roles for the auth method.  In this example, we are creating a role that
uses iam authentication, and is bound to an instance role arn.  With this configuration, any instance that is assigned that 
instance profile will be able to authenticate.  You can read more about how this works in the Vault documentation here:
https://www.vaultproject.io/docs/auth/aws.html

Refer to the output of your Terraform apply to get the test_instance_profile_arn.  Insert this arn into the 
"bound_iam_instance_profile_arn" value.  

```hcl
resource "vault_aws_auth_backend_role" "example" {
  backend   = "${vault_auth_backend.aws.path}"
  role      = "aws-by-instanceprofile"
  auth_type = "iam"

  //  bound_ami_id                   = "ami-8c1be5f6"
  //  bound_account_id               = "123456789012"
  //  bound_vpc_id                   = "vpc-b61106d4"
  //  bound_subnet_id                = "vpc-133128f1"
  //  bound_iam_role_arn             = "arn:aws:iam::123456789012:role/MyRole"
  bound_iam_instance_profile_arn = "arn:aws:iam::724703905414:instance-profile/test-vault-profile"

  inferred_entity_type = "ec2_instance"
  inferred_aws_region  = "us-east-1"
  ttl                  = 60
  max_ttl              = 120

  policies = ["aws-by-instanceprofile"]
}
```

Below the role block you will see a "vault_policy" block and a "vault_generic_secret" block.  The policy allows all actions
at the path that the generic secret is configured.  This will give us a good test case in the next few steps.

```hcl
resource "vault_policy" "aws-by-instanceprofile" {
  name = "aws-by-instanceprofile"

  policy = <<EOF
# This policy allows all actions to the path "secret/aws-by-instanceprofile/*"
path "secret/aws-by-instanceprofile/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
}

resource "vault_generic_secret" "aws-by-instanceprofile" {
  data_json = <<EOF
{
  "diditwork": "yes"
}
EOF

  path = "secret/aws-by-instanceprofile/diditwork"
}
```

Next step is to connect to the test instance and login with vault.  The test instance connection string is output by the 
terraform apply you ran earlier.  Once you've connected to the test instance, verify vault was installed and run the following

```bash
# use the host name exported by the terraform apply
export VAULT_ADDR="${vault_address}"
vault login -method=aws role=aws-by-instanceprofile
```

If everything worked out then you should have gotten something like this:

```
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                                Value
---                                -----
token                              551afff7-a0da-8484-4682-65f7be7d950b
token_accessor                     350316bc-2b33-73a0-46cc-6e31dac6dae8
token_duration                     1m
token_renewable                    true
token_policies                     [aws-by-instanceprofile default]
token_meta_inferred_entity_id      i-056a0bb3bde0a2b20
token_meta_inferred_entity_type    ec2_instance
token_meta_account_id              724703905414
token_meta_auth_type               iam
token_meta_canonical_arn           arn:aws:iam::724703905414:role/testing-vault-ir
token_meta_client_arn              arn:aws:sts::724703905414:assumed-role/testing-vault-ir/i-056a0bb3bde0a2b20
token_meta_client_user_id          AROAJ4FB45KA4MHYQBOEG
token_meta_inferred_aws_region     us-east-1
```

Now we will want to test the key we created to see if we are really authenticated.

```bash
vault kv get secret/aws-by-instanceprofile/diditwork
```

If you got the following:
```
====== Data ======
Key          Value
---          -----
diditwork    yes
```

then you are successful.  Congratulations, you've successfully setup Vault with IAM authentication.

## What next?

Try adding another role, policy, and secret and binding it to a different resource, such as an aws account.  Additional
authentication paths can be configured by copying the following blocks in "vault.tf" in the example directory:
* vault_aws_auth_backend_role
* vault_policy
* vault_generic_secret

Here are a few thoughts and notes:
* Any subsequent secrets that you create under the paths specified in the policy will authenticate respective to the
auth role that your policy is mapped to.  
* You can have multiple policies attached to a single auth role, or have a policy mapped to multiple auth roles.
* Cross account authentication does not require a cross account trust because vault uses the AWS signed instance meta data 
document to verify instance authenticity.

TODOs for this repo
* enable ASG with SSM based auto-unseal.
* limit IAM policy at module/main.tf["testing_iam_instance_rolepolicy"], too broad at the moment 
* better code commenting throughout
