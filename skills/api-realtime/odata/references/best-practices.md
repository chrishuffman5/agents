# OData Best Practices

## Query Composition

### $filter Patterns

**Comparison:** `$filter=Price gt 20 and Price le 100`

**String functions:** `$filter=contains(Name,'Widget')`, `startswith(Name,'Pro')`, `tolower(Category) eq 'electronics'`

**Date functions:** `$filter=year(CreatedAt) eq 2024`, `$filter=CreatedAt gt 2024-01-01T00:00:00Z`

**Null handling:** `$filter=MiddleName eq null`, `$filter=MiddleName ne null`

**Type casting:** `$filter=isof(Example.SpecialProduct)`

### Lambda Operators

**any** (at least one element):
```
$filter=Tags/any(t: contains(t, 'sale'))
$filter=Items/any(i: i/Price gt 100)
$filter=assignedLicenses/any(l: l/skuId eq guid'...')
```

**all** (every element):
```
$filter=Reviews/all(r: r/Rating ge 4)
```

**Nested lambda:**
```
$filter=Rooms/all(r: r/Amenities/any(a: a eq 'tv') and r/BaseRate lt 100)
```

Empty collection: `any()` returns false. `all()` returns true (vacuous truth).

### $expand with Nested Options

```
$expand=Items($select=ProductID,Quantity;$filter=Price gt 50;$orderby=Price desc;$top=10)
$expand=Supplier($expand=Contacts($select=Name,Email))
```

Multiple expansions: comma-separated. Nested query options: semicolon-separated inside parentheses.

### $select for Performance

Always use `$select` to reduce payload:
```
$select=ID,Name,Price
```

`*` selects all declared properties.

## Data Aggregation ($apply)

### Basic Aggregate

```
$apply=aggregate(Price with average as AvgPrice)
$apply=aggregate($count as ProductCount)
$apply=aggregate(Price with sum as TotalValue, $count as Count)
```

Methods: `sum`, `min`, `max`, `average`, `countdistinct`, `$count`.

### groupby

```
$apply=groupby((Category), aggregate(Price with average as AvgPrice))
$apply=groupby((Supplier/Name), aggregate(Price with max as MaxPrice, $count as Count))
```

### Composed Transformations

Pipe operator `/` applies transformations left to right:
```
$apply=filter(Category eq 'Electronics')/groupby((Status), aggregate($count as Count))
```

### Full Aggregation Example

```
$apply=filter(OrderDate ge 2024-01-01T00:00:00Z)/
  groupby((Customer/Country, Status),
    aggregate($count as OrderCount, TotalAmount with sum as Revenue))
&$orderby=Revenue desc&$top=10
```

### compute

Add computed properties:
```
$apply=compute(Price mul TaxRate as TaxAmount)
```

## Batch Requests

### JSON Format (OData 4.01+)

```json
POST /odata/$batch
Content-Type: application/json

{
  "requests": [
    {"id": "r1", "method": "GET", "url": "Products(1)"},
    {"id": "r2", "atomicityGroup": "g1", "method": "POST", "url": "Orders",
     "body": {"CustomerID": "ALFKI"}},
    {"id": "r3", "atomicityGroup": "g1", "dependsOn": ["r2"],
     "method": "POST", "url": "$r2/Items",
     "body": {"ProductID": 42}}
  ]
}
```

`atomicityGroup`: requests in same group are atomic (all succeed or all fail).
`dependsOn`: reference earlier request results.

### Multipart Format (OData 4.0)

Changesets for atomic operations. GET requests cannot be inside changesets.

## Server-Driven Paging

Server may impose max page size. Response includes `@odata.nextLink`:
```json
{
  "@odata.count": 1543,
  "value": [...],
  "@odata.nextLink": "https://api.example.com/odata/Products?$skip=20"
}
```

Clients must follow `@odata.nextLink` to get all results. Never construct next page URLs manually.

## Performance Best Practices

### Use $select

Reduces I/O, serialization, and transfer size. Configure as default in client SDKs.

### Limit $expand Depth

Restrict `$expand` to 2-3 levels. Deeply nested expansions can cause expensive joins.

### Server-Side Paging

Set max page size (e.g., 100) and return `@odata.nextLink`. Prevents clients from requesting unbounded result sets.

### Index Filter Columns

Ensure columns used in `$filter` and `$orderby` are indexed. `$filter=tolower(Name) eq 'widget'` prevents index usage -- consider case-insensitive collation instead.

### Streaming Large Results

For very large exports, consider:
- `$top` + `@odata.nextLink` pagination
- `$apply` to aggregate server-side instead of transferring raw data
- Async batch for long-running queries

## ETag and Concurrency

OData uses ETags for optimistic concurrency:
```http
GET /Products(42)
ETag: "abc123"

PATCH /Products(42)
If-Match: "abc123"
{"Price": 34.99}
```

If ETag does not match: `412 Precondition Failed`.

## OData in Microsoft Ecosystem

### Microsoft Graph API

Microsoft Graph is an OData v4.0 service:
```
GET https://graph.microsoft.com/v1.0/me/messages?$select=subject,from&$top=10&$filter=isRead eq false
```

### SharePoint REST API

SharePoint exposes OData endpoints:
```
GET /_api/web/lists/getbytitle('Documents')/items?$select=Title,Modified&$filter=Modified gt datetime'2024-01-01'
```

### Power BI / Excel

Power BI and Excel Power Query connect to OData feeds natively. The `$metadata` document enables auto-discovery of tables and relationships.

## OData in SAP Ecosystem

SAP Gateway exposes S/4HANA business objects as OData services. SAP-specific:
- SEGW transaction for service definition
- SAP annotations for UI rendering
- Delta queries for change tracking
- Draft handling for multi-step editing
