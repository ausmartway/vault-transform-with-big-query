#!/usr/bin/env python3
"""
Test script to demonstrate BigQuery emulator limitations with remote functions.
This shows why we need different approaches for local vs production.
"""

import requests
import json

BIGQUERY_BASE_URL = "http://localhost:9050"
PROJECT_ID = "test-project"

def test_basic_query():
    """Test that basic BigQuery queries work."""
    print("🧪 Testing basic BigQuery functionality...")
    
    sql = f"""
    SELECT 
        COUNT(*) as transaction_count,
        COUNT(DISTINCT encrypted_credit_card) as unique_cards
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    """
    
    query_payload = {
        "query": sql,
        "useLegacySql": False
    }
    
    try:
        response = requests.post(
            f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries",
            json=query_payload
        )
        
        if response.status_code == 200:
            result = response.json()
            if 'rows' in result and len(result['rows']) > 0:
                row = result['rows'][0]
                count = row['f'][0]['v']
                unique_cards = row['f'][1]['v']
                print(f"✅ BigQuery working: {count} transactions, {unique_cards} unique cards")
            else:
                print("✅ BigQuery working but no data found")
        else:
            print(f"❌ Basic query failed: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Error: {str(e)}")

def test_remote_function_support():
    """Test if BigQuery emulator supports remote functions (it doesn't)."""
    print("\n🧪 Testing remote function support...")
    
    # Try to create an external connection (this will fail in emulator)
    connection_sql = f"""
    CREATE OR REPLACE EXTERNAL CONNECTION `{PROJECT_ID}.us-central1.test-connection`
    OPTIONS (
      type = 'CLOUD_RESOURCE',
      endpoint = 'http://localhost:8080'
    );
    """
    
    query_payload = {
        "query": connection_sql,
        "useLegacySql": False
    }
    
    try:
        response = requests.post(
            f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries",
            json=query_payload
        )
        
        if response.status_code == 200:
            print("✅ External connection created (unexpected in emulator)")
        else:
            print(f"❌ External connection failed: {response.status_code}")
            print("   This is expected - BigQuery emulator doesn't support external connections")
            
    except Exception as e:
        print(f"❌ Error (expected): {str(e)}")

def test_function_creation():
    """Test creating a remote function (this will also fail in emulator)."""
    print("\n🧪 Testing remote function creation...")
    
    function_sql = f"""
    CREATE OR REPLACE FUNCTION `{PROJECT_ID}.test_functions.encrypt_test`(input STRING)
    RETURNS STRING
    REMOTE WITH CONNECTION `{PROJECT_ID}.us-central1.test-connection`
    OPTIONS (
      endpoint = 'http://localhost:8080'
    );
    """
    
    query_payload = {
        "query": function_sql,
        "useLegacySql": False
    }
    
    try:
        response = requests.post(
            f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries",
            json=query_payload
        )
        
        if response.status_code == 200:
            print("✅ Remote function created (unexpected in emulator)")
        else:
            print(f"❌ Remote function creation failed: {response.status_code}")
            print("   This is expected - BigQuery emulator doesn't support remote functions")
            
    except Exception as e:
        print(f"❌ Error (expected): {str(e)}")

def show_workaround():
    """Show our local development workaround."""
    print("\n" + "="*60)
    print("💡 LOCAL DEVELOPMENT WORKAROUND")
    print("="*60)
    print()
    print("Since BigQuery emulator doesn't support remote functions, we:")
    print()
    print("1. Make direct HTTP calls to Cloud Function:")
    print("   requests.post('http://localhost:8080', json=payload)")
    print()
    print("2. Use the encrypted result in regular SQL:")
    print("   SELECT * FROM transactions WHERE encrypted_credit_card = 'encrypted_value'")
    print()
    print("3. This simulates what would happen in production where:")
    print("   SELECT * FROM transactions")
    print("   WHERE encrypted_credit_card = vault_functions.encrypt_credit_card('4111111111111111')")
    print()
    print("See scripts/query_encrypted_data.py for working examples!")

def main():
    print("🔍 BIGQUERY EMULATOR REMOTE FUNCTION TEST")
    print("Testing what works and what doesn't in local development")
    print("="*60)
    
    test_basic_query()
    test_remote_function_support()
    test_function_creation()
    show_workaround()

if __name__ == "__main__":
    main()
