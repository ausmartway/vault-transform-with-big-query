import unittest
import json
from unittest.mock import patch, MagicMock
import sys
import os

# Add the project root to the Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from main import app, VaultTransformClient

class TestVaultTransformBigQuery(unittest.TestCase):
    
    def setUp(self):
        """Set up test client"""
        self.app = app.test_client()
        self.app.testing = True
        
        # Mock environment variables
        self.env_patcher = patch.dict(os.environ, {
            'VAULT_URL': 'https://test-vault.com',
            'VAULT_TOKEN': 'test-token',
            'VAULT_NAMESPACE': 'test-namespace',
            'VAULT_TRANSFORM_ROLE': 'test-role'
        })
        self.env_patcher.start()
    
    def tearDown(self):
        """Clean up after tests"""
        self.env_patcher.stop()
    
    @patch('main.requests.post')
    def test_encrypt_endpoint_success(self, mock_post):
        """Test successful encryption endpoint"""
        # Mock Vault API response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'data': {'encoded_value': 'encrypted_4111111111111111'}
        }
        mock_post.return_value = mock_response
        
        # Test data in BigQuery remote function format
        test_data = {
            "requestId": "test-123",
            "caller": "//bigquery.googleapis.com/projects/test/jobs/test",
            "sessionUser": "test@example.com",
            "calls": [
                ["4111111111111111"],
                ["4222222222222222"]
            ]
        }
        
        response = self.app.post('/encrypt', 
                               data=json.dumps(test_data),
                               content_type='application/json')
        
        self.assertEqual(response.status_code, 200)
        response_data = json.loads(response.data)
        self.assertIn('replies', response_data)
        self.assertEqual(len(response_data['replies']), 2)
    
    @patch('main.requests.post')
    def test_decrypt_endpoint_success(self, mock_post):
        """Test successful decryption endpoint"""
        # Mock Vault API response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'data': {'decoded_value': '4111111111111111'}
        }
        mock_post.return_value = mock_response
        
        # Test data in BigQuery remote function format
        test_data = {
            "requestId": "test-123",
            "caller": "//bigquery.googleapis.com/projects/test/jobs/test",
            "sessionUser": "test@example.com",
            "calls": [
                ["encrypted_4111111111111111"],
                ["encrypted_4222222222222222"]
            ]
        }
        
        response = self.app.post('/decrypt', 
                               data=json.dumps(test_data),
                               content_type='application/json')
        
        self.assertEqual(response.status_code, 200)
        response_data = json.loads(response.data)
        self.assertIn('replies', response_data)
        self.assertEqual(len(response_data['replies']), 2)
    
    def test_encrypt_endpoint_invalid_data(self):
        """Test encryption endpoint with invalid data"""
        test_data = {"invalid": "data"}
        
        response = self.app.post('/encrypt', 
                               data=json.dumps(test_data),
                               content_type='application/json')
        
        self.assertEqual(response.status_code, 400)
        response_data = json.loads(response.data)
        self.assertIn('error', response_data)
    
    def test_health_endpoint(self):
        """Test health check endpoint"""
        response = self.app.get('/health')
        
        self.assertEqual(response.status_code, 200)
        response_data = json.loads(response.data)
        self.assertEqual(response_data['status'], 'healthy')
    
    @patch('main.requests.post')
    def test_vault_client_encrypt(self, mock_post):
        """Test VaultTransformClient encrypt method"""
        # Mock Vault API response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'data': {'encoded_value': 'encrypted_value'}
        }
        mock_post.return_value = mock_response
        
        client = VaultTransformClient()
        result = client.encrypt('4111111111111111')
        
        self.assertEqual(result, 'encrypted_value')
        mock_post.assert_called_once()
    
    @patch('main.requests.post')
    def test_vault_client_decrypt(self, mock_post):
        """Test VaultTransformClient decrypt method"""
        # Mock Vault API response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'data': {'decoded_value': '4111111111111111'}
        }
        mock_post.return_value = mock_response
        
        client = VaultTransformClient()
        result = client.decrypt('encrypted_value')
        
        self.assertEqual(result, '4111111111111111')
        mock_post.assert_called_once()
    
    @patch('main.requests.post')
    def test_vault_client_encrypt_failure(self, mock_post):
        """Test VaultTransformClient encrypt method with API failure"""
        # Mock Vault API failure response
        mock_response = MagicMock()
        mock_response.status_code = 400
        mock_response.text = 'Bad Request'
        mock_post.return_value = mock_response
        
        client = VaultTransformClient()
        result = client.encrypt('4111111111111111')
        
        self.assertIsNone(result)

if __name__ == '__main__':
    unittest.main()
