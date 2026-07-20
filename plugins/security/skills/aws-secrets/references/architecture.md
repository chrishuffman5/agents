# AWS Secrets Manager + KMS — Architecture Internals

Deep reference covering Secrets Manager rotation Lambda contract, versioning mechanics, multi-region replication, KMS key hierarchy, grants vs. key policies, envelope encryption, and multi-region key architecture.

---

## Secrets Manager Internals

### Secret Storage Architecture

Each secret in Secrets Manager consists of:

```
Secret (logical container)
├── ARN: arn:aws:secretsmanager:region:account:secret:name-RandomSuffix
├── Metadata: name, description, rotation config, tags, resource policy
└── Versions (encrypted blobs)
    ├── Version ID A → Staging labels: [AWSPREVIOUS]
    ├── Version ID B → Staging labels: [AWSCURRENT]
    └── Version ID C → Staging labels: [AWSPENDING]
```

**Staging labels** are movable tags on versions. A version can have multiple labels. When rotation completes:
1. `AWSPENDING` label moves to the new version (now `AWSCURRENT`)
2. Old `AWSCURRENT` becomes `AWSPREVIOUS`
3. Old `AWSPREVIOUS` label is removed (version retained, just no staging label)

Versions without staging labels are retained for 24 hours by default, then deleted during cleanup.

### Encryption at Rest

Secrets Manager encrypts every secret value using AES-256-GCM via the specified KMS key. The encryption is envelope encryption:

```
1. Secrets Manager calls kms:GenerateDataKey with the key ID
2. KMS returns: Plaintext DEK + CiphertextBlob (encrypted DEK)
3. SM encrypts the secret value with the Plaintext DEK
4. SM stores: { encrypted_secret_value, CiphertextBlob } in its internal store
5. Plaintext DEK is never persisted

To decrypt:
1. SM calls kms:Decrypt with the CiphertextBlob
2. KMS returns Plaintext DEK
3. SM decrypts the secret value
4. Returns plaintext secret to caller
```

The calling principal must have both `secretsmanager:GetSecretValue` AND `kms:Decrypt` permission on the KMS key. Denying `kms:Decrypt` prevents secret access even with full SM permissions.

---

## Rotation Lambda — 4-Step Contract

The rotation Lambda function implements a strict 4-step protocol invoked by Secrets Manager.

### createSecret

**Purpose**: Generate the new credential and store it as `AWSPENDING`

```python
def create_secret(client, arn, token):
    # Check if AWSPENDING already exists (idempotency)
    try:
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage='AWSPENDING')
        logger.info("Secret already exists for token %s, skipping.", token)
        return
    except client.exceptions.ResourceNotFoundException:
        pass
    
    # Get current secret to use as template
    current = json.loads(
        client.get_secret_value(SecretId=arn, VersionStage='AWSCURRENT')['SecretString']
    )
    
    # Generate new password
    new_password = client.get_random_password(
        PasswordLength=32,
        ExcludePunctuation=True
    )['RandomPassword']
    
    current['password'] = new_password
    
    # Store as AWSPENDING
    client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=json.dumps(current),
        VersionStages=['AWSPENDING']
    )
```

### setSecret

**Purpose**: Apply the new credential to the target service (e.g., update database password)

```python
def set_secret(client, arn, token):
    # Retrieve AWSPENDING secret
    pending = json.loads(
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage='AWSPENDING')['SecretString']
    )
    
    # Connect to DB using CURRENT credentials (or use master secret for rotation)
    current = json.loads(
        client.get_secret_value(SecretId=arn, VersionStage='AWSCURRENT')['SecretString']
    )
    
    # Update password in the database
    conn = psycopg2.connect(
        host=current['host'], port=current['port'],
        user=current['username'], password=current['password'],
        dbname=current['dbname']
    )
    with conn.cursor() as cur:
        cur.execute(
            "ALTER USER %s WITH PASSWORD %%s" % pending['username'],
            (pending['password'],)
        )
    conn.commit()
```

### testSecret

**Purpose**: Validate the new credential actually works before finalizing

```python
def test_secret(client, arn, token):
    pending = json.loads(
        client.get_secret_value(SecretId=arn, VersionId=token, VersionStage='AWSPENDING')['SecretString']
    )
    
    # Actually connect with new credentials
    conn = psycopg2.connect(
        host=pending['host'], port=pending['port'],
        user=pending['username'], password=pending['password'],
        dbname=pending['dbname']
    )
    conn.close()
    # If this raises, rotation is aborted and AWSCURRENT remains valid
```

### finishSecret

**Purpose**: Promote `AWSPENDING` to `AWSCURRENT`

```python
def finish_secret(client, arn, token):
    metadata = client.describe_secret(SecretId=arn)
    
    # Find current version to demote
    current_version = None
    for version_id, stages in metadata['VersionIdsToStages'].items():
        if 'AWSCURRENT' in stages:
            if version_id == token:
                logger.info("Version %s is already AWSCURRENT.", token)
                return
            current_version = version_id
            break
    
    # Move labels
    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage='AWSCURRENT',
        MoveToVersionId=token,
        RemoveFromVersionId=current_version
    )
```

### Rotation Error Handling

If any step throws an exception:
- Rotation is marked as failed
- `AWSCURRENT` label remains on the old version (no disruption to running apps)
- Secrets Manager retries rotation up to the next scheduled interval
- CloudWatch metric `RotationSucceeded` / `RotationFailed` published

---

## KMS Key Hierarchy

### Conceptual Model

```
AWS KMS Root Keys (HSM-backed, never leave AWS KMS)
  └── Customer Master Key (CMK) — logical key you manage
        ├── Key Material (active) — used for new encryptions
        ├── Key Material (rotated v1) — retained for decryption
        └── Key Material (rotated v2) — retained for decryption

Application
  ↓ calls kms:GenerateDataKey(CMK)
  ← Receives: DEK plaintext + DEK ciphertext
  
  Data Encryption Key (DEK) — unique per object/session
    ├── Plaintext DEK — encrypt data, then zero from memory
    └── Encrypted DEK — stored with ciphertext, never on its own
```

KMS keys themselves are encrypted at rest using a separate layer of KMS-internal keys (fleet root keys stored in HSMs). The CMK you manage is a logical reference to this material.

### Key Policy vs. IAM Policy Interaction

KMS uses a dual-authorization model. A principal needs permission from BOTH layers:

```
Allow = Key Policy ALLOWS + (IAM policy ALLOWS or no IAM constraint)
Deny  = Key Policy DENIES OR IAM policy DENIES
```

**Critical**: If the key policy does NOT include `"Principal": {"AWS": "arn:aws:iam::ACCOUNT:root"}` with `"Action": "kms:*"`, then IAM policies have NO effect on the key. This is the "lockout" scenario — the only way in is to contact AWS Support.

Default key policy always includes the account root statement:
```json
{
  "Sid": "Enable IAM User Permissions",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::123456789012:root"},
  "Action": "kms:*",
  "Resource": "*"
}
```

With this in the key policy, IAM policies attached to users/roles control access normally.

### Grants vs. Key Policy

| Dimension | Key Policy | Grants |
|---|---|---|
| Modification | Requires key admin (replace full policy) | Any principal with `kms:CreateGrant` |
| Scope | Full key | Specific operations only |
| Delegation | Cannot delegate beyond own permissions | Grantee can retire (but not revoke) |
| Temporary | Must modify policy to remove | Retire grant when done |
| Auditability | Policy version history in CloudTrail | Each grant is a CloudTrail event |
| Use when | Persistent, broad access (services, admins) | Temporary, delegation, automated processes |

**Grants for Secrets Manager rotation**:
When SM rotates a secret, it creates a temporary grant allowing the rotation Lambda's execution role to use the key. The grant is retired after rotation completes.

### ViaService Condition

Restrict key usage to specific AWS services only:

```json
{
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::123456789:role/AppRole"},
  "Action": ["kms:GenerateDataKey", "kms:Decrypt"],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "kms:ViaService": [
        "secretsmanager.us-east-1.amazonaws.com",
        "s3.us-east-1.amazonaws.com"
      ]
    }
  }
}
```

This allows AppRole to use the key only when the request is made by Secrets Manager or S3 on the role's behalf — not direct KMS API calls.

---

## Multi-Region Key Architecture

### Key Architecture

```
Primary Region (us-east-1)
  mrk-abc123 (Key ID prefix "mrk-" indicates multi-region)
  ARN: arn:aws:kms:us-east-1:123456789:key/mrk-abc123

Replica Region (eu-west-1)
  mrk-abc123 (same key ID, different region in ARN)
  ARN: arn:aws:kms:eu-west-1:123456789:key/mrk-abc123
```

Key properties:
- Same key material in both regions (replicated by KMS)
- Different ARNs but same key ID suffix
- Each region has its own key policy (independent)
- Data encrypted in primary can be decrypted in replica without cross-region API call

### Rotation of Multi-Region Keys

When you rotate the primary key:
- New key material is generated in the primary region
- New material is replicated to all replica regions
- Old material is retained in all regions for decryption

### Secrets Manager + Multi-Region Keys Pattern

```
us-east-1:
  Secret: prod/myapp/db-creds (primary)
  Encrypted with: mrk-abc123 (primary key)

eu-west-1:
  Secret: prod/myapp/db-creds (replica)
  Encrypted with: mrk-abc123 (replica key)
  
Application in eu-west-1:
  → GetSecretValue → calls eu-west-1 SM endpoint
  → SM calls kms:Decrypt → eu-west-1 KMS (local, low latency)
  → No cross-region calls needed
```

Without multi-region keys, the replica SM would call back to the primary region's KMS for decryption — adding latency and creating a cross-region dependency.

---

## IAM Policies for Secrets Manager

### Least-Privilege Policy for an Application

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GetSecrets",
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789:secret:prod/myapp/*"
    },
    {
      "Sid": "DecryptWithCMK",
      "Effect": "Allow",
      "Action": "kms:Decrypt",
      "Resource": "arn:aws:kms:us-east-1:123456789:key/mrk-abc123",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "secretsmanager.us-east-1.amazonaws.com"
        }
      }
    }
  ]
}
```

### Rotation Lambda IAM Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetRandomPassword"
      ],
      "Resource": "arn:aws:secretsmanager:*:123456789:secret:prod/*"
    },
    {
      "Effect": "Allow",
      "Action": ["kms:GenerateDataKey", "kms:Decrypt"],
      "Resource": "arn:aws:kms:us-east-1:123456789:key/mrk-abc123"
    },
    {
      "Effect": "Allow",
      "Action": ["ec2:CreateNetworkInterface", "ec2:DeleteNetworkInterface",
                 "ec2:DescribeNetworkInterfaces"],
      "Resource": "*"
      // Required if Lambda runs in VPC for private DB access
    }
  ]
}
```

---

## CloudTrail Audit Events

Key CloudTrail events for monitoring:

| Event | Source | Indicates |
|---|---|---|
| `GetSecretValue` | secretsmanager | Secret accessed |
| `PutSecretValue` | secretsmanager | Secret updated |
| `RotateSecret` | secretsmanager | Rotation triggered |
| `DeleteSecret` | secretsmanager | Secret deleted (30-day recovery window default) |
| `Decrypt` | kms | KMS decrypt operation (every GetSecretValue triggers this) |
| `GenerateDataKey` | kms | Encryption operation |
| `DisableKey` | kms | Key disabled (all dependent secrets inaccessible) |
| `ScheduleKeyDeletion` | kms | Key deletion scheduled |

Alert on:
- `DeleteSecret` without prior approval ticket correlation
- `DisableKey` or `ScheduleKeyDeletion` on production keys
- `GetSecretValue` from unexpected IAM principals or IP ranges
- Failed rotation (`RotationSucceeded=false`)
