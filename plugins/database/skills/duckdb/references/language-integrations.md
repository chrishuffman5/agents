# DuckDB Language Integrations Reference

Python, WASM (browser/Node.js), and R integration patterns.

---

## Python Integration

```python
import duckdb

# In-memory connection (default)
con = duckdb.connect()

# Persistent database
con = duckdb.connect('my_database.duckdb')

# Configuration at connection time
con = duckdb.connect(config={'threads': 4, 'memory_limit': '8GB'})

# Query files directly
df = duckdb.sql("SELECT * FROM 'data.parquet' WHERE amount > 100").df()

# Query Pandas DataFrames directly (zero-copy via Arrow)
import pandas as pd
df = pd.DataFrame({'id': [1, 2, 3], 'value': [10, 20, 30]})
result = duckdb.sql("SELECT * FROM df WHERE value > 15").df()

# Query Polars DataFrames
import polars as pl
lf = pl.LazyFrame({'x': [1, 2, 3]})
duckdb.sql("SELECT * FROM lf")

# Query Arrow tables
import pyarrow as pa
table = pa.table({'col1': [1, 2], 'col2': ['a', 'b']})
duckdb.sql("SELECT * FROM table")

# Relational API (method chaining)
rel = con.sql("SELECT * FROM orders")
rel = rel.filter("amount > 100").aggregate("region, sum(amount) AS total").order("total DESC")
result = rel.fetchdf()

# Prepared statements
con.execute("SELECT * FROM orders WHERE region = ? AND amount > ?", ['US', 100])
rows = con.fetchall()

# Appender (fast bulk insert)
appender = con.appender('target_table')
for row in data:
    appender.append_row(row)
appender.flush()
```

## WASM Deployment

DuckDB compiles to WebAssembly for browser and Node.js deployment:

```javascript
// Browser usage with jsDelivr CDN
import * as duckdb from '@duckdb/duckdb-wasm';
import duckdb_wasm from '@duckdb/duckdb-wasm/dist/duckdb-mvp.wasm';

const bundle = await duckdb.selectBundle({
    mvp: { mainModule: duckdb_wasm, mainWorker: new URL('@duckdb/duckdb-wasm/dist/duckdb-browser-mvp.worker.js', import.meta.url).href }
});
const worker = new Worker(bundle.mainWorker);
const logger = new duckdb.ConsoleLogger();
const db = new duckdb.AsyncDuckDB(logger, worker);
await db.instantiate(bundle.mainModule);

const conn = await db.connect();
const result = await conn.query("SELECT 42 AS answer");
console.log(result.toArray());
await conn.close();

// Register files, query Parquet over HTTP
await db.registerFileURL('remote.parquet', 'https://example.com/data.parquet');
const result2 = await conn.query("SELECT * FROM 'remote.parquet' LIMIT 10");
```

## R Integration

```r
library(duckdb)

# In-memory
con <- dbConnect(duckdb())

# Persistent
con <- dbConnect(duckdb(), "my_database.duckdb")

# Query files
dbGetQuery(con, "SELECT * FROM read_parquet('data.parquet') LIMIT 10")

# Query R data.frames directly
dbWriteTable(con, "mtcars_tbl", mtcars)
dbGetQuery(con, "SELECT cyl, avg(mpg) FROM mtcars_tbl GROUP BY cyl")

# dplyr integration
library(dplyr)
tbl(con, "orders") %>%
  filter(amount > 100) %>%
  group_by(region) %>%
  summarize(total = sum(amount))

dbDisconnect(con)
```
