# Archer FAIR Quantitative Risk Scenario Walkthrough

Archer's cyber risk quantification module supports the FAIR (Factor Analysis of Information Risk) methodology.

```
FAIR Risk Scenario in Archer:

Scenario: Ransomware encrypts production systems
  Asset: Production databases (Oracle, SQL Server)
  Threat: External attacker via phishing → endpoint compromise → lateral movement
  
  Loss Event Frequency:
    Threat Contact Frequency: 52/year (weekly phishing attempts)
    Probability of Action: 0.30 (30% of phishing emails are acted on)
    Vulnerability: 0.15 (15% — EDR + email filtering reduces but doesn't eliminate)
    Loss Event Frequency = 52 × 0.30 × 0.15 = ~2.3 loss events/year
    
  Loss Magnitude (per event):
    Primary Loss:
      Productivity: 3 days × 500 employees × $500/day = $750K
      Response/Recovery: $300K (IR team + forensics + recovery labor)
      Replacement: $100K (hardware, licenses)
    Secondary Loss:
      Regulatory: $500K (potential HIPAA fine + notification costs)
      Reputation: $1M (estimated customer churn impact)
    Total Loss Magnitude: $2.65M per event
    
  Annualized Loss Expectancy:
    ALE = 2.3 × $2.65M = ~$6.1M/year (before controls)
    
  Control investment analysis:
    EDR upgrade + SOC coverage: $500K/year
    New vulnerability: reduces to 0.05 (5%)
    New ALE: 52 × 0.30 × 0.05 × $2.65M = ~$2M/year
    Risk reduction value: $6.1M - $2M = $4.1M/year
    ROI: ($4.1M - $0.5M) / $0.5M = 720% annual ROI
```

**Archer FAIR reports:**
- Executive report: top risks by ALE (annualized loss expectancy)
- Before/after control investment analysis
- Portfolio view: total organizational ALE by category
- Sensitivity analysis: what-if scenarios for control changes
