#!/usr/bin/env python3
"""
OVH API Test Script
Quick test to verify OVH API credentials and connectivity
"""

import ovh
import sys
import json

def test_ovh_api():
    """Test OVH API connection and basic functionality"""
    print("🔷 OVH API Connection Test")
    print("=" * 40)

    try:
        # Initialize OVH client with explicit credentials
        print("📡 Initializing OVH client...")
        client = ovh.Client(
            endpoint='ovh-ca',
            config_file='./ovh.conf'
        )
        print("✅ Client initialized successfully")

        # Test 1: Get account information
        print("\n🔍 Test 1: Account Information")
        try:
            me = client.get('/me')
            print(f"✅ Account: {me.get('nichandle', 'N/A')}")
            print(f"   Name: {me.get('firstname', '')} {me.get('name', '')}")
            print(f"   Email: {me.get('email', 'N/A')}")
            print(f"   Country: {me.get('country', 'N/A')}")
        except Exception as e:
            print(f"❌ Failed to get account info: {e}")
            return False

        # Test 2: List dedicated servers
        print("\n🖥️  Test 2: Dedicated Servers")
        try:
            servers = client.get('/dedicated/server')
            if servers:
                print(f"✅ Found {len(servers)} server(s):")
                for i, server in enumerate(servers[:5], 1):  # Show max 5 servers
                    try:
                        server_info = client.get(f'/dedicated/server/{server}')
                        print(f"   {i}. {server}")
                        print(f"      Range: {server_info.get('commercialRange', 'N/A')}")
                        print(f"      Datacenter: {server_info.get('datacenter', 'N/A')}")
                        print(f"      State: {server_info.get('state', 'N/A')}")
                    except Exception as e:
                        print(f"   {i}. {server} - Error getting details: {e}")

                if len(servers) > 5:
                    print(f"   ... and {len(servers) - 5} more servers")
            else:
                print("⚠️  No dedicated servers found")
        except Exception as e:
            print(f"❌ Failed to list servers: {e}")
            return False

        # Test 3: Check API permissions
        print("\n🔐 Test 3: API Permissions")
        permissions_ok = True

        # Test required endpoints
        required_endpoints = [
            ('/dedicated/server', 'GET'),
            ('/me', 'GET')
        ]

        for endpoint, method in required_endpoints:
            try:
                if method == 'GET':
                    if endpoint == '/dedicated/server':
                        client.get(endpoint)
                    elif endpoint == '/me':
                        client.get(endpoint)
                print(f"✅ {method} {endpoint} - OK")
            except Exception as e:
                print(f"❌ {method} {endpoint} - Failed: {e}")
                permissions_ok = False

        if permissions_ok:
            print("✅ All required permissions verified")
        else:
            print("⚠️  Some permissions may be missing")

        # Test 4: Test a server operation (if servers exist)
        if servers:
            print("\n🔧 Test 4: Server Operations")
            test_server = servers[0]
            try:
                # Test getting boot configuration (read-only)
                boot_info = client.get(f'/dedicated/server/{test_server}/boot')
                print(f"✅ Can read boot config for {test_server}")
                print(f"   Current boot type: {boot_info.get('bootType', 'N/A')}")

                # Test getting server tasks (read-only)
                tasks = client.get(f'/dedicated/server/{test_server}/task')
                print(f"✅ Can read server tasks ({len(tasks)} tasks)")

            except Exception as e:
                print(f"⚠️  Limited server access: {e}")

        print("\n🎉 API Test Summary:")
        print("✅ OVH API credentials are working correctly")
        print("✅ Basic operations successful")
        print("✅ Ready for Harvester deployment")

        return True

    except Exception as e:
        print(f"❌ API test failed: {e}")
        print("\n🔧 Troubleshooting:")
        print("   1. Check ovh.conf file exists and has correct credentials")
        print("   2. Verify API keys are active in OVH manager")
        print("   3. Check network connectivity")
        return False

def main():
    """Run API tests"""
    success = test_ovh_api()

    if success:
        print("\n✅ All tests passed! You can now run ovh-harvester-deploy.py")
        sys.exit(0)
    else:
        print("\n❌ Tests failed! Please fix API configuration")
        sys.exit(1)

if __name__ == "__main__":
    main()