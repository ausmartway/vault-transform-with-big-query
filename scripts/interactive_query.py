#!/usr/bin/env python3
"""
Interactive tool for querying encrypted credit card transactions.
This demonstrates a practical application of using real credit card numbers
to query encrypted data in BigQuery.
"""

import requests
import json
import sys
from typing import Optional

# Configuration
BIGQUERY_BASE_URL = "http://localhost:9050"
CLOUD_FUNCTION_URL = "http://localhost:8080"
PROJECT_ID = "test-project"

def encrypt_credit_card(card_number: str) -> Optional[str]:
    """Encrypt a credit card number using the Cloud Function."""
    try:
        payload = {
            "requestId": "interactive-query",
            "calls": [[card_number]]
        }
        
        response = requests.post(CLOUD_FUNCTION_URL, json=payload)
        
        if response.status_code == 200:
            result = response.json()
            if 'replies' in result and len(result['replies']) > 0:
                return result['replies'][0]
        
        print(f"❌ Encryption failed: {response.status_code} - {response.text}")
        return None
        
    except Exception as e:
        print(f"❌ Error encrypting credit card: {str(e)}")
        return None

def run_query(sql: str) -> Optional[list]:
    """Execute a SQL query against BigQuery."""
    query_request = {
        "query": sql,
        "useLegacySql": False
    }
    
    url = f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries"
    
    try:
        response = requests.post(url, json=query_request)
        
        if response.status_code == 200:
            result = response.json()
            if 'rows' in result:
                return result['rows'], result.get('schema', {}).get('fields', [])
            return [], []
        else:
            print(f"❌ Query failed: {response.status_code} - {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Error executing query: {str(e)}")
        return None

def format_transaction_results(rows, schema):
    """Format and display transaction results."""
    if not rows:
        print("   No transactions found.")
        return
    
    # Extract column names
    columns = [field['name'] for field in schema]
    
    print(f"   Found {len(rows)} transaction(s):")
    print()
    
    for i, row in enumerate(rows, 1):
        print(f"   Transaction {i}:")
        for j, col in enumerate(columns):
            value = row['f'][j]['v'] if row['f'][j]['v'] is not None else 'NULL'
            if col == 'amount':
                value = f"${float(value):,.2f}"
            elif col == 'is_fraud':
                value = "🚨 FRAUD" if value == 'true' else "✅ Legitimate"
            print(f"     {col}: {value}")
        print()

def query_by_credit_card():
    """Query transactions by credit card number."""
    print("\n🔍 Query Transactions by Credit Card Number")
    print("-" * 50)
    
    card_number = input("Enter credit card number (or 'quit' to exit): ").strip()
    
    if card_number.lower() == 'quit':
        return False
    
    if not card_number or len(card_number) < 13:
        print("❌ Invalid credit card number. Please enter a valid number.")
        return True
    
    print(f"\n🔐 Encrypting credit card number...")
    encrypted_card = encrypt_credit_card(card_number)
    
    if not encrypted_card:
        print("❌ Failed to encrypt credit card number.")
        return True
    
    print(f"✅ Encrypted: {card_number} → {encrypted_card}")
    
    print(f"\n🗃️  Searching for transactions...")
    
    sql = f"""
    SELECT 
        transaction_id,
        amount,
        merchant,
        merchant_category,
        transaction_date,
        location,
        is_fraud
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    WHERE encrypted_credit_card = '{encrypted_card}'
    ORDER BY transaction_date DESC
    """
    
    result = run_query(sql)
    if result is None:
        return True
    
    rows, schema = result
    format_transaction_results(rows, schema)
    
    return True

def query_by_merchant():
    """Query transactions by merchant."""
    print("\n🏪 Query Transactions by Merchant")
    print("-" * 40)
    
    merchant = input("Enter merchant name (partial match, or 'quit' to exit): ").strip()
    
    if merchant.lower() == 'quit':
        return False
    
    if not merchant:
        print("❌ Please enter a merchant name.")
        return True
    
    print(f"\n🗃️  Searching for transactions from merchants matching '{merchant}'...")
    
    sql = f"""
    SELECT 
        transaction_id,
        encrypted_credit_card,
        amount,
        merchant,
        merchant_category,
        transaction_date,
        location,
        is_fraud
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    WHERE LOWER(merchant) LIKE LOWER('%{merchant}%')
    ORDER BY transaction_date DESC
    """
    
    result = run_query(sql)
    if result is None:
        return True
    
    rows, schema = result
    format_transaction_results(rows, schema)
    
    return True

def query_fraud_transactions():
    """Query fraud transactions."""
    print("\n🚨 Query Fraud Transactions")
    print("-" * 30)
    
    print("Searching for all fraud transactions...")
    
    sql = f"""
    SELECT 
        transaction_id,
        encrypted_credit_card,
        amount,
        merchant,
        merchant_category,
        transaction_date,
        location,
        CASE 
            WHEN amount > 10000 THEN 'Very High Risk'
            WHEN amount > 5000 THEN 'High Risk'
            WHEN amount > 1000 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END as risk_level
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    WHERE is_fraud = true
    ORDER BY amount DESC
    """
    
    result = run_query(sql)
    if result is None:
        return True
    
    rows, schema = result
    
    if not rows:
        print("   ✅ No fraud transactions found.")
    else:
        print(f"   🚨 Found {len(rows)} fraud transaction(s):")
        print()
        
        total_fraud_amount = 0
        for i, row in enumerate(rows, 1):
            amount = float(row['f'][2]['v'])
            total_fraud_amount += amount
            
            print(f"   Fraud Transaction {i}:")
            columns = [field['name'] for field in schema]
            for j, col in enumerate(columns):
                value = row['f'][j]['v'] if row['f'][j]['v'] is not None else 'NULL'
                if col == 'amount':
                    value = f"${float(value):,.2f}"
                print(f"     {col}: {value}")
            print()
        
        print(f"   💰 Total fraud amount: ${total_fraud_amount:,.2f}")
    
    input("\nPress Enter to continue...")
    return True

def show_analytics():
    """Show analytics dashboard."""
    print("\n📊 Transaction Analytics Dashboard")
    print("-" * 40)
    
    # Summary statistics
    sql_summary = f"""
    SELECT 
        COUNT(*) as total_transactions,
        COUNT(DISTINCT encrypted_credit_card) as unique_cards,
        SUM(amount) as total_amount,
        AVG(amount) as avg_amount,
        SUM(CASE WHEN is_fraud = true THEN 1 ELSE 0 END) as fraud_count,
        SUM(CASE WHEN is_fraud = true THEN amount ELSE 0 END) as fraud_amount
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    """
    
    result = run_query(sql_summary)
    if result and result[0]:
        row = result[0][0]
        total_txns = int(row['f'][0]['v'])
        unique_cards = int(row['f'][1]['v']) 
        total_amount = float(row['f'][2]['v'])
        avg_amount = float(row['f'][3]['v'])
        fraud_count = int(row['f'][4]['v'])
        fraud_amount = float(row['f'][5]['v'])
        
        print("📈 Summary Statistics:")
        print(f"   • Total Transactions: {total_txns:,}")
        print(f"   • Unique Credit Cards: {unique_cards:,}")
        print(f"   • Total Transaction Amount: ${total_amount:,.2f}")
        print(f"   • Average Transaction: ${avg_amount:.2f}")
        print(f"   • Fraud Transactions: {fraud_count:,} ({fraud_count/total_txns*100:.1f}%)")
        print(f"   • Fraud Amount: ${fraud_amount:,.2f} ({fraud_amount/total_amount*100:.1f}%)")
    
    # Top merchants by transaction count
    sql_merchants = f"""
    SELECT 
        merchant,
        COUNT(*) as transaction_count,
        SUM(amount) as total_amount
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    GROUP BY merchant
    ORDER BY transaction_count DESC
    LIMIT 5
    """
    
    result = run_query(sql_merchants)
    if result and result[0]:
        print("\n🏪 Top Merchants by Transaction Count:")
        for i, row in enumerate(result[0], 1):
            merchant = row['f'][0]['v']
            count = int(row['f'][1]['v'])
            amount = float(row['f'][2]['v'])
            print(f"   {i}. {merchant}: {count} transactions, ${amount:,.2f}")
    
    input("\nPress Enter to continue...")
    return True

def main():
    """Main interactive loop."""
    print("🎯 Interactive Encrypted Transaction Query Tool")
    print("=" * 60)
    print("This tool demonstrates querying encrypted credit card data")
    print("using real credit card numbers as input.")
    print()
    
    # Check if services are running
    try:
        if not requests.get(f"{BIGQUERY_BASE_URL}/bigquery/v2/projects").ok:
            print("❌ BigQuery emulator is not running. Please start it first.")
            sys.exit(1)
        
        if not requests.get(CLOUD_FUNCTION_URL).ok:
            print("❌ Cloud Function is not running. Please start it first.")
            sys.exit(1)
    except:
        print("❌ Cannot connect to services. Please start them first.")
        sys.exit(1)
    
    print("✅ All services are running.")
    print()
    print("💡 Sample credit card numbers in the database:")
    print("   • 4111111111111111 (has 2 transactions, 1 fraud)")
    print("   • 4222222222222222 (has 2 transactions, 0 fraud)")
    print("   • 5555555555554444 (has 2 transactions, 0 fraud)")
    print("   • 6011111111111117 (has 2 transactions, 1 fraud)")
    
    while True:
        print("\n" + "=" * 60)
        print("🔍 Query Options:")
        print("1. Query by Credit Card Number")
        print("2. Query by Merchant")
        print("3. Show Fraud Transactions")
        print("4. Show Analytics Dashboard")
        print("5. Exit")
        
        choice = input("\nSelect an option (1-5): ").strip()
        
        if choice == '1':
            if not query_by_credit_card():
                break
        elif choice == '2':
            if not query_by_merchant():
                break
        elif choice == '3':
            if not query_fraud_transactions():
                break
        elif choice == '4':
            if not show_analytics():
                break
        elif choice == '5':
            print("\n👋 Goodbye!")
            break
        else:
            print("❌ Invalid option. Please choose 1-5.")

if __name__ == "__main__":
    main()
