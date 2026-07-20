# Druid Advanced Features

## Approximate Algorithms

Druid provides extensions for approximate algorithms:

| Algorithm | Extension | Use Case | SQL Function |
|---|---|---|---|
| HyperLogLog (HLL) | druid-datasketches | Distinct count | `APPROX_COUNT_DISTINCT_DS_HLL()` |
| Theta Sketch | druid-datasketches | Distinct count + set operations | `APPROX_COUNT_DISTINCT_DS_THETA()` |
| Quantiles (KLL) | druid-datasketches | Percentiles, histograms | `DS_QUANTILES_SKETCH()` |
| Tuple Sketch | druid-datasketches | Distinct + associated values | `DS_TUPLE_DOUBLES()` |
| Bloom Filter | druid-bloom-filter | Membership testing | `BLOOM_FILTER()` |

**HLL vs. Theta Sketch:**
- HLL: more space-efficient (~2% error), no set operations
- Theta: supports union/intersection/difference, slightly higher memory, ~3% error

## Multi-Value Dimensions

Druid natively supports multi-value string dimensions (arrays of values per row):

```sql
-- Filter by any value in a multi-value dimension
SELECT * FROM events WHERE MV_CONTAINS(tags, 'urgent');

-- Expand multi-value dimensions
SELECT tag, COUNT(*) FROM events CROSS JOIN UNNEST(MV_TO_ARRAY(tags)) AS t(tag) GROUP BY 1;

-- Filter and aggregate
SELECT
  MV_FILTER_ONLY(tags, ARRAY['error', 'warning']) AS filtered_tags,
  COUNT(*)
FROM events
GROUP BY 1;
```
