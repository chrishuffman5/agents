# Vault Agent Full Configuration Example

Sidecar/daemon that handles auth, token renewal, and secret templating. Eliminates Vault auth logic from applications.

```hcl
# vault-agent-config.hcl
vault {
  address = "https://vault.example.com"
}

auto_auth {
  method "kubernetes" {
    mount_path = "auth/kubernetes"
    config = {
      role = "my-app"
    }
  }

  sink "file" {
    config = {
      path = "/vault/secrets/.vault-token"
    }
  }
}

template {
  source      = "/vault/templates/config.tpl"
  destination = "/vault/secrets/config.txt"
  command     = "sh -c 'kill -HUP $(cat /app/app.pid)'"  # reload app on change
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address     = "127.0.0.1:8200"
  tls_disable = true
}
```

Template syntax (uses Go templates with Vault functions):

```
{{ with secret "secret/data/myapp/config" }}
DB_PASSWORD={{ .Data.data.db_password }}
API_KEY={{ .Data.data.api_key }}
{{ end }}
```
