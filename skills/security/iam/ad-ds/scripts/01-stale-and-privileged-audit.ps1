# Purpose:        AD hygiene audit - stale enabled accounts, never-expiring passwords, and privileged group membership
# Applies to:     Active Directory Domain Services (RSAT ActiveDirectory module; read access to the domain)
# Read-only:      yes
# Inputs:         none (targets the current domain)
# Interpretation: Stale enabled accounts are the attacker's favorite foothold (nobody notices their logons). Password-
#                 never-expires on USER accounts (vs managed service accounts) is a policy gap. Privileged group members
#                 should be a short, known list - every surprise name here is a finding; nested groups hide sprawl,
#                 hence -Recursive. adminCount=1 on accounts NO LONGER privileged = stale AdminSDHolder protection
#                 (breaks delegation and h