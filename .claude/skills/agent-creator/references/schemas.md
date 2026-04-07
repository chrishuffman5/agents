# Agent Creator Schemas

JSON structures used by the agent-creator skill for configuration, evaluation, and tracking.

---

## agent-manifest.json

Tracks all agents in a domain hierarchy. Located at the project root (e.g., `agents/manifest.json`).

```json
{
  "project": "agents",
  "domains": [
    {
      "name": "database",
      "path": "database/",
      "description": "Data storage, retrieval, query optimization, administration",
      "technologies": [
        {
          "name": "sql-server",
          "path": "database/sql-server/",
          "description": "Microsoft SQL Server relational database engine",
          "versions": [
            {
              "name": "2022",
              "path": "database/sql-server/2022/",
              "compatibility_level": 160,
              "support_status": "mainstream",
              "eol_date": "2028-01-11"
            }
          ]
        }
      ]
    }
  ]
}
```

**Fields:**
- `project`: Project identifier
- `domains[].name`: Domain identifier (lowercase)
- `domains[].path`: Relative path to domain agent directory
- `domains[].technologies[].name`: Technology identifier (lowercase, hyphenated)
- `domains[].technologies[].versions[].name`: Version identifier
- `domains[].technologies[].versions[].support_status`: "mainstream", "extended", "eol"

---

## evals.json

Test cases for an agent. Located at `{agent-dir}/evals/evals.json`. Uses the same schema as the skill-creator.

```json
{
  "agent_name": "database-sql-server-2022",
  "domain": "database",
  "technology": "sql-server",
  "version": "2022",
  "evals": [
    {
      "id": 1,
      "prompt": "My SQL Server 2022 database is showing high WRITELOG waits. The database uses synchronous commit on an AG secondary. What should I investigate?",
      "expected_output": "Version-specific diagnosis mentioning accelerated database recovery, persistent log buffer, and AG flow control",
      "category": "troubleshooting",
      "requires_version_knowledge": true,
      "expectations": [
        "Mentions SQL Server 2022 specific features relevant to WRITELOG waits",
        "Suggests checking AG flow control settings",
        "Does not recommend features unavailable in SQL Server 2022"
      ]
    }
  ]
}
```

**Fields:**
- `agent_name`: Full agent identifier (domain-technology-version)
- `domain`, `technology`, `version`: Hierarchy identifiers
- `evals[].id`: Unique integer identifier
- `evals[].prompt`: Realistic user task prompt
- `evals[].expected_output`: Description of what a good response includes
- `evals[].category`: "troubleshooting", "optimization", "migration", "administration", "development"
- `evals[].requires_version_knowledge`: Whether this test specifically requires version-specific knowledge
- `evals[].expectations`: Verifiable assertions for grading

---

## grading.json

Evaluation results for an agent test run. Same schema as skill-creator's grading.json — see the skill-creator's `references/schemas.md` for the full specification.

Key additions for agent grading:

```json
{
  "expectations": [...],
  "summary": {...},
  "domain_quality": {
    "specificity_score": 4,
    "version_accuracy": true,
    "actionability_score": 5,
    "boundary_awareness": true,
    "notes": "Agent correctly identified PSP optimization as SQL Server 2022 feature"
  }
}
```

**Additional fields:**
- `domain_quality.specificity_score`: 1-5, how version-specific was the response (vs. generic)
- `domain_quality.version_accuracy`: Were version-specific claims correct?
- `domain_quality.actionability_score`: 1-5, could a user follow this advice?
- `domain_quality.boundary_awareness`: Did the agent stay within its version scope?
