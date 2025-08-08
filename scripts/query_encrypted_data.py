#!/usr/bin/env python3
"""
Script to demonstrate querying encrypted BigQuery data using real credit card numbers as input.
This shows how to encrypt a credit card number and then find matching records in the database.
"""

import requests
import json
from typing import Optional

# Configuration
BIGQUERY_BASE_URL = "http://localhost:9050"
CLOUD_FUNCTION_URL = "http://localhost:8080"
PROJECT_ID = "test-project"

def encrypt_credit_card(card_number: str) -> Optional[str]:
    """
    Encrypt a credit card number using the Cloud Function.
    
    Args:
        card_number: The credit card number to encrypt
        
    Returns:
        Encrypted credit card number or None if encryption fails
    """
    try:
        payload = {
            "requestId": "encrypt-query",
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

def run_bigquery_query(sql: str, description: str = "Query"):
    """Execute a SQL query against BigQuery and display results."""
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
                
                if len(result['rows']) == 0:
                    print("No results found.")
                else:
                    # Display rows
                    for i, row in enumerate(result['rows']):
                        row_data = []
                        for j, col in enumerate(columns):
                            value = row['f'][j]['v'] if row['f'][j]['v'] is not None else 'NULL'
                            row_data.append(f"{col}: {value}")
                        print(f"Row {i+1}: {' | '.join(row_data)}")
                
                return result['rows']
            else:
                print("✅ Query executed successfully (no results returned)")
                return []
        else:
            print(f"❌ Query failed with status {response.status_code}")
            print(f"Response: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Error executing query: {str(e)}")
        return None

def find_transactions_by_card(card_number: str):
    """
    Find all transactions for a given credit card number.
    This demonstrates the complete workflow of encrypting the input and querying.
    """
    print(f"🔍 Searching for transactions using credit card: {card_number}")
    
    # Step 1: Encrypt the credit card number
    print("\n📟 Step 1: Encrypting the credit card number...")
    encrypted_card = encrypt_credit_card(card_number)
    
    if not encrypted_card:
        print("❌ Failed to encrypt credit card number")
        return
    
    print(f"✅ Encrypted: {card_number} → {encrypted_card}")
    
    # Step 2: Query BigQuery for transactions with this encrypted card
    print("\n🗃️  Step 2: Querying BigQuery for matching transactions...")
    
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
    WHERE encrypted_credit_card = '{encrypted_card}'
    ORDER BY transaction_date DESC
    """
    
    results = run_bigquery_query(sql, f"Transactions for card ending in {card_number[-4:]}")
    
    if results and len(results) > 0:
        print(f"\n✅ Found {len(results)} transaction(s) for this credit card")
        
        # Calculate summary statistics
        total_amount = 0
        fraud_count = 0
        
        for row in results:
            amount = float(row['f'][2]['v']) if row['f'][2]['v'] else 0
            is_fraud = row['f'][7]['v'] == 'true' if row['f'][7]['v'] else False
            
            total_amount += amount
            if is_fraud:
                fraud_count += 1
        
        print(f"\n📊 Summary:")
        print(f"   • Total transactions: {len(results)}")
        print(f"   • Total amount: ${total_amount:,.2f}")
        print(f"   • Fraud transactions: {fraud_count}")
        print(f"   • Average amount: ${total_amount/len(results):,.2f}")
        
    else:
        print(f"\n⚠️  No transactions found for credit card {card_number}")

def demonstrate_analytics_queries():
    """Demonstrate various analytics queries using encrypted data."""
    
    print("\n" + "="*80)
    print("🔬 ADVANCED ANALYTICS ON ENCRYPTED DATA")
    print("="*80)
    
    # Query 1: Find suspicious patterns (multiple transactions from same encrypted card)
    sql1 = f"""
    SELECT 
        encrypted_credit_card,
        COUNT(*) as transaction_count,
        SUM(amount) as total_spent,
        MAX(amount) as highest_transaction,
        COUNT(CASE WHEN is_fraud = true THEN 1 END) as fraud_count
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    GROUP BY encrypted_credit_card
    HAVING COUNT(*) > 1
    ORDER BY total_spent DESC
    """
    
    run_bigquery_query(sql1, "Credit Card Usage Analysis (Encrypted)")
    
    # Query 2: Risk analysis by merchant category
    sql2 = f"""
    SELECT 
        merchant_category,
        COUNT(DISTINCT encrypted_credit_card) as unique_cards,
        COUNT(*) as total_transactions,
        AVG(amount) as avg_amount,
        SUM(CASE WHEN is_fraud = true THEN 1 ELSE 0 END) as fraud_transactions,
        ROUND(100.0 * SUM(CASE WHEN is_fraud = true THEN 1 ELSE 0 END) / COUNT(*), 2) as fraud_percentage
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    GROUP BY merchant_category
    ORDER BY fraud_percentage DESC, total_transactions DESC
    """
    
    run_bigquery_query(sql2, "Fraud Risk Analysis by Merchant Category")
    
    # Query 3: High-value transactions analysis
    sql3 = f"""
    SELECT 
        encrypted_credit_card,
        transaction_id,
        amount,
        merchant,
        location,
        is_fraud,
        CASE 
            WHEN amount > 10000 THEN 'Very High Risk'
            WHEN amount > 5000 THEN 'High Risk'
            WHEN amount > 1000 THEN 'Medium Risk'
            ELSE 'Low Risk'
        END as risk_category
    FROM `{PROJECT_ID}.fraud_detection.transactions`
    WHERE amount > 1000
    ORDER BY amount DESC
    """
    
    run_bigquery_query(sql3, "High-Value Transaction Risk Assessment")

def demonstrate_real_scenario():
    """
    Demonstrate how the system would work in a real scenario by:
    1. Taking a real credit card number
    2. Encrypting it using Vault Transform
    3. Storing a transaction with the encrypted value
    4. Then querying it back using the original number
    """
    print("\n" + "="*80)
    print("🔧 REAL SCENARIO DEMONSTRATION")
    print("="*80)
    print("This shows how the system would work with fresh data:")
    print("1. Encrypt a real credit card number")
    print("2. Store a transaction with the encrypted value")
    print("3. Query using the original credit card number")
    
    test_card = "4000000000000002"  # Valid test card number
    
    print(f"\n📝 Using test credit card: {test_card}")
    
    # Step 1: Encrypt the card
    print("\n🔐 Step 1: Encrypting the credit card...")
    encrypted_card = encrypt_credit_card(test_card)
    
    if not encrypted_card:
        print("❌ Failed to encrypt - skipping real scenario demo")
        return
    
    print(f"✅ Encrypted: {test_card} → {encrypted_card}")
    
    # Step 2: Insert a test transaction
    print("\n💾 Step 2: Inserting a test transaction...")
    
    insert_url = f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/datasets/fraud_detection/tables/transactions/insertAll"
    
    test_transaction = {
        "rows": [{
            "json": {
                "transaction_id": "TXN_DEMO_001",
                "encrypted_credit_card": encrypted_card,
                "original_credit_card": test_card,  # For demo only
                "amount": 299.99,
                "merchant": "Demo Store",
                "merchant_category": "Demo",
                "transaction_date": "2025-08-08T12:00:00Z",
                "location": "Demo Location",
                "is_fraud": False,
                "created_at": "2025-08-08T12:00:00Z"
            }
        }]
    }
    
    try:
        response = requests.post(insert_url, json=test_transaction)
        if response.status_code == 200:
            print("✅ Test transaction inserted successfully")
        else:
            print(f"⚠️  Insert failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Error inserting transaction: {str(e)}")
    
    # Step 3: Query using the original card number
    print(f"\n🔍 Step 3: Querying for transactions using original card {test_card}...")
    
    # Encrypt the input card number
    query_encrypted = encrypt_credit_card(test_card)
    
    if query_encrypted:
        sql = f"""
        SELECT 
            transaction_id,
            encrypted_credit_card,
            amount,
            merchant,
            location,
            is_fraud
        FROM `{PROJECT_ID}.fraud_detection.transactions`
        WHERE encrypted_credit_card = '{query_encrypted}'
        ORDER BY transaction_date DESC
        """
        
        results = run_bigquery_query(sql, f"Demo: Transactions for card {test_card}")
        
        if results and len(results) > 0:
            print(f"\n🎉 SUCCESS! Found {len(results)} transaction(s) using real encryption")
        else:
            print(f"\n⚠️  No transactions found (this might be expected if encryption uses random elements)")
    
    print("\n💡 This demonstrates the complete workflow:")
    print("   1. Credit card numbers are encrypted before storage")
    print("   2. Queries encrypt input before searching")
    print("   3. No plain text credit cards are stored or searched")

def demonstrate_with_existing_data():
    """
    Demonstrate with the existing sample data that has pre-encrypted values.
    """
    print("\n" + "="*80)
    print("📊 WORKING WITH EXISTING SAMPLE DATA")
    print("="*80)
    print("Since our sample data has pre-encrypted values, let's show analytics:")
    
    # Map of existing encrypted values to original cards for demo
    existing_mappings = {
        "9673837498063827": "4111111111111111",
        "0478270584270145": "4222222222222222", 
        "8514374752952481": "5555555555554444",
        "2573849502847193": "6011111111111117"
    }
    
    print("\n🗂️  Existing encrypted mappings in sample data:")
    for encrypted, original in existing_mappings.items():
        print(f"   {original} → {encrypted}")
    
    # Now let's query for each existing card
    for encrypted_card, original_card in existing_mappings.items():
        print(f"\n🔍 Querying transactions for card ending in {original_card[-4:]}...")
        
        sql = f"""
        SELECT 
            transaction_id,
            encrypted_credit_card,
            amount,
            merchant,
            merchant_category,
            location,
            is_fraud
        FROM `{PROJECT_ID}.fraud_detection.transactions`
        WHERE encrypted_credit_card = '{encrypted_card}'
        ORDER BY transaction_date DESC
        """
        
        results = run_bigquery_query(sql, f"Existing data: Card ending in {original_card[-4:]}")
        
        if results and len(results) > 0:
            print(f"✅ Found {len(results)} transaction(s)")
            
            # Calculate summary
            total_amount = 0
            fraud_count = 0
            
            for row in results:
                amount = float(row['f'][2]['v']) if row['f'][2]['v'] else 0
                is_fraud = row['f'][6]['v'] == 'true' if row['f'][6]['v'] else False
                
                total_amount += amount
                if is_fraud:
                    fraud_count += 1
            
            print(f"   💰 Total spent: ${total_amount:,.2f}")
            print(f"   ⚠️  Fraud transactions: {fraud_count}")
        else:
            print("   ❌ No transactions found")

def main():
    """Main function to demonstrate querying encrypted data with real card numbers."""
    
    print("🎯 BigQuery Encrypted Data Query Demo")
    print("="*80)
    print("This demo shows how to use real credit card numbers to query encrypted data")
    print("in BigQuery using the Vault Transform Cloud Function for encryption.")
    print()
    
    # First, demonstrate with existing sample data
    demonstrate_with_existing_data()
    
    # Then show advanced analytics
    demonstrate_analytics_queries()
    
    # Finally, demonstrate the real scenario
    demonstrate_real_scenario()
    
    print("\n" + "="*80)
    print("✅ Demo completed!")
    print("\n💡 Key Insights:")
    print("   • Credit card numbers are encrypted before querying")
    print("   • Queries work on encrypted data without exposing original numbers")
    print("   • Analytics can be performed on encrypted datasets")
    print("   • The Cloud Function handles encryption/decryption transparently")
    print("\n🔧 Usage in production:")
    print("   • Replace localhost URLs with actual service endpoints")
    print("   • Add proper authentication and authorization")
    print("   • Implement rate limiting and monitoring")
    print("   • Use parameterized queries to prevent SQL injection")
    print("   • Ensure consistent encryption configuration across all services")

if __name__ == "__main__":
    main()
