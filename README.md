# MLOps GCP-Vertex-Snowflake integration

<!--- Pick Cloud provider Badge -->
<!---![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white) -->
<!---![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white) -->
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)

<!--- Replace repository name -->
![License](https://badgen.net/github/license/getindata/terraform-module-template/)
![Release](https://badgen.net/github/release/getindata/terraform-module-template/)

<p align="center">
  <img height="150" src="https://getindata.com/img/logo.svg">
  <h3 align="center">We help companies turn their data into assets</h3>
</p>

---

The repository contains code samples from 
"MLOPs for Pro's - Technical perspective. Build a Feature Store Faster - an Introduction to Vertex AI, Snowflake and dbt Cloud" ebook.

## USAGE

### Set up environment

Prepare Terraform plan:

```terraform
terraform plan --out plan -var 'snowflake_password=PASSWORD' -var 'snowflake_account=ACCOUNT' -var 'snowflake_username=USERNAME'
```

Apply terraform plan:
```terraform
terraform apply plan
```

### Destroy environment

Prepare Terraform plan:

```terraform
terraform plan -destroy --out plan    
```

Apply terraform plan:
```terraform
terraform apply plan
```

## Inputs

| Name | Description                           | Type | Default | Required |
|------|---------------------------------------|------|--------|:--------:|
| service_account_file_name | File with the GCP Service Account Key | `string` | `key.json` |    no    |
| project_id | GCP Project ID                        | `string` |  |   yes    |
| region | Default GCP region | `string` | `europe-west4` |    no    |
| zone | Default GCP zone | `string` | `europe-west4-a` |    no    |
| bucket_region | Default GCP bucket region | `string` | `EUROPE-WEST4` |    no    |
| snowflake_region | Snowflake region | `string` | `europe-west4.gcp` |    no    |
| snowflake_username | Snowflake username | `string` | |   yes    |
| snowflake_account | Snowflake account name. https://docs.snowflake.com/en/user-guide/admin-account-identifier.html | `string` |  |   yes    |
| snowflake_password | Snowflake password | `string` |  |   yes    |

## CONTRIBUTING

Contributions are very welcomed!

Start by reviewing [contribution guide](CONTRIBUTING.md) and our [code of conduct](CODE_OF_CONDUCT.md). After that, start coding and ship your changes by creating a new PR.

## LICENSE

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.

## AUTHORS

<a href="https://github.com/getindata/mlops-gcp-vertex-snowflake-dbt">
  <img src="https://contrib.rocks/image?repo=getindata/mlops-gcp-vertex-snowflake-dbt" />
</a>

Made with [contrib.rocks](https://contrib.rocks).
