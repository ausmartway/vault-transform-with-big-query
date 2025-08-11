#!/usr/bin/env python3
"""
Test script for the Vault Transform Cloud Function
This script demonstrates how to call the Cloud Function for credit card encryption/decryption
"""

import json
import requests
import os
from typing import List, Dict, Any

def test_encrypt_function(function_url: str, credit_cards: List[str]) -> Dict[str, Any]:
    """Test the encrypt endpoint of the Cloud Function"""
    
    # BigQuery Remote Function format
    payload = {
        "requestId": "test-123",
        "caller": "//bigquery.googleapis.com/projects/test/jobs/test:US.bquxjob_test",
        "sessionUser": "test-user@test.com",
        "calls": [[cc] for cc in credit_cards]
    }
    
    response = requests.post(
        f"{function_url}/encrypt",
        json=payload,
        headers={"Content-Type": "application/json"},
        timeout=30
    )
    
    return response.status_code, response.json()

def test_decrypt_function(function_url: str, encrypted_values: List[str]) -> Dict[str, Any]:
    """Test the decrypt endpoint of the Cloud Function"""
    
    # BigQuery Remote Function format
    payload = {
        "requestId": "test-456",
        "caller": "//bigquery.googleapis.com/projects/test/jobs/test:US.bquxjob_test",
        "sessionUser": "test-user@test.com",
        "calls": [[enc] for enc in encrypted_values]
    }
    
    response = requests.post(
        f"{function_url}/decrypt",
        json=payload,
        headers={"Content-Type": "application/json"},
        timeout=30
    )
    
    return response.status_code, response.json()

def main():
    """Main test function"""
    
    # Get function URL from environment or use default
    function_url = os.environ.get('FUNCTION_URL', 'http://localhost:8080')
    
    print("🧪 Testing Vault Transform Cloud Function")
    print(f"📍 Function URL: {function_url}")
    print("-" * 50)
    
    # Test credit card numbers
    test_cards = [
        "4111111111111111",  # Visa test card
        "5555555555554444",  # Mastercard test card
        "378282246310005"    # Amex test card
    ]
    
    print("🔒 Testing Encryption...")
    status_code, encrypt_response = test_encrypt_function(function_url, test_cards)
    
    if status_code == 200:
        print("✅ Encryption successful!")
        encrypted_values = encrypt_response.get('replies', [])
        
        for i, (original, encrypted) in enumerate(zip(test_cards, encrypted_values)):
            print(f"  Card {i+1}: {original} → {encrypted}")
        
        print("\n🔓 Testing Decryption...")
        status_code, decrypt_response = test_decrypt_function(function_url, encrypted_values)
        
        if status_code == 200:
            print("✅ Decryption successful!")
            decrypted_values = decrypt_response.get('replies', [])
            
            # Verify round-trip
            all_match = True
            for i, (original, decrypted) in enumerate(zip(test_cards, decrypted_values)):
                match = "✅" if original == decrypted else "❌"
                print(f"  Card {i+1}: {decrypted} {match}")
                if original != decrypted:
                    all_match = False
            
            if all_match:
                print("\n🎉 All tests passed! Round-trip encryption/decryption successful.")
            else:
                print("\n❌ Round-trip test failed!")
        else:
            print(f"❌ Decryption failed: {status_code}")
            print(f"Response: {decrypt_response}")
    else:
        print(f"❌ Encryption failed: {status_code}")
        print(f"Response: {encrypt_response}")

if __name__ == "__main__":
    main()
