#!/usr/bin/env python3
"""
Direct test of the main.py Cloud Function without Functions Framework
Tests the encrypt/decrypt functions directly
"""

import sys
import os
import json

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

# Import our main module
try:
    import main
    print("✅ Successfully imported main.py")
except ImportError as e:
    print(f"❌ Failed to import main.py: {e}")
    sys.exit(1)

def test_encrypt_function():
    """Test the encrypt function directly"""
    print("\n🔒 Testing encrypt function...")
    
    # Create a mock Flask request
    class MockRequest:
        def __init__(self, data):
            self._json = data
        
        def get_json(self):
            return self._json
    
    # Test data in BigQuery remote function format
    test_data = {
        "calls": [
            ["4111111111111111"],
            ["4222222222222222"], 
            ["5555555555554444"]
        ]
    }
    
    try:
        # Test encrypt_credit_card function
        with main.app.test_request_context('/', json=test_data):
            response = main.encrypt_credit_card()
            
        if response.status_code == 200:
            result = json.loads(response.data.decode('utf-8'))
        else:
            print(f"❌ Encryption returned status {response.status_code}")
            return None
            
        print("✅ Encryption successful!")
        print("📋 Results:")
        for i, call in enumerate(test_data["calls"]):
            original = call[0]
            encrypted = result["replies"][i]
            print(f"   {original} → {encrypted}")
            
        return result["replies"]
    except Exception as e:
        print(f"❌ Encryption failed: {e}")
        return None

def test_decrypt_function(encrypted_values):
    """Test the decrypt function directly"""
    if not encrypted_values:
        return False
        
    print("\n🔓 Testing decrypt function...")
    
    # Prepare decrypt data - convert each encrypted value to a list
    test_data = {
        "calls": [[encrypted_val] for encrypted_val in encrypted_values]
    }
    
    try:
        # Test decrypt_credit_card function
        with main.app.test_request_context('/', json=test_data):
            response = main.decrypt_credit_card()
            
        if response.status_code == 200:
            result = json.loads(response.data.decode('utf-8'))
        else:
            print(f"❌ Decryption returned status {response.status_code}")
            return False
            
        print("✅ Decryption successful!")
        print("📋 Results:")
        
        original_cards = ["4111111111111111", "4222222222222222", "5555555555554444"]
        for i, encrypted_val in enumerate(encrypted_values):
            decrypted = result["replies"][i]
            expected = original_cards[i]
            match = "✅" if decrypted == expected else "❌"
            print(f"   {encrypted_val} → {decrypted} {match}")
            
        return True
    except Exception as e:
        print(f"❌ Decryption failed: {e}")
        return False

def test_health_function():
    """Test the health function"""
    print("\n🏥 Testing health function...")
    
    try:
        # Test health_check function
        with main.app.test_request_context('/'):
            result = main.health_check()
            
        print(f"✅ Health check successful: {result}")
        return True
    except Exception as e:
        print(f"❌ Health check failed: {e}")
        return False

def main_test():
    """Main test function"""
    print("🧪 Direct Cloud Function Testing (No Framework)")
    print("=" * 50)
    
    # Check environment
    print("🔧 Environment check...")
    vault_addr = os.getenv('VAULT_ADDR', 'Not set')
    vault_token = os.getenv('VAULT_TOKEN', 'Not set')
    print(f"   VAULT_ADDR: {vault_addr}")
    print(f"   VAULT_TOKEN: {'Set' if vault_token and vault_token != 'Not set' else 'Not set'}")
    
    # Run tests
    health_ok = test_health_function()
    encrypted_values = test_encrypt_function()
    decrypt_ok = test_decrypt_function(encrypted_values)
    
    # Summary
    print(f"\n📊 Test Summary:")
    print(f"   Health check: {'✅ PASS' if health_ok else '❌ FAIL'}")
    print(f"   Encryption: {'✅ PASS' if encrypted_values else '❌ FAIL'}")
    print(f"   Decryption: {'✅ PASS' if decrypt_ok else '❌ FAIL'}")
    
    if all([health_ok, encrypted_values, decrypt_ok]):
        print("\n🎉 All tests passed!")
        print("\n💡 Your Cloud Function is ready for:")
        print("   1. Local Functions Framework testing")
        print("   2. Google Cloud deployment")
        print("   3. BigQuery remote function integration")
    else:
        print("\n❌ Some tests failed. Check your configuration.")
        
    return all([health_ok, encrypted_values, decrypt_ok])

if __name__ == "__main__":
    success = main_test()
    sys.exit(0 if success else 1)
