# Wazuh Custom Rule Examples

**Detect PowerShell with encoded command (from Sysmon Event ID 1):**
```xml
<group name="windows,sysmon,malware,">
  <rule id="100100" level="10">
    <if_group>sysmon_event1</if_group>
    <field name="win.eventdata.image" type="pcre2">(?i)powershell\.exe</field>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)(-encodedcommand|-enc\s)</field>
    <description>PowerShell executed with encoded command argument</description>
    <mitre>
      <id>T1059.001</id>
    </mitre>
    <group>attack,execution,</group>
  </rule>
</group>
```

**Detect Office application spawning scripting engines:**
```xml
<group name="windows,sysmon,malware,">
  <rule id="100101" level="12">
    <if_group>sysmon_event1</if_group>
    <field name="win.eventdata.parentImage" type="pcre2">(?i)(winword|excel|outlook|powerpnt)\.exe</field>
    <field name="win.eventdata.image" type="pcre2">(?i)(cmd|powershell|wscript|cscript|mshta|regsvr32)\.exe</field>
    <description>Office application spawned scripting engine - possible macro execution</description>
    <mitre>
      <id>T1566.001</id>
    </mitre>
    <group>attack,initial_access,</group>
  </rule>
</group>
```

**Detect shadow copy deletion (ransomware pre-step):**
```xml
<group name="windows,ransomware,">
  <rule id="100200" level="14">
    <if_group>sysmon_event1</if_group>
    <field name="win.eventdata.commandLine" type="pcre2">(?i)(vssadmin.*delete.*shadows|wmic.*shadowcopy.*delete|bcdedit.*/set.*recoveryenabled)</field>
    <description>Shadow copy deletion attempt - possible ransomware pre-execution</description>
    <mitre>
      <id>T1490</id>
    </mitre>
    <group>attack,impact,ransomware,</group>
  </rule>
</group>
```
