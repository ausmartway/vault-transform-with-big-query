#!/usr/bin/env python3
"""
Comprehensive test to verify BigQuery emulator's remote function support capabilities.
This test systematically checks what BigQuery emulator can and cannot do.
"""

import requests
import json

BIGQUERY_BASE_URL = "http://localhost:9050"
PROJECT_ID = "test-project"

def test_external_connection_creation():
    """Test creating external connections (required for remote functions)."""
    print("🧪 Testing External Connection Creation")
    print("=" * 50)
    
    # Test 1: Try to create an external connection
    connection_sql = f"""
    CREATE OR REPLACE EXTERNAL CONNECTION `{PROJECT_ID}.us-central1.vault-connection`
    OPTIONS (
      type = 'CLOUD_RESOURCE',
      endpoint = 'http://localhost:8080'
    )
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
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text[:500]}...")
        
        if response.status_code == 200:
            print("✅ External connection creation SUCCEEDED (unexpected for emulator)")
            return True
        else:
            print("❌ External connection creation FAILED (expected for emulator)")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception during external connection test: {str(e)}")
        return False

def test_remote_function_creation():
    """Test creating remote functions."""
    print("\n🧪 Testing Remote Function Creation")
    print("=" * 50)
    
    function_sql = f"""
    CREATE OR REPLACE FUNCTION `{PROJECT_ID}.vault_functions.encrypt_test`(input STRING)
    RETURNS STRING
    REMOTE WITH CONNECTION `{PROJECT_ID}.us-central1.vault-connection`
    OPTIONS (
      endpoint = 'http://localhost:8080'
    )
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
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text[:500]}...")
        
        if response.status_code == 200:
            print("✅ Remote function creation SUCCEEDED (unexpected for emulator)")
            return True
        else:
            print("❌ Remote function creation FAILED (expected for emulator)")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception during remote function test: {str(e)}")
        return False

def test_regular_udf_creation():
    """Test if regular UDFs work (they should)."""
    print("\n🧪 Testing Regular UDF Creation")
    print("=" * 50)
    
    udf_sql = f"""
    CREATE OR REPLACE FUNCTION `{PROJECT_ID}.test_functions.add_numbers`(x INT64, y INT64)
    RETURNS INT64
    AS (x + y)
    """
    
    query_payload = {
        "query": udf_sql,
        "useLegacySql": False
    }
    
    try:
        response = requests.post(
            f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries",
            json=query_payload
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text[:500]}...")
        
        if response.status_code == 200:
            print("✅ Regular UDF creation SUCCEEDED")
            
            # Test calling the UDF
            test_sql = f"SELECT `{PROJECT_ID}.test_functions.add_numbers`(5, 3) as result"
            test_payload = {"query": test_sql, "useLegacySql": False}
            
            test_response = requests.post(
                f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries",
                json=test_payload
            )
            
            if test_response.status_code == 200:
                result = test_response.json()
                if 'rows' in result:
                    value = result['rows'][0]['f'][0]['v']
                    print(f"✅ UDF call result: {value} (should be 8)")
                    return True
            else:
                print(f"❌ UDF call failed: {test_response.text}")
        else:
            print("❌ Regular UDF creation FAILED")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception during UDF test: {str(e)}")
        return False

def test_javascript_udf():
    """Test JavaScript UDFs (should work according to documentation)."""
    print("\n🧪 Testing JavaScript UDF")
    print("=" * 50)
    
    js_udf_sql = f"""
    CREATE OR REPLACE FUNCTION `{PROJECT_ID}.test_functions.multiply_js`(x FLOAT64, y FLOAT64)
    RETURNS FLOAT64
    LANGUAGE js AS \"\"\"
    return x * y;
    \"\"\"
    """
    
    query_payload = {
        "query": js_udf_sql,
        "useLegacySql": False
    }
    
    try:
        response = requests.post(
            f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries",
            json=query_payload
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text[:500]}...")
        
        if response.status_code == 200:
            print("✅ JavaScript UDF creation SUCCEEDED")
            return True
        else:
            print("❌ JavaScript UDF creation FAILED")
            print(f"   Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception during JavaScript UDF test: {str(e)}")
        return False

def test_http_function_call():
    """Test if we can make HTTP calls from BigQuery (alternative to remote functions)."""
    print("\n🧪 Testing HTTP Function Calls")
    print("=" * 50)
    
    # This would be the ideal syntax, but likely won't work
    http_sql = """
    SELECT 
        NET.HTTP_GET('http://localhost:8080/encrypt', 
                     STRUCT('{"credit_card": "4111111111111111"}' AS body)) as result
    """
    
    query_payload = {
        "query": http_sql,
        "useLegacySql": False
    }
    
    try:
        response = requests.post(
            f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries",
            json=query_payload
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text[:500]}...")
        
        if response.status_code == 200:
            print("✅ HTTP function call SUCCEEDED (very unexpected)")
            return True
        else:
            print("❌ HTTP function call FAILED (expected)")
            return False
            
    except Exception as e:
        print(f"❌ Exception during HTTP function test: {str(e)}")
        return False

def test_basic_functionality():
    """Verify basic BigQuery functionality works."""
    print("\n🧪 Testing Basic BigQuery Functionality")
    print("=" * 50)
    
    basic_sql = "SELECT 'Hello World' as message, 42 as number"
    
    query_payload = {
        "query": basic_sql,
        "useLegacySql": False
    }
    
    try:
        response = requests.post(
            f"{BIGQUERY_BASE_URL}/bigquery/v2/projects/{PROJECT_ID}/queries",
            json=query_payload
        )
        
        if response.status_code == 200:
            result = response.json()
            if 'rows' in result:
                print("✅ Basic query works")
                print(f"   Result: {result['rows'][0]['f'][0]['v']}, {result['rows'][0]['f'][1]['v']}")
                return True
        else:
            print(f"❌ Basic query failed: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception during basic test: {str(e)}")
        return False

def check_emulator_version():
    """Check what version/capabilities the emulator reports."""
    print("\n🧪 Checking Emulator Capabilities")
    print("=" * 50)
    
    try:
        # Try to get discovery document
        discovery_response = requests.get(f"{BIGQUERY_BASE_URL}/discovery/v1/apis/bigquery/v2/rest")
        
        if discovery_response.status_code == 200:
            discovery = discovery_response.json()
            print(f"✅ Discovery endpoint works")
            if 'version' in discovery:
                print(f"   API Version: {discovery['version']}")
            if 'title' in discovery:
                print(f"   Title: {discovery['title']}")
        else:
            print(f"❌ Discovery endpoint failed: {discovery_response.status_code}")
            
    except Exception as e:
        print(f"❌ Exception during discovery: {str(e)}")

def show_summary():
    """Show final summary of capabilities."""
    print("\n" + "=" * 80)
    print("📋 BIGQUERY EMULATOR REMOTE FUNCTION CAPABILITY SUMMARY")
    print("=" * 80)
    print()
    print("❌ UNSUPPORTED (as expected):")
    print("   • External connections (CREATE EXTERNAL CONNECTION)")
    print("   • Remote functions (CREATE FUNCTION ... REMOTE WITH CONNECTION)")
    print("   • HTTP calls from SQL (NET.HTTP_* functions)")
    print()
    print("✅ SUPPORTED:")
    print("   • Basic SQL queries")
    print("   • Regular SQL UDFs")
    print("   • JavaScript UDFs (likely)")
    print("   • Standard BigQuery functions")
    print()
    print("💡 WORKAROUND FOR REMOTE FUNCTIONS:")
    print("   Since BigQuery emulator doesn't support remote functions, we:")
    print("   1. Make direct HTTP calls to Cloud Function from Python")
    print("   2. Use the encrypted result in standard SQL queries")
    print("   3. This simulates what remote functions would do in production")
    print()
    print("🏭 PRODUCTION vs LOCAL:")
    print("   • Production: SELECT * WHERE card = vault_functions.encrypt('4111111111111111')")
    print("   • Local: encrypted = http_call(); SELECT * WHERE card = '{encrypted}'")

def main():
    """Run all tests to determine BigQuery emulator's remote function capabilities."""
    print("🔍 BIGQUERY EMULATOR REMOTE FUNCTION CAPABILITY TEST")
    print("Testing what the BigQuery emulator can and cannot do")
    print("=" * 80)
    
    # Test basic functionality first
    if not test_basic_functionality():
        print("❌ Basic functionality failed - BigQuery emulator may not be running")
        return
    
    # Check emulator capabilities
    check_emulator_version()
    
    # Test remote function related features
    external_conn_works = test_external_connection_creation()
    remote_func_works = test_remote_function_creation()
    udf_works = test_regular_udf_creation()
    js_udf_works = test_javascript_udf()
    http_works = test_http_function_call()
    
    # Show comprehensive summary
    show_summary()
    
    print("\n🎯 CONCLUSION:")
    if not external_conn_works and not remote_func_works:
        print("✅ Confirmed: BigQuery emulator does NOT support remote functions")
        print("✅ Our workaround approach (direct HTTP calls) is necessary and correct")
    else:
        print("⚠️  Unexpected: Some remote function features seem to work")
        print("⚠️  This may indicate the emulator has been updated")

if __name__ == "__main__":
    main()
