# AWS CLI Commands by Service

Complete command reference with real examples.

---

## IAM

```bash
# Users
aws iam create-user --user-name alice --tags Key=Team,Value=platform
aws iam list-users --query 'Users[].{Name:UserName,Created:CreateDate}' -o table
aws iam create-login-profile --user-name alice --password "Temp@12345!" --password-reset-required
aws iam delete-user --user-name alice

# Groups
aws iam create-group --group-name developers
aws iam add-user-to-group --user-name alice --group-name developers
aws iam attach-group-policy --group-name developers --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
aws iam get-group --group-name developers --query 'Users[].UserName' -o text

# Roles
aws iam create-role --role-name lambda-role --assume-role-policy-document '{
  "Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
aws iam list-roles --query 'Roles[?contains(RoleName,`lambda`)].{Name:RoleName,Arn:Arn}' -o table

# Policies
aws iam create-policy --policy-name s3-read --policy-document '{
  "Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:ListBucket"],
  "Resource":["arn:aws:s3:::my-bucket","arn:aws:s3:::my-bucket/*"]}]}'
aws iam attach-role-policy --role-name lambda-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam list-attached-role-policies --role-name lambda-role --query 'AttachedPolicies[].{Name:PolicyName,Arn:PolicyArn}' -o table

# Inline policies
aws iam put-role-policy --role-name my-role --policy-name inline-s3 --policy-document '{
  "Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"s3:PutObject","Resource":"arn:aws:s3:::my-bucket/*"}]}'

# Access keys
aws iam create-access-key --user-name alice --query 'AccessKey.[AccessKeyId,SecretAccessKey]' -o text
aws iam list-access-keys --user-name alice
aws iam update-access-key --user-name alice --access-key-id AKIAEXAMPLE --status Inactive
aws iam delete-access-key --user-name alice --access-key-id AKIAEXAMPLE

# Instance profiles
aws iam create-instance-profile --instance-profile-name my-profile
aws iam add-role-to-instance-profile --instance-profile-name my-profile --role-name my-ec2-role
```

---

## S3

```bash
# High-level (aws s3)
aws s3 mb s3://my-bucket --region us-east-1
aws s3 ls
aws s3 ls s3://my-bucket/logs/ --recursive --human-readable
aws s3 cp ./report.csv s3://my-bucket/reports/report.csv
aws s3 cp s3://my-bucket/report.csv ./report.csv
aws s3 sync ./dist s3://my-bucket/static/ --delete
aws s3 sync ./dist s3://my-bucket/static/ --exclude "*.map" --include "*.js" --delete
aws s3 mv s3://my-bucket/old/file.txt s3://my-bucket/new/file.txt
aws s3 rm s3://my-bucket/old-prefix/ --recursive
aws s3 rb s3://my-bucket --force
aws s3 presign s3://my-bucket/private/report.pdf --expires-in 3600

# Low-level (aws s3api)
aws s3api create-bucket --bucket my-bucket --region us-east-1
aws s3api create-bucket --bucket my-west --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2
aws s3api put-public-access-block --bucket my-bucket \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket my-bucket --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket my-bucket --server-side-encryption-configuration '{
  "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-lifecycle-configuration --bucket my-bucket --lifecycle-configuration '{
  "Rules":[{"ID":"expire-logs","Status":"Enabled","Filter":{"Prefix":"logs/"},"Expiration":{"Days":90}}]}'
aws s3api list-objects-v2 --bucket my-bucket --prefix logs/ \
  --query 'Contents[].{Key:Key,Size:Size,Modified:LastModified}' -o table
aws s3api put-object --bucket my-bucket --key data/file.json --body file://file.json \
  --content-type application/json --storage-class INTELLIGENT_TIERING
```

---

## Lambda

```bash
# Create
aws lambda create-function --function-name my-func --runtime python3.12 --handler index.handler \
  --role arn:aws:iam::123456789012:role/lambda-role --zip-file fileb://function.zip \
  --timeout 30 --memory-size 256 --environment 'Variables={DB_HOST=mydb,LOG_LEVEL=INFO}'
aws lambda wait function-active --function-name my-func

# Update code
aws lambda update-function-code --function-name my-func --zip-file fileb://function.zip
aws lambda wait function-updated --function-name my-func

# Update config
aws lambda update-function-configuration --function-name my-func --memory-size 512 --timeout 60

# Invoke
aws lambda invoke --function-name my-func --payload '{"key":"value"}' \
  --cli-binary-format raw-in-base64-out response.json

# List
aws lambda list-functions --query 'Functions[].{Name:FunctionName,Runtime:Runtime,Memory:MemorySize}' -o table

# Layers
aws lambda publish-layer-version --layer-name my-deps --zip-file fileb://layer.zip --compatible-runtimes python3.12
LAYER_ARN=$(aws lambda list-layer-versions --layer-name my-deps --query 'LayerVersions[0].LayerVersionArn' -o text)
aws lambda update-function-configuration --function-name my-func --layers "$LAYER_ARN"

# Event source (SQS)
aws lambda create-event-source-mapping --function-name my-func \
  --event-source-arn arn:aws:sqs:us-east-1:123456789012:my-queue --batch-size 10

# Versions and aliases
aws lambda publish-version --function-name my-func --description "v2.1"
aws lambda create-alias --function-name my-func --name prod --function-version 5
aws lambda put-function-concurrency --function-name my-func --reserved-concurrent-executions 100

# Permissions
aws lambda add-permission --function-name my-func --statement-id allow-apigw \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:123456789012:api-id/*"
```

---

## RDS

```bash
# Subnet group
aws rds create-db-subnet-group --db-subnet-group-name my-db-subnets \
  --db-subnet-group-description "DB subnets" --subnet-ids subnet-aaa subnet-bbb

# Create PostgreSQL
aws rds create-db-instance --db-instance-identifier prod-pg --db-instance-class db.t3.medium \
  --engine postgres --engine-version 16.2 --master-username dbadmin --master-user-password "$DB_PASS" \
  --allocated-storage 100 --max-allocated-storage 500 --storage-type gp3 --storage-encrypted \
  --db-subnet-group-name my-db-subnets --vpc-security-group-ids sg-xxx \
  --backup-retention-period 7 --multi-az --deletion-protection
aws rds wait db-instance-available --db-instance-identifier prod-pg

# List
aws rds describe-db-instances \
  --query 'DBInstances[].{ID:DBInstanceIdentifier,Class:DBInstanceClass,Engine:Engine,Status:DBInstanceStatus,Endpoint:Endpoint.Address}' -o table

# Get endpoint
aws rds describe-db-instances --db-instance-identifier prod-pg --query 'DBInstances[0].Endpoint.Address' -o text

# Modify
aws rds modify-db-instance --db-instance-identifier prod-pg --db-instance-class db.t3.large --apply-immediately

# Snapshots
aws rds create-db-snapshot --db-instance-identifier prod-pg --db-snapshot-identifier "prod-pg-$(date +%Y%m%d)"
aws rds wait db-snapshot-available --db-snapshot-identifier "prod-pg-$(date +%Y%m%d)"
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier prod-pg-restored \
  --db-snapshot-identifier prod-pg-20260101 --db-instance-class db.t3.medium

# Aurora
aws rds create-db-cluster --db-cluster-identifier my-aurora --engine aurora-postgresql --engine-version 15.4 \
  --master-username admin --master-user-password "$DB_PASS" --db-subnet-group-name my-db-subnets \
  --vpc-security-group-ids sg-xxx --storage-encrypted
aws rds create-db-instance --db-instance-identifier my-aurora-writer --db-cluster-identifier my-aurora \
  --db-instance-class db.r6g.large --engine aurora-postgresql
```

---

## CloudFormation

```bash
# Validate
aws cloudformation validate-template --template-body file://template.yaml

# Create
aws cloudformation create-stack --stack-name my-stack --template-body file://template.yaml \
  --parameters ParameterKey=Env,ParameterValue=prod --capabilities CAPABILITY_NAMED_IAM \
  --tags Key=Project,Value=MyApp
aws cloudformation wait stack-create-complete --stack-name my-stack

# Deploy (create or update)
aws cloudformation deploy --stack-name my-stack --template-file template.yaml \
  --parameter-overrides Env=prod --capabilities CAPABILITY_NAMED_IAM --no-fail-on-empty-changeset

# Outputs
aws cloudformation describe-stacks --stack-name my-stack \
  --query 'Stacks[0].Outputs[].{Key:OutputKey,Value:OutputValue}' -o table

# Change sets
aws cloudformation create-change-set --stack-name my-stack --change-set-name preview \
  --template-body file://template.yaml --capabilities CAPABILITY_NAMED_IAM
aws cloudformation describe-change-set --stack-name my-stack --change-set-name preview \
  --query 'Changes[].{Action:ResourceChange.Action,Type:ResourceChange.ResourceType,ID:ResourceChange.LogicalResourceId}' -o table
aws cloudformation execute-change-set --stack-name my-stack --change-set-name preview

# Delete
aws cloudformation delete-stack --stack-name my-stack
aws cloudformation wait stack-delete-complete --stack-name my-stack

# Drift
DRIFT_ID=$(aws cloudformation detect-stack-drift --stack-name my-stack --query 'StackDriftDetectionId' -o text)
aws cloudformation describe-stack-resource-drifts --stack-name my-stack \
  --stack-resource-drift-status-filters MODIFIED DELETED -o table
```

---

## ECS

```bash
# Cluster
aws ecs create-cluster --cluster-name prod
aws ecs describe-clusters --clusters prod --query 'clusters[0].{Status:status,Tasks:runningTasksCount}'

# Task definition (inline Fargate)
aws ecs register-task-definition --family my-api --requires-compatibilities FARGATE \
  --network-mode awsvpc --cpu 512 --memory 1024 \
  --execution-role-arn arn:aws:iam::123456789012:role/ecs-exec-role \
  --container-definitions '[{"name":"api","image":"123456789012.dkr.ecr.us-east-1.amazonaws.com/my-api:latest","portMappings":[{"containerPort":8080}],"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"/ecs/my-api","awslogs-region":"us-east-1","awslogs-stream-prefix":"ecs"}}}]'

# Service
aws ecs create-service --cluster prod --service-name my-api --task-definition my-api:3 \
  --desired-count 3 --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-aaa,subnet-bbb],securityGroups=[sg-xxx],assignPublicIp=DISABLED}"
aws ecs wait services-stable --cluster prod --services my-api

# Update service (deploy new revision)
aws ecs update-service --cluster prod --service-name my-api --task-definition my-api:4 --force-new-deployment
aws ecs wait services-stable --cluster prod --services my-api

# Scale
aws ecs update-service --cluster prod --service-name my-api --desired-count 5

# Exec into container
aws ecs execute-command --cluster prod --task arn:aws:ecs:... --container api --command "/bin/sh" --interactive
```

---

## EKS

```bash
# Create cluster
aws eks create-cluster --name prod --kubernetes-version 1.29 \
  --role-arn arn:aws:iam::123456789012:role/EKSClusterRole \
  --resources-vpc-config subnetIds=subnet-aaa,subnet-bbb,securityGroupIds=sg-xxx
aws eks wait cluster-active --name prod
aws eks update-kubeconfig --name prod --region us-east-1

# Node group
aws eks create-nodegroup --cluster-name prod --nodegroup-name workers \
  --node-role arn:aws:iam::123456789012:role/EKSNodeRole --subnets subnet-aaa subnet-bbb \
  --instance-types t3.medium --scaling-config minSize=2,maxSize=10,desiredSize=3
aws eks wait nodegroup-active --cluster-name prod --nodegroup-name workers

# Add-ons
aws eks create-addon --cluster-name prod --addon-name vpc-cni
aws eks create-addon --cluster-name prod --addon-name coredns
aws eks create-addon --cluster-name prod --addon-name kube-proxy
```

---

## CloudWatch and Logs

```bash
# Metrics
aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=prod-pg \
  --start-time $(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --end-time $(date -u '+%Y-%m-%dT%H:%M:%SZ') --period 3600 --statistics Average Maximum -o table
aws cloudwatch put-metric-data --namespace "MyApp" --metric-name OrdersProcessed --value 150 --unit Count

# Alarms
aws cloudwatch put-metric-alarm --alarm-name lambda-errors --namespace AWS/Lambda --metric-name Errors \
  --dimensions Name=FunctionName,Value=my-func --statistic Sum --period 300 --threshold 5 \
  --comparison-operator GreaterThanOrEqualToThreshold --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:alerts

# Logs
aws logs create-log-group --log-group-name /app/my-service
aws logs put-retention-policy --log-group-name /app/my-service --retention-in-days 30
aws logs tail /app/my-service --follow --since 15m
aws logs filter-log-events --log-group-name /app/my-service --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s000) --query 'events[].message' -o text
```

---

## SSM

```bash
# Parameter Store
aws ssm put-parameter --name /app/prod/db-host --value "prod-pg.example.com" --type String --overwrite
aws ssm put-parameter --name /app/prod/db-pass --value "Secret!" --type SecureString --overwrite
aws ssm get-parameter --name /app/prod/db-host --query 'Parameter.Value' -o text
aws ssm get-parameter --name /app/prod/db-pass --with-decryption --query 'Parameter.Value' -o text
aws ssm get-parameters-by-path --path /app/prod/ --recursive --with-decryption \
  --query 'Parameters[].{Name:Name,Value:Value}' -o table

# Run Command
COMMAND_ID=$(aws ssm send-command --document-name AWS-RunShellScript \
  --targets 'Key=tag:Env,Values=prod' --parameters 'commands=["df -h","uptime"]' \
  --query 'Command.CommandId' -o text)
aws ssm list-command-invocations --command-id "$COMMAND_ID" \
  --query 'CommandInvocations[].{Instance:InstanceId,Status:Status}' -o table

# Session Manager
aws ssm start-session --target i-0123456789abcdef0
aws ssm start-session --target i-0123456789abcdef0 --document-name AWS-StartPortForwardingSession \
  --parameters portNumber=5432,localPortNumber=15432
```

---

## Route 53

```bash
# Hosted zones
ZONE_ID=$(aws route53 create-hosted-zone --name example.com --caller-reference "$(date +%s)" \
  --query 'HostedZone.Id' -o text | cut -d'/' -f3)
aws route53 list-hosted-zones --query 'HostedZones[].{Name:Name,ID:Id}' -o table

# UPSERT records
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"app.example.com","Type":"A","TTL":300,"ResourceRecords":[{"Value":"1.2.3.4"}]}}]}'

# Alias record (ALB)
aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch '{
  "Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"app.example.com","Type":"A","AliasTarget":{"HostedZoneId":"Z35SXDOTRQ7X7K","DNSName":"myalb.us-east-1.elb.amazonaws.com","EvaluateTargetHealth":true}}}]}'

# List records
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  --query 'ResourceRecordSets[].{Name:Name,Type:Type}' -o table
```

---

## STS

```bash
aws sts get-caller-identity
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' -o table

# Assume role
aws sts assume-role --role-arn arn:aws:iam::123456789012:role/MyRole --role-session-name my-session

# Get session token (MFA)
aws sts get-session-token --serial-number arn:aws:iam::123456789012:mfa/my-device --token-code 123456
```

---

## VPC Networking

```bash
# VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' -o text)
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=prod-vpc
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

# Subnets
PUB_SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --query 'Subnet.SubnetId' -o text)
PRIV_SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --query 'Subnet.SubnetId' -o text)

# Internet gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' -o text)
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"

# Route table
RTB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' -o text)
aws ec2 create-route --route-table-id "$RTB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID"
aws ec2 associate-route-table --route-table-id "$RTB_ID" --subnet-id "$PUB_SUBNET"

# Security group
SG_ID=$(aws ec2 create-security-group --group-name web-sg --description "Web SG" --vpc-id "$VPC_ID" --query 'GroupId' -o text)
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 10.0.0.0/8
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0
```
