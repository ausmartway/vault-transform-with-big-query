#!/usr/bin/env python3
"""
Script to setup BigQuery datasets and populate with sample transaction data.
"""

import os
import sys
import json
import requests
from datetime import datetime, timedelta

# BigQuery Emulator endpoint
BIGQUERY_BASE_URL = "http://localhost:9050"
PROJECT_ID = "test-project"

def create_dataset(dataset_id):
    """Create a BigQuery dataset."""
    url = f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/datasets"
    
    dataset_config = {
        "datasetReference": {
            "datasetId": dataset_id,
            "projectId": PROJECT_ID
        },
        "friendlyName": f"Dataset {dataset_id}",
        "description": f"Dataset for {dataset_id} data"
    }
    
    response = requests.post(url, json=dataset_config)
    if response.status_code == 200:
        print(f"✅ Created dataset: {dataset_id}")
        return True
    elif response.status_code == 409:
        print(f"ℹ️  Dataset already exists: {dataset_id}")
        return True
    else:
        print(f"❌ Failed to create dataset {dataset_id}: {response.status_code}")
        print(f"Response: {response.text}")
        return False

def create_table(dataset_id, table_id, schema):
    """Create a BigQuery table with the given schema."""
    url = f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/datasets/{dataset_id}/tables"
    
    table_config = {
        "tableReference": {
            "projectId": PROJECT_ID,
            "datasetId": dataset_id,
            "tableId": table_id
        },
        "schema": {
            "fields": schema
        }
    }
    
    response = requests.post(url, json=table_config)
    if response.status_code == 200:
        print(f"✅ Created table: {dataset_id}.{table_id}")
        return True
    elif response.status_code == 409:
        print(f"ℹ️  Table already exists: {dataset_id}.{table_id}")
        return True
    else:
        print(f"❌ Failed to create table {dataset_id}.{table_id}: {response.status_code}")
        print(f"Response: {response.text}")
        return False

def insert_data(dataset_id, table_id, rows):
    """Insert data into a BigQuery table."""
    url = f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/datasets/{dataset_id}/tables/{table_id}/insertAll"
    
    insert_request = {
        "rows": [{"json": row} for row in rows]
    }
    
    response = requests.post(url, json=insert_request)
    if response.status_code == 200:
        print(f"✅ Inserted {len(rows)} rows into {dataset_id}.{table_id}")
        return True
    else:
        print(f"❌ Failed to insert data into {dataset_id}.{table_id}: {response.status_code}")
        print(f"Response: {response.text}")
        return False

def setup_fraud_detection_data():
    """Setup fraud detection dataset and sample transaction data."""
    
    # Create fraud_detection dataset
    if not create_dataset("fraud_detection"):
        return False
    
    # Define transaction table schema
    transaction_schema = [
        {"name": "transaction_id", "type": "STRING", "mode": "REQUIRED"},
        {"name": "encrypted_credit_card", "type": "STRING", "mode": "REQUIRED"},
        {"name": "original_credit_card", "type": "STRING", "mode": "NULLABLE"},
        {"name": "amount", "type": "FLOAT64", "mode": "REQUIRED"},
        {"name": "merchant", "type": "STRING", "mode": "REQUIRED"},
        {"name": "merchant_category", "type": "STRING", "mode": "NULLABLE"},
        {"name": "transaction_date", "type": "TIMESTAMP", "mode": "REQUIRED"},
        {"name": "location", "type": "STRING", "mode": "NULLABLE"},
        {"name": "is_fraud", "type": "BOOLEAN", "mode": "NULLABLE"},
        {"name": "created_at", "type": "TIMESTAMP", "mode": "REQUIRED"}
    ]
    
    # Create transactions table
    if not create_table("fraud_detection", "transactions", transaction_schema):
        return False
    
    # Sample transaction data (encrypted credit cards are dummy encrypted values)
    base_time = datetime.now() - timedelta(days=30)
    
    sample_transactions = [
        {
            "transaction_id": "TXN001",
            "encrypted_credit_card": "9673837498063827",  # Encrypted version of 4111111111111111
            "original_credit_card": "4111111111111111",   # For demo purposes - normally wouldn't store this
            "amount": 89.99,
            "merchant": "Amazon",
            "merchant_category": "E-commerce",
            "transaction_date": (base_time + timedelta(hours=1)).isoformat(),
            "location": "Online",
            "is_fraud": False,
            "created_at": datetime.now().isoformat()
        },
        {
            "transaction_id": "TXN002", 
            "encrypted_credit_card": "0478270584270145",  # Encrypted version of 4222222222222222
            "original_credit_card": "4222222222222222",
            "amount": 1299.99,
            "merchant": "Best Buy",
            "merchant_category": "Electronics",
            "transaction_date": (base_time + timedelta(hours=5)).isoformat(),
            "location": "New York, NY",
            "is_fraud": False,
            "created_at": datetime.now().isoformat()
        },
        {
            "transaction_id": "TXN003",
            "encrypted_credit_card": "8514374752952481",  # Encrypted version of 5555555555554444
            "original_credit_card": "5555555555554444",
            "amount": 45.67,
            "merchant": "Starbucks",
            "merchant_category": "Food & Beverage",
            "transaction_date": (base_time + timedelta(hours=12)).isoformat(),
            "location": "San Francisco, CA",
            "is_fraud": False,
            "created_at": datetime.now().isoformat()
        },
        {
            "transaction_id": "TXN004",
            "encrypted_credit_card": "9673837498063827",  # Same card as TXN001
            "original_credit_card": "4111111111111111",
            "amount": 25000.00,
            "merchant": "Suspicious Electronics Store",
            "merchant_category": "Electronics",
            "transaction_date": (base_time + timedelta(hours=13)).isoformat(),
            "location": "Unknown Location",
            "is_fraud": True,  # Flagged as fraud - large amount, suspicious merchant
            "created_at": datetime.now().isoformat()
        },
        {
            "transaction_id": "TXN005",
            "encrypted_credit_card": "0478270584270145",  # Same card as TXN002
            "original_credit_card": "4222222222222222",
            "amount": 199.99,
            "merchant": "Target",
            "merchant_category": "Retail",
            "transaction_date": (base_time + timedelta(days=1)).isoformat(),
            "location": "Chicago, IL",
            "is_fraud": False,
            "created_at": datetime.now().isoformat()
        },
        {
            "transaction_id": "TXN006",
            "encrypted_credit_card": "8514374752952481",  # Same card as TXN003
            "original_credit_card": "5555555555554444",
            "amount": 8999.99,
            "merchant": "Legitimate Jewelry Store",
            "merchant_category": "Luxury Goods",
            "transaction_date": (base_time + timedelta(days=2)).isoformat(),
            "location": "Beverly Hills, CA",
            "is_fraud": False,
            "created_at": datetime.now().isoformat()
        },
        {
            "transaction_id": "TXN007",
            "encrypted_credit_card": "2573849502847193",  # New encrypted card
            "original_credit_card": "6011111111111117",
            "amount": 15.99,
            "merchant": "Netflix",
            "merchant_category": "Subscription",
            "transaction_date": (base_time + timedelta(days=3)).isoformat(),
            "location": "Online",
            "is_fraud": False,
            "created_at": datetime.now().isoformat()
        },
        {
            "transaction_id": "TXN008",
            "encrypted_credit_card": "2573849502847193",  # Same card as TXN007
            "original_credit_card": "6011111111111117",
            "amount": 50000.00,
            "merchant": "Cash Advance ATM",
            "merchant_category": "ATM",
            "transaction_date": (base_time + timedelta(days=3, hours=2)).isoformat(),
            "location": "Foreign Country",
            "is_fraud": True,  # Large cash advance shortly after small purchase
            "created_at": datetime.now().isoformat()
        }
    ]
    
    # Insert sample data
    if not insert_data("fraud_detection", "transactions", sample_transactions):
        return False
    
    return True

def setup_vault_functions_data():
    """Setup dataset for Vault remote functions metadata."""
    
    # Create vault_functions dataset
    if not create_dataset("vault_functions"):
        return False
    
    # Define remote functions table schema
    functions_schema = [
        {"name": "function_name", "type": "STRING", "mode": "REQUIRED"},
        {"name": "endpoint_url", "type": "STRING", "mode": "REQUIRED"},
        {"name": "description", "type": "STRING", "mode": "NULLABLE"},
        {"name": "created_at", "type": "TIMESTAMP", "mode": "REQUIRED"}
    ]
    
    # Create remote_functions table
    if not create_table("vault_functions", "remote_functions", functions_schema):
        return False
    
    # Sample function metadata
    function_data = [
        {
            "function_name": "encrypt_credit_card",
            "endpoint_url": "http://cloud-function-dev:8080/encrypt",
            "description": "Encrypts credit card numbers using Vault Transform",
            "created_at": datetime.now().isoformat()
        },
        {
            "function_name": "decrypt_credit_card", 
            "endpoint_url": "http://cloud-function-dev:8080/decrypt",
            "description": "Decrypts credit card numbers using Vault Transform",
            "created_at": datetime.now().isoformat()
        },
        {
            "function_name": "health_check",
            "endpoint_url": "http://cloud-function-dev:8080/health",
            "description": "Health check endpoint for Vault Transform service",
            "created_at": datetime.now().isoformat()
        }
    ]
    
    # Insert function metadata
    if not insert_data("vault_functions", "remote_functions", function_data):
        return False
    
    return True

def verify_data():
    """Verify that data was inserted correctly by running some test queries."""
    print("\n🧪 Verifying data with test queries...")
    
    # Test query 1: Count transactions
    query1 = {
        "query": f"SELECT COUNT(*) as total_transactions FROM `{PROJECT_ID}.fraud_detection.transactions`",
        "useLegacySql": False
    }
    
    url = f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries"
    response = requests.post(url, json=query1)
    
    if response.status_code == 200:
        result = response.json()
        if 'rows' in result:
            count = result['rows'][0]['f'][0]['v']
            print(f"✅ Total transactions in database: {count}")
    
    # Test query 2: Count fraud transactions
    query2 = {
        "query": f"SELECT COUNT(*) as fraud_count FROM `{PROJECT_ID}.fraud_detection.transactions` WHERE is_fraud = true",
        "useLegacySql": False
    }
    
    response = requests.post(url, json=query2)
    if response.status_code == 200:
        result = response.json()
        if 'rows' in result:
            count = result['rows'][0]['f'][0]['v']
            print(f"✅ Fraud transactions in database: {count}")
    
    # Test query 3: List available functions
    query3 = {
        "query": f"SELECT function_name, endpoint_url FROM `{PROJECT_ID}.vault_functions.remote_functions`",
        "useLegacySql": False
    }
    
    response = requests.post(url, json=query3)
    if response.status_code == 200:
        result = response.json()
        if 'rows' in result:
            print(f"✅ Available remote functions: {len(result['rows'])}")
            for row in result['rows']:
                func_name = row['f'][0]['v']
                endpoint = row['f'][1]['v']
                print(f"   • {func_name}: {endpoint}")

def main():
    """Main function to setup all BigQuery data."""
    print("🚀 Setting up BigQuery datasets and sample data...")
    print(f"BigQuery Emulator: {BIGQUERY_BASE_URL}")
    print(f"Project ID: {PROJECT_ID}")
    print()
    
    # Check if BigQuery emulator is running
    try:
        response = requests.get(f"{BIGQUERY_BASE_URL}/bigquery/v2/projects")
        if response.status_code != 200:
            print(f"❌ BigQuery emulator may not be running. Status: {response.status_code}")
            return 1
        print(f"✅ BigQuery emulator is responding")
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to BigQuery emulator. Make sure it's running on localhost:9050")
        return 1
    
    # Setup fraud detection data
    print("📊 Setting up fraud detection dataset...")
    if not setup_fraud_detection_data():
        print("❌ Failed to setup fraud detection data")
        return 1
    
    print("\n🔧 Setting up Vault functions metadata...")
    if not setup_vault_functions_data():
        print("❌ Failed to setup Vault functions data")
        return 1
    
    print("\n🎯 Data setup complete!")
    
    # Verify the data
    verify_data()
    
    print("\n✅ BigQuery setup completed successfully!")
    print("\n💡 You can now run queries like:")
    print("   • SELECT * FROM `test-project.fraud_detection.transactions` LIMIT 5")
    print("   • SELECT COUNT(*) FROM `test-project.fraud_detection.transactions` WHERE is_fraud = true")
    print("   • SELECT * FROM `test-project.vault_functions.remote_functions`")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
