#!/usr/bin/env python3
"""
Script to run test queries against BigQuery with sample transaction data.
"""

import requests
import json
from datetime import datetime

# BigQuery Emulator endpoint
BIGQUERY_BASE_URL = "http://localhost:9050"
PROJECT_ID = "test-project"

def run_query(sql, description):
    """Execute a SQL query and display results."""
    print(f"\n🔍 {description}")
    print(f"SQL: {sql}")
    print("-" * 80)
    
    query_request = {
        "query": sql,
        "useLegacySql": False
    }
    
    url = f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries"
    
    try:
        response = requests.post(url, json=query_request)
        
        if response.status_code == 200:
            result = response.json()
            
            if 'schema' in result and 'rows' in result:
                # Extract column names
                columns = [field['name'] for field in result['schema']['fields']]
                print(f"Columns: {', '.join(columns)}")
                print()
                
                # Display rows
                for i, row in enumerate(result['rows'][:10]):  # Limit to 10 rows
                    row_data = []
                    for j, col in enumerate(columns):
                        value = row['f'][j]['v'] if row['f'][j]['v'] is not None else 'NULL'
                        row_data.append(f"{col}: {value}")
                    print(f"Row {i+1}: {' | '.join(row_data)}")
                
                if len(result['rows']) > 10:
                    print(f"... and {len(result['rows']) - 10} more rows")
            else:
                print("✅ Query executed successfully (no results returned)")
        else:
            print(f"❌ Query failed with status {response.status_code}")
            print(f"Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Error executing query: {str(e)}")

def main():
    """Run various test queries to demonstrate the data."""
    print("🧪 Running BigQuery Test Queries")
    print("=" * 80)
    
    # Query 1: Show all transactions
    run_query(
        f"SELECT transaction_id, encrypted_credit_card, amount, merchant, is_fraud FROM `{PROJECT_ID}.fraud_detection.transactions` ORDER BY transaction_date",
        "All Transactions (showing encrypted credit cards)"
    )
    
    # Query 2: Show fraud transactions only
    run_query(
        f"SELECT transaction_id, encrypted_credit_card, amount, merchant, location FROM `{PROJECT_ID}.fraud_detection.transactions` WHERE is_fraud = true",
        "Fraud Transactions Only"
    )
    
    # Query 3: Transaction summary by merchant category
    run_query(
        f"SELECT merchant_category, COUNT(*) as transaction_count, SUM(amount) as total_amount, AVG(amount) as avg_amount FROM `{PROJECT_ID}.fraud_detection.transactions` GROUP BY merchant_category ORDER BY total_amount DESC",
        "Transaction Summary by Merchant Category"
    )
    
    # Query 4: High-value transactions (over $1000)
    run_query(
        f"SELECT transaction_id, encrypted_credit_card, amount, merchant, is_fraud FROM `{PROJECT_ID}.fraud_detection.transactions` WHERE amount > 1000 ORDER BY amount DESC",
        "High-Value Transactions (over $1000)"
    )
    
    # Query 5: Transactions per day
    run_query(
        f"SELECT DATE(transaction_date) as transaction_day, COUNT(*) as daily_transactions, SUM(amount) as daily_total FROM `{PROJECT_ID}.fraud_detection.transactions` GROUP BY DATE(transaction_date) ORDER BY transaction_day",
        "Daily Transaction Summary"
    )
    
    # Query 6: Available Vault functions
    run_query(
        f"SELECT function_name, endpoint_url, description FROM `{PROJECT_ID}.vault_functions.remote_functions`",
        "Available Vault Transform Functions"
    )
    
    # Query 7: Credit card usage patterns (encrypted cards)
    run_query(
        f"SELECT encrypted_credit_card, COUNT(*) as usage_count, SUM(amount) as total_spent, MAX(amount) as highest_transaction FROM `{PROJECT_ID}.fraud_detection.transactions` GROUP BY encrypted_credit_card ORDER BY total_spent DESC",
        "Credit Card Usage Patterns (using encrypted values)"
    )
    
    print("\n" + "=" * 80)
    print("✅ Test queries completed!")
    print("\n💡 Key insights from the data:")
    print("   • 8 total transactions with 2 marked as fraud")
    print("   • Transactions span multiple merchant categories")
    print("   • Credit card numbers are stored in encrypted format")
    print("   • Vault Transform functions are cataloged for remote queries")
    print("\n🔧 Next steps:")
    print("   • Connect Cloud Function to decrypt credit cards")
    print("   • Test remote function calls from BigQuery")
    print("   • Implement real-time fraud detection queries")

if __name__ == "__main__":
    main()
