# AWS WAF Rule Statement Type Examples

Full Terraform examples for each `statement` type used in `aws_wafv2_web_acl` / `aws_wafv2_rule_group` rules.

**Byte match:**
```hcl
statement {
  byte_match_statement {
    search_string         = "sqlmap"
    field_to_match {
      single_header {
        name = "user-agent"
      }
    }
    text_transformation {
      priority = 0
      type     = "LOWERCASE"
    }
    positional_constraint = "CONTAINS"  # EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD
  }
}
```

**Geo match:**
```hcl
statement {
  geo_match_statement {
    country_codes = ["CN", "RU", "KP"]
  }
}
```

**IP set reference:**
```hcl
resource "aws_wafv2_ip_set" "trusted_ips" {
  name               = "trusted-ips"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = ["10.0.0.0/8", "192.168.1.100/32"]
}

statement {
  ip_set_reference_statement {
    arn = aws_wafv2_ip_set.trusted_ips.arn
  }
}
```

**Regex pattern set:**
```hcl
resource "aws_wafv2_regex_pattern_set" "sql_patterns" {
  name  = "sql-injection-patterns"
  scope = "REGIONAL"

  regular_expression {
    regex_string = "(?i)(union.*select|select.*from|insert.*into|delete.*from|drop.*table)"
  }
}

statement {
  regex_pattern_set_reference_statement {
    arn = aws_wafv2_regex_pattern_set.sql_patterns.arn
    field_to_match {
      body {}
    }
    text_transformation {
      priority = 0
      type     = "URL_DECODE"
    }
    text_transformation {
      priority = 1
      type     = "HTML_ENTITY_DECODE"
    }
  }
}
```

**Rate-based rule with custom key:**
```hcl
statement {
  rate_based_statement {
    limit              = 100
    aggregate_key_type = "CUSTOM_KEYS"
    
    custom_key {
      header {
        name = "X-API-Key"
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }
    
    scope_down_statement {
      byte_match_statement {
        search_string         = "/api/"
        field_to_match { uri_path {} }
        text_transformation { priority = 0; type = "NONE" }
        positional_constraint = "STARTS_WITH"
      }
    }
  }
}
```

**AND/OR/NOT compound statements:**
```hcl
statement {
  and_statement {
    statement {
      geo_match_statement {
        country_codes = ["CN"]
      }
    }
    statement {
      not_statement {
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.trusted_cn_ips.arn
          }
        }
      }
    }
  }
}
```
