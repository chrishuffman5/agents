# Neptune SPARQL Query Language

## SPARQL Query Language

Neptune is a W3C SPARQL 1.1 compliant RDF triple store.

```sparql
# Insert triples
INSERT DATA {
  <http://example.org/person/alice> <http://xmlns.com/foaf/0.1/name> "Alice" .
  <http://example.org/person/alice> <http://xmlns.com/foaf/0.1/age> "30"^^<http://www.w3.org/2001/XMLSchema#integer> .
  <http://example.org/person/alice> <http://xmlns.com/foaf/0.1/knows> <http://example.org/person/bob> .
}

# Query with PREFIX shorthand
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?name ?age
WHERE {
  ?person foaf:name ?name .
  ?person foaf:age ?age .
  FILTER (?age > 25)
}
ORDER BY ?name

# OPTIONAL and FILTER
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?person ?name ?email
WHERE {
  ?person foaf:name ?name .
  OPTIONAL { ?person foaf:mbox ?email }
  FILTER (CONTAINS(?name, "Ali"))
}

# CONSTRUCT (build a subgraph)
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
CONSTRUCT {
  ?person foaf:name ?name .
  ?person foaf:knows ?friend .
}
WHERE {
  ?person foaf:name ?name .
  ?person foaf:knows ?friend .
}

# Named graphs
INSERT DATA {
  GRAPH <http://example.org/graph/social> {
    <http://example.org/person/alice> <http://xmlns.com/foaf/0.1/knows> <http://example.org/person/bob> .
  }
}

# Aggregation
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT (COUNT(?person) AS ?count) ?company
WHERE {
  ?person <http://example.org/worksAt> ?company .
}
GROUP BY ?company
ORDER BY DESC(?count)
```

**Neptune SPARQL specifics:**
- HTTP endpoint: `https://<cluster-endpoint>:8182/sparql`
- Supports SPARQL 1.1 Query, Update, Graph Store HTTP Protocol
- Named graph support (quads)
- `EXPLAIN` supported via `explain=<mode>` query parameter (static, dynamic, details)
- Default graph is the union of all named graphs
- No support for SPARQL federation (SERVICE keyword for remote endpoints)
