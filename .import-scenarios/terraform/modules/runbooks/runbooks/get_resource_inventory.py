#!/usr/bin/env python3
"""
Azure resource inventory.
Runtime: Python 3.10 | Requires: azure-identity, azure-mgmt-resource
"""

import sys
from datetime import datetime
from collections import defaultdict


def main():
    print(f"Get-ResourceInventory | {sys.version.split()[0]} | {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC")
    print()

    from azure.identity import ManagedIdentityCredential
    from azure.mgmt.resource import ResourceManagementClient, SubscriptionClient

    credential = ManagedIdentityCredential()
    sub_client = SubscriptionClient(credential)
    subscription = next(sub_client.subscriptions.list())
    sub_id = subscription.subscription_id
    print(f"Subscription: {subscription.display_name} ({sub_id})")
    print()

    rc = ResourceManagementClient(credential, sub_id)
    resources = list(rc.resources.list())
    rgs = list(rc.resource_groups.list())
    print(f"{len(resources)} resources across {len(rgs)} resource groups")
    print()

    # By type
    by_type = defaultdict(list)
    for r in resources:
        by_type[r.type].append(r)
    sorted_types = sorted(by_type.items(), key=lambda x: len(x[1]), reverse=True)

    print("By type (top 15):")
    for rtype, items in sorted_types[:15]:
        name = rtype.split('/')[-1]
        pct = len(items) / len(resources) * 100
        print(f"  {name:<30} {len(items):>4}  ({pct:.1f}%)")
    print()

    # By location
    by_loc = defaultdict(int)
    for r in resources:
        by_loc[r.location or 'global'] += 1
    print("By location:")
    for loc, count in sorted(by_loc.items(), key=lambda x: x[1], reverse=True):
        print(f"  {loc:<25} {count:>4}")
    print()

    # Tag coverage
    required_tags = ['Environment', 'Owner', 'CostCenter']
    print("Tag coverage:")
    for tag in required_tags:
        tagged = sum(1 for r in resources if r.tags and tag in r.tags)
        pct = tagged / len(resources) * 100 if resources else 0
        status = "OK" if pct >= 80 else ("warn" if pct >= 50 else "LOW")
        print(f"  [{status}] {tag:<15} {tagged}/{len(resources)} ({pct:.1f}%)")
    print()

    # Resource groups
    by_rg = defaultdict(list)
    for r in resources:
        rg_name = r.id.split('/')[4] if r.id else 'unknown'
        by_rg[rg_name].append(r)

    print("Resource groups:")
    for rg in sorted(rgs, key=lambda x: len(by_rg.get(x.name, [])), reverse=True):
        items = by_rg.get(rg.name, [])
        types = len(set(r.type for r in items))
        print(f"  {rg.name:<40} {len(items):>3} resources  {types} types  {rg.location}")


if __name__ == "__main__":
    main()
