# Falco Plugin Examples: AWS CloudTrail and Kubernetes Audit

### AWS CloudTrail Plugin

Detects threats in AWS CloudTrail logs:

**Setup:**
```yaml
# falco.yaml
plugins:
  - name: cloudtrail
    library_path: libcloudtrail.so
    init_config:
      sqsQueueUrl: "https://sqs.us-east-1.amazonaws.com/123456789012/my-cloudtrail-sqs"
      # Falco polls SQS; CloudTrail delivers to S3 + SNS + SQS
    open_params: ""

load_plugins:
  - cloudtrail
  - json  # needed for field extraction

# falco.yaml: add cloudtrail as event source
rules_files:
  - /etc/falco/aws_cloudtrail_rules.yaml
```

**CloudTrail rule fields:**
```yaml
# Fields available in CloudTrail rules
ct.id              # CloudTrail event ID
ct.name            # API call name (e.g., "ConsoleLogin", "CreateUser")
ct.error           # Error code (if call failed)
ct.user            # IAM user/role making the call
ct.usertype        # IAMUser, AssumedRole, Root, AWSService, etc.
ct.userid          # Account ID
ct.userarn         # Full ARN of caller
ct.region          # AWS region
ct.srcip           # Source IP of API call
ct.useragent       # User agent (boto3, AWS Console, CLI)
ct.request.param[name]    # Request parameter
ct.response.element[name] # Response element
```

**Example CloudTrail rules:**
```yaml
- rule: Disable CloudTrail Logging
  desc: An IAM entity disabled CloudTrail logging — possible defense evasion
  condition: >
    ct.name = "StopLogging"
    and not ct.usertype = "AWSService"
  output: >
    CloudTrail logging disabled
    (user=%ct.user src=%ct.srcip region=%ct.region)
  priority: CRITICAL
  source: aws_cloudtrail

- rule: Create IAM User
  desc: A new IAM user was created
  condition: >
    ct.name = "CreateUser"
    and ct.error = ""          # successful call only
    and not ct.usertype = "AWSService"
  output: >
    IAM user created
    (creator=%ct.user new_user=%ct.request.param[userName] region=%ct.region)
  priority: NOTICE
  source: aws_cloudtrail

- rule: Root Account Activity
  desc: The root account was used — should never happen in well-governed environments
  condition: >
    ct.usertype = "Root"
    and not ct.name startswith "STS"
  output: >
    Root account activity detected
    (action=%ct.name src=%ct.srcip region=%ct.region)
  priority: CRITICAL
  source: aws_cloudtrail
```

### Kubernetes Audit Plugin

For analyzing Kubernetes API server audit logs:

```yaml
- rule: Exec in Production Namespace
  desc: kubectl exec or attach used in production namespace
  condition: >
    kaudit.verb in (create)
    and kaudit.resource.subresource in (exec, attach)
    and kaudit.target.namespace = "production"
    and not kaudit.user.name in (allowed_kubectl_exec_users)
  output: >
    kubectl exec in production
    (user=%kaudit.user.name pod=%kaudit.target.name ns=%kaudit.target.namespace)
  priority: WARNING
  source: k8s_audit
```
