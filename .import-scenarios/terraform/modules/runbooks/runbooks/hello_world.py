#!/usr/bin/env python3
"""
Basic Python 3.10 runbook - authenticates with managed identity and prints subscription info.
Runtime: Python 3.10 | Requires: azure-identity, azure-mgmt-resource
"""

import sys
import os
from datetime import datetime


def main():
    print(f"Hello-World-Python | {sys.version.split()[0]} | {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC")
    print()

    from azure.identity import ManagedIdentityCredential
    from azure.mgmt.resource import SubscriptionClient

    credential = ManagedIdentityCredential()
    sub_client = SubscriptionClient(credential)

    subs = list(sub_client.subscriptions.list())
    print(f"Accessible subscriptions: {len(subs)}")
    for sub in subs:
        print(f"  {sub.display_name} ({sub.subscription_id}) - {sub.state}")

    print()
    print("Environment (non-sensitive):")
    for var in ['AUTOMATION_ASSET_ACCOUNTID', 'COMPUTERNAME', 'OS']:
        print(f"  {var}: {os.environ.get(var, 'not set')}")


if __name__ == "__main__":
    main()
