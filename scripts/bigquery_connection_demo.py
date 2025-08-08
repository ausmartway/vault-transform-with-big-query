#!/usr/bin/env python3
"""
Demonstration of BigQuery Remote Functions vs Local Development Approach

This script shows the difference between:
1. Local development: Direct HTTP calls to Cloud Function
2. Production: BigQuery remote functions (simulated)
"""

import requests
import json
from typing import Optional

# Configuration
BIGQUERY_BASE_URL = "http://localhost:9050"
CLOUD_FUNCTION_URL = "http://localhost:8080"
PROJECT_ID = "test-project"

def demonstrate_local_approach():
    """Show how we currently query encrypted data in local development."""
    print("=" * 80)
    print("🏠 LOCAL DEVELOPMENT APPROACH")
    print("=" * 80)
    print()
    print("In local development, BigQuery emulator doesn't support remote functions.")
    print("So we make direct HTTP calls to the Cloud Function:")
    print()
    
    # Step 1: Direct call to Cloud Function for encryption
    print("1️⃣ ENCRYPT CREDIT CARD (Direct HTTP call)")
    card_number = "4111111111111111"
    
    payload = {
        "requestId": "encrypt-demo",
        "calls": [[card_number]]
    }
    
    print(f"   POST {CLOUD_FUNCTION_URL}")
    print(f"   Payload: {json.dumps(payload, indent=2)}")
    
    try:
        response = requests.post(CLOUD_FUNCTION_URL, json=payload)
        if response.status_code == 200:
            result = response.json()
            encrypted_value = result['replies'][0]
            print(f"   ✅ Response: {encrypted_value}")
        else:
            print(f"   ❌ Failed: {response.status_code}")
            return
    except Exception as e:
        print(f"   ❌ Error: {str(e)}")
        return
    
    # Step 2: Use encrypted value in BigQuery query
    print()
    print("2️⃣ QUERY BIGQUERY (Direct SQL with encrypted value)")
    sql = f"""
    SELECT 
        transaction_id,
        encrypted_credit_card,
        amount,
        merchant,
        is_fraud
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    WHERE encrypted_credit_card = '{encrypted_value}'
    """
    print(f"   SQL Query:")
    for line in sql.strip().split('\n'):
        print(f"   {line}")
    
    # Execute query
    try:
        query_payload = {
            "query": sql,
            "useLegacySql": False
        }
        
        query_response = requests.post(
            f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries",
            json=query_payload
        )
        
        if query_response.status_code == 200:
            query_result = query_response.json()
            if 'rows' in query_result:
                print(f"   ✅ Found {len(query_result['rows'])} transactions")
                for row in query_result['rows']:
                    values = [cell['v'] for cell in row['f']]
                    print(f"       Transaction: {values[0]}, Amount: ${values[2]}, Merchant: {values[3]}")
            else:
                print("   ✅ No transactions found")
        else:
            print(f"   ❌ Query failed: {query_response.status_code}")
            
    except Exception as e:
        print(f"   ❌ Query error: {str(e)}")

def demonstrate_production_approach():
    """Show how remote functions would work in production BigQuery."""
    print("\n" + "=" * 80)
    print("☁️  PRODUCTION APPROACH (BigQuery Remote Functions)")
    print("=" * 80)
    print()
    print("In production, BigQuery calls the Cloud Function automatically:")
    print()
    
    print("1️⃣ BIGQUERY SETUP (One-time configuration)")
    print("   Create external connection:")
    print("   CREATE OR REPLACE EXTERNAL CONNECTION `project.region.vault-connection`")
    print("   OPTIONS (")
    print("     type = 'CLOUD_RESOURCE',")
    print("     endpoint = 'https://your-cloud-function-url'")
    print("   );")
    print()
    
    print("   Create remote functions:")
    print("   CREATE OR REPLACE FUNCTION `project.vault_functions.encrypt_credit_card`(credit_card STRING)")
    print("   RETURNS STRING")
    print("   REMOTE WITH CONNECTION `project.region.vault-connection`;")
    print()
    
    print("2️⃣ SEAMLESS QUERYING (No manual encryption needed)")
    production_sql = """
    SELECT 
        transaction_id,
        vault_functions.decrypt_credit_card(encrypted_credit_card) as original_card,
        amount,
        merchant,
        transaction_date,
        is_fraud
    FROM `project.fraud_detection.transactions`
    WHERE encrypted_credit_card = vault_functions.encrypt_credit_card('4111111111111111')
    ORDER BY transaction_date DESC;
    """
    
    print("   SQL Query (BigQuery handles encryption automatically):")
    for line in production_sql.strip().split('\n'):
        print(f"   {line}")
    
    print()
    print("3️⃣ WHAT HAPPENS BEHIND THE SCENES:")
    print("   a) BigQuery calls vault_functions.encrypt_credit_card('4111111111111111')")
    print("   b) BigQuery sends HTTP request to Cloud Function:")
    print("      POST https://your-cloud-function-url")
    print("      {")
    print('        "requestId": "bquxjob_123...",')
    print('        "caller": "//bigquery.googleapis.com/...",')
    print('        "calls": [["4111111111111111"]]')
    print("      }")
    print("   c) Cloud Function responds with encrypted value")
    print("   d) BigQuery uses encrypted value in WHERE clause")
    print("   e) BigQuery calls vault_functions.decrypt_credit_card() for results")
    print("   f) Cloud Function decrypts values for display")

def show_cloud_function_interface():
    """Show the Cloud Function interface that BigQuery calls."""
    print("\n" + "=" * 80)
    print("🔧 CLOUD FUNCTION INTERFACE")
    print("=" * 80)
    print()
    print("Our Cloud Function expects BigQuery remote function format:")
    print()
    
    print("📥 REQUEST FORMAT:")
    request_example = {
        "requestId": "bquxjob_5b4c112c_17961fafeaf",
        "caller": "//bigquery.googleapis.com/projects/myproject/jobs/myproject:US.bquxjob_5b4c112c_17961fafeaf",
        "calls": [
            ["4111111111111111"],
            ["4222222222222222"],
            ["5555555555554444"]
        ]
    }
    print(json.dumps(request_example, indent=2))
    
    print()
    print("📤 RESPONSE FORMAT:")
    response_example = {
        "replies": [
            "9673837498063827",
            "0478270584270145", 
            "8514374752952481"
        ]
    }
    print(json.dumps(response_example, indent=2))
    
    print()
    print("🎯 CLOUD FUNCTION ENDPOINTS:")
    print(f"   Local:      {CLOUD_FUNCTION_URL}")
    print("   Production: https://your-region-your-project.cloudfunctions.net/vault-transform")
    
    print()
    print("📋 FUNCTION ENTRY POINTS:")
    print("   main.py:vault_transform_bigquery() - Main entry point")
    print("   Handles both encryption and decryption based on request content")

def main():
    """Run all demonstrations."""
    print("🔐 VAULT TRANSFORM + BIGQUERY INTEGRATION DEMO")
    print("How BigQuery connects to Cloud Function for encryption/decryption")
    print()
    
    # Show current local approach
    demonstrate_local_approach()
    
    # Show production approach
    demonstrate_production_approach()
    
    # Show Cloud Function interface
    show_cloud_function_interface()
    
    print("\n" + "=" * 80)
    print("📚 SUMMARY")
    print("=" * 80)
    print()
    print("Local Development:")
    print("  • BigQuery emulator doesn't support remote functions")
    print("  • We make direct HTTP calls to Cloud Function")
    print("  • Manual encryption before querying")
    print()
    print("Production:")
    print("  • BigQuery remote functions call Cloud Function automatically")
    print("  • Seamless encryption/decryption in SQL queries")
    print("  • No manual steps needed")
    print()
    print("Files:")
    print("  • sql/bigquery_setup.sql - Remote function definitions")
    print("  • src/main.py - Cloud Function code")
    print("  • scripts/query_encrypted_data.py - Local demo")
    print()

if __name__ == "__main__":
    main()
