# ZAP GitHub Actions Integration

### Official ZAP Actions

**Baseline scan:**
```yaml
- name: ZAP Baseline Scan
  uses: zaproxy/action-baseline@v0.12.0
  with:
    target: 'https://app.example.com'
    rules_file_name: '.zap/rules.tsv'
    cmd_options: '-I'   # Don't fail
```

**Full scan:**
```yaml
- name: ZAP Full Scan
  uses: zaproxy/action-full-scan@v0.10.0
  with:
    target: 'https://test.example.com'
    rules_file_name: '.zap/rules.tsv'
    allow_issue_writing: true   # Create GitHub issues for findings
```

**API scan:**
```yaml
- name: ZAP API Scan
  uses: zaproxy/action-api-scan@v0.7.0
  with:
    target: 'https://api.example.com/openapi.json'
    format: openapi
```

**With authentication (Automation Framework):**
```yaml
- name: ZAP Authenticated Scan
  uses: zaproxy/action-af@v0.2.0
  with:
    plan: '.zap/automation-plan.yaml'
  env:
    DAST_USERNAME: ${{ secrets.DAST_USERNAME }}
    DAST_PASSWORD: ${{ secrets.DAST_PASSWORD }}
```

### Uploading to GitHub Security Tab

```yaml
- name: ZAP Scan
  uses: zaproxy/action-full-scan@v0.10.0
  with:
    target: 'https://test.example.com'
    report_format: 'sarif'
    report_file: 'zap-results.sarif'

- name: Upload ZAP SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: zap-results.sarif
  if: always()
```
