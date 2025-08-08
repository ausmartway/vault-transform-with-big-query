import os
import json
import requests
from flask import Flask, request, jsonify
from typing import Dict, Any, Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class VaultTransformClient:
    """Client for interacting with Hashicorp Vault Transform Secret Engine"""
    
    def __init__(self):
        self.vault_url = os.environ.get('VAULT_URL', 'https://vault.example.com')
        self.vault_token = os.environ.get('VAULT_TOKEN')
        self.vault_namespace = os.environ.get('VAULT_NAMESPACE', '')
        self.transform_role = os.environ.get('VAULT_TRANSFORM_ROLE', 'creditcard-transform')
        
        if not self.vault_token:
            raise ValueError("VAULT_TOKEN environment variable is required")
    
    def _get_headers(self) -> Dict[str, str]:
        """Get headers for Vault API requests"""
        headers = {
            'X-Vault-Token': self.vault_token,
            'Content-Type': 'application/json'
        }
        if self.vault_namespace:
            headers['X-Vault-Namespace'] = self.vault_namespace
        return headers
    
    def encrypt(self, plaintext: str) -> Optional[str]:
        """
        Encrypt plaintext using Vault Transform Secret Engine
        
        Args:
            plaintext: The original credit card number to encrypt
            
        Returns:
            Encrypted value or None if encryption fails
        """
        try:
            url = f"{self.vault_url}/v1/transform/encode/{self.transform_role}"
            payload = {
                "value": plaintext
            }
            
            response = requests.post(
                url,
                headers=self._get_headers(),
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                return result.get('data', {}).get('encoded_value')
            else:
                logger.error(f"Vault encryption failed: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"Error encrypting data: {str(e)}")
            return None
    
    def decrypt(self, ciphertext: str) -> Optional[str]:
        """
        Decrypt ciphertext using Vault Transform Secret Engine
        
        Args:
            ciphertext: The encrypted credit card number to decrypt
            
        Returns:
            Decrypted value or None if decryption fails
        """
        try:
            url = f"{self.vault_url}/v1/transform/decode/{self.transform_role}"
            payload = {
                "value": ciphertext
            }
            
            response = requests.post(
                url,
                headers=self._get_headers(),
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                return result.get('data', {}).get('decoded_value')
            else:
                logger.error(f"Vault decryption failed: {response.status_code} - {response.text}")
                return None
                
        except Exception as e:
            logger.error(f"Error decrypting data: {str(e)}")
            return None

# Initialize Vault client
vault_client = VaultTransformClient()

@app.route('/encrypt', methods=['POST'])
def encrypt_credit_card():
    """
    BigQuery remote function endpoint for encrypting credit card numbers
    
    Expected request format from BigQuery:
    {
        "requestId": "124ab1c",
        "caller": "//bigquery.googleapis.com/projects/myproject/jobs/myproject:US.bquxjob_5b4c112c_17961fafeaf",
        "sessionUser": "test-user@test-company.com",
        "calls": [
            ["4111111111111111"],
            ["4222222222222222"]
        ]
    }
    """
    try:
        request_data = request.get_json()
        
        if not request_data or 'calls' not in request_data:
            return jsonify({"error": "Invalid request format"}), 400
        
        calls = request_data['calls']
        replies = []
        
        for call in calls:
            if not call or len(call) == 0:
                replies.append(None)
                continue
                
            credit_card_number = call[0]
            
            if not credit_card_number:
                replies.append(None)
                continue
            
            # Encrypt the credit card number
            encrypted_value = vault_client.encrypt(str(credit_card_number))
            replies.append(encrypted_value)
        
        response = {
            "replies": replies
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error in encrypt endpoint: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@app.route('/decrypt', methods=['POST'])
def decrypt_credit_card():
    """
    BigQuery remote function endpoint for decrypting credit card numbers
    
    Expected request format from BigQuery:
    {
        "requestId": "124ab1c",
        "caller": "//bigquery.googleapis.com/projects/myproject/jobs/myproject:US.bquxjob_5b4c112c_17961fafeaf",
        "sessionUser": "test-user@test-company.com",
        "calls": [
            ["encrypted_cc_1"],
            ["encrypted_cc_2"]
        ]
    }
    """
    try:
        request_data = request.get_json()
        
        if not request_data or 'calls' not in request_data:
            return jsonify({"error": "Invalid request format"}), 400
        
        calls = request_data['calls']
        replies = []
        
        for call in calls:
            if not call or len(call) == 0:
                replies.append(None)
                continue
                
            encrypted_value = call[0]
            
            if not encrypted_value:
                replies.append(None)
                continue
            
            # Decrypt the credit card number
            decrypted_value = vault_client.decrypt(str(encrypted_value))
            replies.append(decrypted_value)
        
        response = {
            "replies": replies
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error in decrypt endpoint: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy"}), 200

def vault_transform_bigquery(request):
    """
    Google Cloud Function entry point for HTTP requests
    This function handles both encryption and decryption based on the endpoint path
    """
    # Route the request to the appropriate Flask app endpoint
    with app.test_request_context(path=request.path, method=request.method, 
                                  data=request.get_data(), headers=request.headers):
        try:
            # Process the request through Flask app
            response = app.full_dispatch_request()
            return response
        except Exception as e:
            logger.error(f"Error processing request: {str(e)}")
            return jsonify({"error": "Internal server error"}), 500

if __name__ == "__main__":
    # For local testing
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
