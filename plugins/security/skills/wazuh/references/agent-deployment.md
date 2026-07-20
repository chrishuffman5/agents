# Wazuh Agent Deployment

### Linux Agent Installation

```bash
# Import Wazuh GPG key and add repository (RHEL/CentOS/Amazon Linux)
rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
cat > /etc/yum.repos.d/wazuh.repo << 'EOF'
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-$releasever - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF

yum install wazuh-agent

# Configure manager address
sed -i 's/MANAGER_IP/<manager_ip>/' /var/ossec/etc/ossec.conf

# Register and start
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent

# Debian/Ubuntu
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update && apt-get install wazuh-agent

sed -i 's/MANAGER_IP/<manager_ip>/' /var/ossec/etc/ossec.conf
systemctl daemon-reload && systemctl enable wazuh-agent && systemctl start wazuh-agent
```

### Windows Agent Installation

```powershell
# Download MSI from packages.wazuh.com
# Install with manager address and agent group
msiexec.exe /i wazuh-agent-4.x.x-1.msi /quiet `
  WAZUH_MANAGER="wazuh-manager.corp.com" `
  WAZUH_AGENT_NAME="WORKSTATION001" `
  WAZUH_AGENT_GROUP="windows-workstations"

# Verify
Get-Service WazuhSvc | Select Status
# Check logs
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 50
```

### macOS Agent Installation

```bash
# Download pkg from packages.wazuh.com
sudo installer -pkg wazuh-agent-4.x.x-1.pkg -target /

# Configure manager
/Library/Ossec/bin/agent-auth -m <manager_ip> -A "macbook-001"

# Start agent
sudo /Library/Ossec/bin/wazuh-control start
```
