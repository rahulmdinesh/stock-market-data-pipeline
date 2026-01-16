# Stock Market Data Pipeline

An end-to-end **real-time + batch** data pipeline for ingesting, processing, storing, and analyzing US stock market data.

## Architecture Overview

Modern **medallion architecture** (Bronze → Silver → Gold) with:

- **Real-time** streaming quotes/trades
- **Batch** daily and YTD historical loads
- **Airflow** for pipeline orchestration 
- **Kafka** as message broker for real time streaming
- **MinIO** (S3-compatible) for object storage 
- **Snowflake** as Data Warehouse
- **dbt** for Data Warehouse transformations
- **Slack** alerts on successful loads, heartbeats & failures
- Heartbeats and logging for monitoring
- **Tableau** for visualization and analytics

## Features

- Idempotent & incremental loads
- Record-level deduplication for real-time quotes
- Market-hours aware processing
- Backfill support for missed data
- dbt-tested & documented transformations


### Data Flow

1. **Producer**: Fetches real-time stock data using Finnhub API during market hours and publishes it to Kafka
2. **Consumer**: Reads from Kafka and writes raw JSON/Parquet to MinIO
3. **Airflow DAGs**
   - `minio_to_snowflake.py` Loads raw real time and batch data to Snowflake Bronze layer
   - `daily_historical_load.py` Incrementally loads daily historical data to MinIO
   - `backfill_ytd_historical.py` One-time Year to Date (YTD) loading of historical data to MinIO
4. **dbt** → Transforms data via medallion architecture to make the data analytics-ready via fact tables and dimension tables
5. Output → Ready for dashboards (Tableau / Power BI / Streamlit / etc.)

## Tech Stack

- Python
- Apache Airflow (orchestration)
- Apache Kafka (real-time streaming)
- MinIO (object storage)
- Snowflake (data warehouse)
- dbt (transformations)
- Docker + docker-compose
- Tableau (visualization and analytics)


## Getting Started

To get started with the project, follow these steps:

1. Clone the repository:

```bash 
git clone https://github.com/rahulmdinesh/stock-market-data-pipeline.git
cd streaming-data-pipeline
```

2. Create a virtual environment

```bash 
python -m venv .venv  
```

3. Activate the virtual environment

```bash 
source .venv/bin/activate  
```

4. Install the dependencies
```bash
pip install -r requirements.txt
```

5. Set the required configurations in the `.env` file such as the Finhub API Key and Snowflake credentials

6. Login to your Snowflake account and run the following commands in a worksheet to set up the initial tables and the  DATA_PIPELINE_ROLE role
```
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS STOCKS;
CREATE SCHEMA IF NOT EXISTS STOCKS.COMMON;
USE SCHEMA STOCKS.COMMON;

CREATE TABLE IF NOT EXISTS bronze_stock_quotes_raw (
    -- Raw data columns
    close_price DECIMAL(10, 2),           
    price_change DECIMAL(10, 2),          
    price_change_percent DECIMAL(10, 4),  
    high_price DECIMAL(10, 2),            
    low_price DECIMAL(10, 2),             
    open_price DECIMAL(10, 2),            
    prev_close DECIMAL(10, 2),            
    symbol VARCHAR(10),                   
    
    -- Timestamps
    quote_timestamp TIMESTAMP_NTZ,        
    fetched_at TIMESTAMP_NTZ,             
    
    -- Metadata
    raw_json VARIANT,                    
    load_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Constraints
    CONSTRAINT pk_stock_quotes PRIMARY KEY (symbol, quote_timestamp)
);

-- Create role and assign to user
CREATE OR REPLACE ROLE DATA_PIPELINE_ROLE;
GRANT ROLE DATA_PIPELINE_ROLE TO USER rahulmdinesh;

-- Database-level access
GRANT USAGE ON DATABASE STOCKS TO ROLE DATA_PIPELINE_ROLE;
GRANT CREATE SCHEMA ON DATABASE STOCKS TO ROLE DATA_PIPELINE_ROLE;

-- Schema access (current and future)
GRANT USAGE ON ALL SCHEMAS IN DATABASE STOCKS TO ROLE DATA_PIPELINE_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE STOCKS TO ROLE DATA_PIPELINE_ROLE;

-- Table access (current and future, across all schemas)
GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE STOCKS TO ROLE DATA_PIPELINE_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE STOCKS TO ROLE DATA_PIPELINE_ROLE;

-- Stage access (current and future, across all schemas)
GRANT ALL PRIVILEGES ON ALL STAGES IN DATABASE STOCKS TO ROLE DATA_PIPELINE_ROLE;
GRANT ALL PRIVILEGES ON FUTURE STAGES IN DATABASE STOCKS TO ROLE DATA_PIPELINE_ROLE;

-- Warehouse access
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DATA_PIPELINE_ROLE;
GRANT OPERATE ON WAREHOUSE COMPUTE_WH TO ROLE DATA_PIPELINE_ROLE;
```

7. Start the containers using Docker Compose
```bash
docker compose up -d
```

8. Launch the Airflow Web UI
```bash
open http://localhost:8080/
```

9. In the Airflow Web UI, go to Admin → Connections; create the following 3 connections:

    a. MinIO Connection:
    - Connection ID: minio_s3 
    - Connection type: Amazon Web Services 
    - Details: provide the MinIO username in the AWS Access Key ID field and the MinIO password in the AWS Secret Access Key field. Also ensure in the Extra Fields, `http://minio:9000` is provided in the host field

    b. Slack Connection:
    - Connection ID: slack_webhook_url
    - Connection type: Slack Incoming Webhook 
    - Details: In the Webhook Token field, paste the Webhook URL. Follow the steps to create one:
        1. Go to https://api.slack.com/apps
        2. Click “Create New App” → “From Scratch”
        3. Give it a name, for example: “Stock Market Data Pipeline Alerts”
        4. Enable Incoming Webhooks
        5. Click “Add Webhook to Workspace” → choose your alert channel (e.g., #data-alerts)
        6. Copy the Webhook URL

    c. Snowflake Connection:
    - Connection ID: snowflake_default
    - Connection type: Snowflake 
    - Details: provide your Snowflake login name in the login field and your Snowflake account password in the password field. In the Extra Fields, populate the Account field with your Snowflake Account Identifier, Warehouse as COMPUTE_WH, Database as STOCKS, schema as COMMON and role as DATA_PIPELINE_ROLE

10. Launch the Airflow Web UI and trigger the `backfill_ytd_historical` DAG
```bash
open http://localhost:8080/
```

11. Launh the Kafdrop Web UI to monitor Kafka cluster and topic metrics
```bash
open http://localhost:9003/
```

12. Once all 3 DAGs have run successfully, run SQL queries om Snowflake to view the data.

## Screenshots
Airflow Web UI for triggering and monitoring DAGs
<img width="1728" height="876" alt="image" src="https://github.com/user-attachments/assets/951f7ed8-5fb8-4967-a447-ba567c1854fe" />

MinIO Web UI
<img width="1728" height="876" alt="image" src="https://github.com/user-attachments/assets/e47b9eff-42d5-4796-bdbc-db2ffcb2b5f6" />

Kafdrop Web UI for Kafka Cluster and Topic metrics
<img width="1728" height="876" alt="image" src="https://github.com/user-attachments/assets/2772ee54-e4d2-4e10-936e-d54f633f5182" />

Slack integration for alerting and monitoring
<img width="1728" height="991" alt="image" src="https://github.com/user-attachments/assets/39202956-fbea-407b-b9c0-3b0c3492cdfe" />

Snowflake UI with schemas generated via DBT (Bronze, Silver, Gold)
<img width="1728" height="872" alt="image" src="https://github.com/user-attachments/assets/fed9001f-9eff-4004-a58a-954fcc08bbec" />

Tableau Dashboard showing KPI Cards for each stock
<img width="1280" height="673" alt="image" src="https://github.com/user-attachments/assets/a7854f43-1639-49a9-8c29-73a1fa783464" />

