# SA Demo 2.0: Data Engineering

## Repository/project map

| Project | Repository | dbt Platform |
|---------|-----------|-----------|
| Terraform Infrastructure | [sa-demo-terraform](https://github.com/dbt-labs/sa-demo-terraform) | — |
| Data Engineering | [sa_demo_data_eng](https://github.com/dbt-labs/sa_demo_data_eng) | [Open in dbt Platform](https://tr995.us1.dbt.com/deploy/70437463654940/projects/70437463662253) |
| Sales Analytics | [sa_demo_da_sales](https://github.com/dbt-labs/sa_demo_da_sales) | [Open in dbt Platform](https://tr995.us1.dbt.com/deploy/70437463654940/projects/70437463662273) |
| Marketing Analytics | [sa_demo_da_marketing](https://github.com/dbt-labs/sa_demo_da_marketing) | [Open in dbt Platform](https://tr995.us1.dbt.com/deploy/70437463654940/projects/70437463662272) |
| Data Science | [sa_demo_ds](https://github.com/dbt-labs/sa_demo_ds) | [Open in dbt Platform](https://tr995.us1.dbt.com/deploy/70437463654940/projects/70437463662271) |

## Local Development Setup

Follow these steps to run dbt locally on your Mac.

### 1. Generate Your Snowflake Key Pair

Open **Terminal** and paste this entire block:

```bash
mkdir -p ~/.ssh && \
openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes-256-cbc -inform PEM -out ~/.ssh/snowflake_rsa_key.p8 && \
openssl rsa -in ~/.ssh/snowflake_rsa_key.p8 -pubout -out ~/.ssh/snowflake_rsa_key.pub && \
echo "\n✅ Keys created! Here's your public key to add to Snowflake:\n" && \
grep -v "PUBLIC KEY" ~/.ssh/snowflake_rsa_key.pub | tr -d '\n' && echo "\n"
```

You'll be prompted to create a passphrase — **remember it** for step 3.

### 2. Register Your Public Key in Snowflake

Copy the public key that was displayed in the terminal, then run this SQL in Snowflake:

```sql
ALTER USER YOUR_USERNAME SET RSA_PUBLIC_KEY='paste_your_public_key_here';
```

Replace `YOUR_USERNAME` with your Snowflake username.

### 3. Set Environment Variables

Open **Terminal** and run:

```bash
open -e ~/.zshrc
```

Add these lines at the end of the file (fill in your values):

```bash
# dbt Snowflake Configuration
export DBT_SNOWFLAKE_USER="your_snowflake_username"
export DBT_DEVELOPMENT_SCHEMA="dbt_yourname"
export DBT_SNOWFLAKE_PRIVATE_KEY_PATH="~/.ssh/snowflake_rsa_key.p8"
export DBT_SNOWFLAKE_PRIVATE_KEY_PASSPHRASE="your_passphrase_from_step_1"
```

Save the file (**Cmd+S**) and close it. Then reload your shell:

```bash
source ~/.zshrc
```

### 4. Verify Your Setup

Test your connection:

```bash
dbt debug
```

You should see "All checks passed!" if everything is configured correctly.

---

## Using the Project

```bash
dbt run    # Run all models
dbt test   # Run all tests
```

## Resources

- [dbt Documentation](https://docs.getdbt.com/docs/introduction)
- [dbt Discourse](https://discourse.getdbt.com/) — Q&A
- [dbt Community](https://getdbt.com/community)
- [dbt Blog](https://blog.getdbt.com/)
