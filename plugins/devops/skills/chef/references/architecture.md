# Chef Architecture

## Chef Client Run

```
chef-client starts
        │
        ▼
┌──────────────┐
│  Build Node  │  Ohai collects system attributes (OS, IP, memory, etc.)
│  Object      │
└──────┬───────┘
       │
┌──────▼───────┐
│  Authenticate │  Client key + node name → Chef Server
└──────┬───────┘
       │
┌──────▼───────┐
│  Synchronize  │  Download cookbooks, roles, environments from server
│  Cookbooks    │
└──────┬───────┘
       │
┌──────▼───────┐
│  Compile      │  Load recipes, build resource collection
│  Resources    │
└──────┬───────┘
       │
┌──────▼───────┐
│  Converge     │  Execute each resource (test → repair pattern)
└──────┬───────┘
       │
┌──────▼───────┐
│  Report       │  Send run status to Chef Server (success/failure, changes)
└──────────────┘
```

### Ohai

Ohai is Chef's system profiler — it collects automatic attributes:

| Plugin | Data Collected |
|---|---|
| `os` | Operating system family, version, architecture |
| `network` | Interfaces, IPs, MAC addresses |
| `memory` | Total, free, swap |
| `cpu` | Count, model, speed |
| `filesystem` | Mounts, sizes, usage |
| `cloud` | EC2, Azure, GCP metadata |
| `hostname` | FQDN, hostname |

Access via `node['platform']`, `node['ipaddress']`, `node['memory']['total']`.

## Chef Server Components

| Component | Purpose |
|---|---|
| **Erchef** | API server (Erlang) — handles all client requests |
| **PostgreSQL** | Stores cookbooks, node data, roles, environments |
| **Elasticsearch/Solr** | Search index for node attributes |
| **Bookshelf** | Cookbook file storage (S3-compatible) |
| **nginx** | HTTPS front-end, load balancer |

## Resource Model

### Resource Execution (Test and Repair)

```ruby
# Each resource follows the test-and-repair pattern:
package 'nginx' do
  action :install
end

# 1. TEST: Is nginx installed?
# 2. If yes: no-op (resource is "up to date")
# 3. If no: REPAIR — install nginx
# 4. Report: "installed package nginx" or "up to date"
```

### Custom Resources

```ruby
# cookbooks/myapp/resources/deploy.rb
unified_mode true

property :version, String, required: true
property :deploy_path, String, default: '/opt/myapp'

action :deploy do
  directory new_resource.deploy_path do
    owner 'app'
    recursive true
  end

  remote_file "#{new_resource.deploy_path}/app-#{new_resource.version}.tar.gz" do
    source "https://releases.example.com/app-#{new_resource.version}.tar.gz"
    notifies :run, 'execute[extract-app]', :immediately
  end

  execute 'extract-app' do
    command "tar xzf app-#{new_resource.version}.tar.gz"
    cwd new_resource.deploy_path
    action :nothing
  end
end
```

## Habitat

Chef Habitat packages applications with their runtime dependencies:

```bash
# Build a Habitat package
hab pkg build .

# Run the package
hab svc load myorg/myapp

# Habitat supervisor manages the service lifecycle
# Supports rolling updates, health checks, configuration binding
```

Habitat is complementary to Chef Infra — Chef configures the OS, Habitat packages the application.
