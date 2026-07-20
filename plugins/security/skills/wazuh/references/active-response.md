# Wazuh Active Response Details

### Built-in Active Response Scripts

| Script | Platform | Function |
|---|---|---|
| `firewall-drop` | Linux | Block IP with iptables |
| `host-deny` | Linux | Add to /etc/hosts.deny |
| `disable-account` | Windows | Disable user account |
| `netsh` | Windows | Block IP with Windows firewall |
| `route-null` | Linux | Null route an IP |

### Configuring Active Response (Manager ossec.conf)

```xml
<!-- Define the active response command -->
<command>
  <name>firewall-drop</name>
  <executable>firewall-drop</executable>
  <timeout_allowed>yes</timeout_allowed>
</command>

<!-- Bind command to rule firing conditions -->
<active-response>
  <command>firewall-drop</command>
  <location>local</location>      <!-- local = agent, server = manager, defined-agent = specific agent -->
  <rules_id>100002</rules_id>     <!-- Fire on this rule ID -->
  <timeout>600</timeout>          <!-- Block for 600 seconds -->
</active-response>
```

### Custom Active Response Script

```bash
#!/bin/bash
# /var/ossec/active-response/bin/custom_block.sh
# Must be executable: chmod +x /var/ossec/active-response/bin/custom_block.sh

ACTION=$1        # add or delete
USER=$2
IP=$3
ALERT_ID=$4
RULE_ID=$5

if [ "$ACTION" = "add" ]; then
    iptables -I INPUT -s "$IP" -j DROP
    logger "Wazuh Active Response: Blocked IP $IP for rule $RULE_ID"
elif [ "$ACTION" = "delete" ]; then
    iptables -D INPUT -s "$IP" -j DROP
    logger "Wazuh Active Response: Unblocked IP $IP"
fi
```
