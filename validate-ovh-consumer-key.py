#!/usr/bin/env python3
"""
OVH Consumer Key Validation Script
This script helps validate the consumer key for OVH API access
"""

import ovh
import sys
import webbrowser

def validate_consumer_key():
    """Validate or generate a new consumer key"""
    print("🔷 OVH Consumer Key Validation")
    print("=" * 40)

    try:
        # Initialize client with app key and secret only
        print("📡 Initializing OVH client for validation...")
        # Read config file and use only app key/secret for validation
        import configparser
        config = configparser.ConfigParser()
        config.read('./ovh.conf')

        client = ovh.Client(
            endpoint=config['default']['endpoint'],
            application_key=config['default']['application_key'],
            application_secret=config['default']['application_secret']
        )

        # Request access rules
        access_rules = [
            {'method': 'GET', 'path': '/me'},
            {'method': 'GET', 'path': '/dedicated/server'},
            {'method': 'GET', 'path': '/dedicated/server/*'},
            {'method': 'PUT', 'path': '/dedicated/server/*'},
            {'method': 'POST', 'path': '/dedicated/server/*/reboot'},
            {'method': 'GET', 'path': '/dedicated/server/*/boot'},
            {'method': 'PUT', 'path': '/dedicated/server/*/boot'},
            {'method': 'GET', 'path': '/dedicated/server/*/task'},
        ]

        print("🔑 Requesting new consumer key...")
        validation = client.request_consumerkey(access_rules)

        print("✅ Consumer key validation initiated")
        print(f"🔗 Validation URL: {validation['validationUrl']}")
        print(f"🔑 Consumer Key: {validation['consumerKey']}")
        print()
        print("📋 Next steps:")
        print("1. Open the validation URL in your browser")
        print("2. Log in to your OVH account")
        print("3. Authorize the application")
        print("4. Update your ovh.conf with the new consumer key")
        print()
        print("Opening validation URL in browser...")

        try:
            webbrowser.open(validation['validationUrl'])
        except:
            print("⚠️  Could not open browser automatically")
            print(f"   Please manually open: {validation['validationUrl']}")

        print()
        print("Updated ovh.conf should look like:")
        print("[default]")
        print("endpoint=ovh-ca")
        print("application_key=3a1dc93e151df1d9")
        print("application_secret=2a5c04587df7b1944adf80d0bd4fd97e")
        print(f"consumer_key={validation['consumerKey']}")

        return validation['consumerKey']

    except Exception as e:
        print(f"❌ Consumer key validation failed: {e}")
        return None

def main():
    """Main validation function"""
    consumer_key = validate_consumer_key()

    if consumer_key:
        print(f"\n✅ New consumer key generated: {consumer_key}")
        print("⚠️  Remember to validate it via the URL above!")
    else:
        print("\n❌ Failed to generate consumer key")
        sys.exit(1)

if __name__ == "__main__":
    main()