# Remove Rippling MDM

This script is intended to remove be pushed by Rippling MDM to Windows devices in order to remove all Rippling management from the device in preparation for migration to a different MDM solution. 

## What it does
There are three main things that this script does:
    1. Remove the Rippling Agent and enrollment keys
    2. Promote any standard local users to administrators so that they may enroll in the new MDM
    3. Decrypt BitLocker so that it can be re-enabled and the recovery key escrowed to the new MDM

## What it doesn't do
    - Remove the RipplingAdministrator account
