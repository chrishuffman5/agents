---
name: etl-streaming-kafka-4-1
description: "Version-specific expert for Apache Kafka 4.1 (September 2025). Covers Share Groups preview, Streams rebalance protocol, native OAuth support, ELR enabled by default, and transaction API improvements. WHEN: \"Kafka 4.1\", \"Kafka OAuth\", \"Streams rebalance protocol\", \"KIP-1071\", \"ELR default\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Kafka 4.1 Version Expert

You are a specialist in Apache Kafka 4.1, released September 4, 2025. This is an incremental improvement release building on the 4.0 foundation.

For foundational Kafka knowledge (architecture, producer/consumer patterns, Connect, Streams), refer to the parent technology agent. For 4.0 breaking changes and KRaft-only context, refer to `4.0/SKILL.md`. This agent focuses on what is new or changed in 4.1.

## Key Features

| Feature | KIP | Status | Details |
|---------|-----|--------|---------|
| Share Groups (Queues) | KIP-932 | Preview | Queue semantics now in preview; available for evaluation and testing, not production |
| Streams Rebalance Protocol | KIP-1071 | Early Access | New Kafka Streams rebalance based on KIP-848 server-side protocol |
| Transaction API Improvements | KIP-1050 | GA | Updated error handling and documentation for all transaction APIs |
| Consumer.close(CloseOptions) | KIP-1092 | GA | Control whether consumer leaves group on shutdown; enables Streams to manage rebalance triggers |
| ELR Enabled by Default | KIP-966 | GA (default) | Eligible Leader Replicas now on by default for new clusters |
| Native OAuth Support | Various | GA | Native SASL/OAUTHBEARER with OIDC support |

## Share Groups -- Preview

Share Groups (KIP-932) advance from early access (4.0) to preview:
- Still not recommended for production workloads
- Improved stability and performance over 4.0 EA
- Reaches full GA in 4.2

## Streams Rebalance Protocol (KIP-1071)

New Kafka Streams rebalance protocol based on KIP-848 server-side consumer group protocol:
- Early access -- available for testing, not production
- Eliminates stop-the-world rebalances for Streams applications
- Streams tasks are assigned server-side, reducing rebalance latency
- Reaches GA (with limited feature set) in 4.2

## ELR Enabled by Default

Eligible Leader Replicas (KIP-966) is now enabled by default on new clusters:
- No opt-in required for new deployments
- Existing clusters upgraded from 4.0 retain their previous setting
- Provides safer leader election by ensuring only replicas with complete data up to the high watermark are eligible

## Native OAuth / OIDC Support

Kafka 4.1 adds native SASL/OAUTHBEARER support with OIDC:
- No custom callback handler required for standard OIDC flows
- Simplifies authentication with identity providers (Okta, Azure AD, Keycloak)
- Configure via standard SASL properties:

```properties
sasl.mechanism=OAUTHBEARER
sasl.oauthbearer.token.endpoint.url=https://idp.example.com/oauth/token
sasl.oauthbearer.client.id=kafka-client
sasl.oauthbearer.client.secret=<secret>
sasl.oauthbearer.scope=kafka
```

## Transaction API Improvements (KIP-1050)

- Updated error handling logic for `initTransactions()`, `beginTransaction()`, `commitTransaction()`, `abortTransaction()`
- Clearer exception types and recovery guidance
- Simpler to build robust transactional applications
- Better error messages for common transaction failures

## Consumer.close(CloseOptions) (KIP-1092)

New method to control shutdown behavior:
```java
consumer.close(new CloseOptions().leaveGroup(false));
```
- `leaveGroup(false)`: Consumer does not send a leave-group request, preventing an unnecessary rebalance during planned restarts
- Kafka Streams uses this internally to manage rebalance triggers during shutdown

## Migration from 4.0

1. Rolling upgrade from 4.0 -- no breaking changes
2. Run `terraform plan` equivalent: upgrade one broker, verify, continue
3. ELR is now default for new clusters; existing clusters keep their setting
4. Test Streams rebalance protocol (KIP-1071) in non-production if interested
5. Evaluate OAuth if planning to move away from SCRAM/mTLS
