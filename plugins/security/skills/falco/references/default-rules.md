# Falco Default Rules Reference

Falco ships 70+ default rules in `/etc/falco/falco_rules.yaml`. Key categories:

**Container / Process:**
- `Terminal shell in container` — bash/sh/zsh spawned interactively
- `Launch Suspicious Network Tool in Container` — nmap, netcat, socat, etc.
- `Launch Package Management Process in Container` — apt, yum, apk (post-deploy install)
- `Modify binary dirs` — writes to /bin, /sbin, /usr/bin, /usr/sbin
- `Write below root` — writes to unexpected root directories
- `Drift outside specific directory` — process writes outside its designated writable area

**Sensitive file access:**
- `Read sensitive file` — /etc/shadow, /etc/sudoers, cloud credential files
- `Read SSH information` — SSH key files, authorized_keys
- `Clear Log Activities` — deleting or truncating log files
- `Create Hardlink Over Sensitive Files` — creating hardlinks to sensitive files

**Privilege escalation:**
- `Set Setuid or Setgid bit` — chmod to set SUID/SGID
- `Change thread namespace` — setns syscall (container escape vector)
- `Mount Sensitive Host System Directories` — mounting /etc, /root, /var from host

**Kubernetes:**
- `K8s Secret Get or List` — secret access from unexpected service accounts
- `RBAC Assessment Namespace` — querying RBAC resources from non-admin pods
- `Create Privileged Pod` — via K8s API (K8s Audit plugin)

**Network:**
- `Outbound Connection to C2 Servers` — connects to known C2 IP list
- `Unexpected UDP Traffic` — DNS to non-standard resolvers
- `Contact cloud metadata service from container` — IMDS access (169.254.169.254)
