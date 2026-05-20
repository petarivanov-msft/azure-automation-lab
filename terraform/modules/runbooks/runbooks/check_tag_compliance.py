#!/usr/bin/env python3
"""
Check Azure resources for tag compliance.
Defaults to checking: Environment, Owner, CostCenter
Runtime: Python 3.10 | Requires: azure-identity, azure-mgmt-resource
"""

import sys
from datetime import datetime
from collections import defaultdict

REQUIRED_TAGS = ['Environment', 'Owner', 'CostCenter']


def main():
    print(f"Check-TagCompliance | {sys.version.split()[0]} | {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC")
    print(f"Required tags: {', '.join(REQUIRED_TAGS)}")
    print()

    from azure.identity import ManagedIdentityCredential
    from azure.mgmt.resource import ResourceManagementClient, SubscriptionClient

    credential = ManagedIdentityCredential()
    sub = next(SubscriptionClient(credential).subscriptions.list())
    sub_id = sub.subscription_id
    print(f"Subscription: {sub.display_name}")
    print()

    rc = ResourceManagementClient(credential, sub_id)
    resources = list(rc.resources.list())

    if not resources:
        print("No resources found.")
        return

    print(f"Found {len(resources)} resources")
    print()

    # Per-tag compliance
    compliance_results = {}
    for tag in REQUIRED_TAGS:
        compliant = [r for r in resources if r.tags and r.tags.get(tag)]
        non_compliant = [r for r in resources if not (r.tags and r.tags.get(tag))]
        pct = len(compliant) / len(resources) * 100
        status = "OK" if pct >= 90 else ("warn" if pct >= 70 else ("low" if pct >= 50 else "CRIT"))
        compliance_results[tag] = {
            'compliant': len(compliant),
            'non_compliant': non_compliant,
            'pct': pct
        }
        print(f"  [{status}] {tag:<15} {len(compliant)}/{len(resources)} ({pct:.1f}%)")

    print()

    # Overall: resources with ALL required tags
    fully_compliant = sum(
        1 for r in resources
        if all(r.tags and r.tags.get(t) for t in REQUIRED_TAGS)
    )
    overall = fully_compliant / len(resources) * 100
    print(f"Overall (all tags present): {fully_compliant}/{len(resources)} ({overall:.1f}%)")
    print()

    # Non-compliant resources per tag (top 10)
    for tag in REQUIRED_TAGS:
        result = compliance_results[tag]
        if result['non_compliant']:
            print(f"Missing '{tag}' ({len(result['non_compliant'])} resources):")
            for r in result['non_compliant'][:10]:
                rtype = r.type.split('/')[-1]
                rg = r.id.split('/')[4] if r.id else 'unknown'
                print(f"  {r.name} ({rtype}) in {rg}")
            if len(result['non_compliant']) > 10:
                print(f"  ... and {len(result['non_compliant']) - 10} more")
            print()

    # Compliance by resource type
    by_type = defaultdict(lambda: {'total': 0, 'compliant': 0})
    for r in resources:
        rt = r.type.split('/')[-1]
        by_type[rt]['total'] += 1
        if all(r.tags and r.tags.get(t) for t in REQUIRED_TAGS):
            by_type[rt]['compliant'] += 1

    print("By resource type (top 15):")
    sorted_types = sorted(
        by_type.items(),
        key=lambda x: x[1]['compliant'] / x[1]['total'] if x[1]['total'] else 0,
        reverse=True
    )
    for rt, counts in sorted_types[:15]:
        pct = counts['compliant'] / counts['total'] * 100
        status = "OK" if pct >= 90 else ("warn" if pct >= 70 else "LOW")
        print(f"  [{status}] {rt:<30} {counts['compliant']:>3}/{counts['total']:<3} ({pct:.1f}%)")

    print()
    if overall < 50:
        print("Tag compliance below 50% - consider Azure Policy to enforce required tags.")


if __name__ == "__main__":
    main()
