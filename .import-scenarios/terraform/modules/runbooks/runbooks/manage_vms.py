#!/usr/bin/env python3
"""
Start/stop/status Azure VMs, optionally filtered by Environment tag.
Runtime: Python 3.10 | Requires: azure-identity, azure-mgmt-compute

Env vars:
  ACTION      - start | stop | status (default: status)
  ENVIRONMENT - filter by Environment tag value (optional)
"""

import sys
import os
from datetime import datetime


ACTION      = os.environ.get('ACTION', 'status').lower()
ENVIRONMENT = os.environ.get('ENVIRONMENT', '')


def main():
    print(f"Manage-VMs | {sys.version.split()[0]} | {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC")
    print(f"Action: {ACTION} | Filter: {ENVIRONMENT or 'all'}")
    print()

    from azure.identity import ManagedIdentityCredential
    from azure.mgmt.compute import ComputeManagementClient
    from azure.mgmt.resource import SubscriptionClient

    credential = ManagedIdentityCredential()
    sub = next(SubscriptionClient(credential).subscriptions.list())
    sub_id = sub.subscription_id
    print(f"Subscription: {sub.display_name}")
    print()

    cc = ComputeManagementClient(credential, sub_id)
    vms = list(cc.virtual_machines.list_all())

    if ENVIRONMENT:
        vms = [v for v in vms if v.tags and v.tags.get('Environment', '').lower() == ENVIRONMENT.lower()]
        print(f"Filtered to {len(vms)} VM(s) with Environment='{ENVIRONMENT}'")

    if not vms:
        print("No VMs found.")
        return

    running = stopped = other = 0

    for vm in vms:
        rg = vm.id.split('/')[4]
        iv = cc.virtual_machines.instance_view(rg, vm.name)
        power_state = next(
            (s.code.replace('PowerState/', '') for s in iv.statuses if s.code.startswith('PowerState/')),
            'unknown'
        )

        if power_state == 'running':
            running += 1
        elif power_state in ('deallocated', 'stopped'):
            stopped += 1
        else:
            other += 1

        env_tag = (vm.tags or {}).get('Environment', 'not set')
        print(f"  {vm.name} | {vm.hardware_profile.vm_size} | {power_state} | env={env_tag}")

        if ACTION == 'start' and power_state != 'running':
            try:
                cc.virtual_machines.begin_start(rg, vm.name)
                print(f"    -> start issued")
            except Exception as e:
                print(f"    -> start failed: {e}")
        elif ACTION == 'stop' and power_state == 'running':
            try:
                cc.virtual_machines.begin_deallocate(rg, vm.name)
                print(f"    -> stop/deallocate issued")
            except Exception as e:
                print(f"    -> stop failed: {e}")

    print()
    print(f"Total: {len(vms)} | Running: {running} | Stopped: {stopped} | Other: {other}")


if __name__ == "__main__":
    main()
