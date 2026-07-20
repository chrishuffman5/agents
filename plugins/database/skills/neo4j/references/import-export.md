# Neo4j Import/Export

## Import/Export

**neo4j-admin import (initial bulk load, fastest):**
```bash
# Import from CSV headers files -- use for initial database population
neo4j-admin database import full neo4j \
  --nodes=Person=import/persons-header.csv,import/persons.csv \
  --relationships=KNOWS=import/knows-header.csv,import/knows.csv \
  --skip-bad-relationships=true \
  --trim-strings=true
```

**LOAD CSV (online, incremental):**
```cypher
-- Load nodes from CSV
LOAD CSV WITH HEADERS FROM 'file:///people.csv' AS row
MERGE (p:Person {id: row.id})
SET p.name = row.name, p.age = toInteger(row.age);

-- Load relationships from CSV
LOAD CSV WITH HEADERS FROM 'file:///knows.csv' AS row
MATCH (a:Person {id: row.from}), (b:Person {id: row.to})
MERGE (a)-[:KNOWS {since: date(row.since)}]->(b);

-- For large CSV files, use periodic commit or CALL IN TRANSACTIONS
LOAD CSV WITH HEADERS FROM 'file:///large.csv' AS row
CALL {
  WITH row
  MERGE (p:Person {id: row.id})
  SET p.name = row.name
} IN TRANSACTIONS OF 10000 ROWS;
```

**APOC import (flexible, multiple formats):**
```cypher
-- JSON import
CALL apoc.load.json('file:///data.json') YIELD value
UNWIND value.items AS item
MERGE (n:Item {id: item.id}) SET n += item;

-- JDBC import from relational database
CALL apoc.load.jdbc('jdbc:postgresql://host/db', 'SELECT * FROM users') YIELD row
MERGE (u:User {id: row.id}) SET u.name = row.name;
```
