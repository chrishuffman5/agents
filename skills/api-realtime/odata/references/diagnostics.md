# OData Diagnostics

## $filter Errors

### "The query specified in the URI is not valid"

**Common causes:**
- Missing quotes around string values: use `$filter=Name eq 'Widget'` not `$filter=Name eq Widget`
- Wrong date format: use `2024-01-15T10:00:00Z` (ISO 8601 with timezone)
- Wrong GUID format: use `$filter=Id eq guid'00000000-0000-0000-0000-000000000001'` (OData 4.0) or just the GUID value (OData 4.01)
- Using `==` instead of `eq`: OData uses `eq`, `ne`, `gt`, `ge`, `lt`, `le`
- Missing parentheses in logical expressions

### Lambda Operator Issues

**"The parent value for a property access of a non-entity type is null"**

**Fix:** The navigation property is null. Add a null check:
```
$filter=Items/any() and Items/any(i: i/Price gt 100)
```

**"any/all not supported on this property"**

**Fix:** Lambda operators only work on collection navigation properties and primitive collections. Verify the property is `Collection(Type)`.

### Function Not Found

```
"Unknown function 'customFunction'"
```

**Fix:** String functions are case-sensitive in some implementations. Use lowercase: `contains()`, `startswith()`, `endswith()`, `tolower()`. Check if the server supports the function.

## $expand Errors

### "Expand depth exceeded"

**Fix:** Server limits expansion depth. Reduce nesting or fetch related data in separate requests.

### "Navigation property not found"

**Fix:** Check property name in `$metadata`. Navigation properties are defined on the entity type, not entity set. Verify spelling and case.

### Circular $expand

```
$expand=Parent($expand=Children($expand=Parent($levels=max)))
```

**Fix:** Use `$levels` with a specific number instead of `max`:
```
$expand=Children($levels=3)
```

## $apply / Aggregation Errors

### "Unknown transformation"

**Fix:** `$apply` requires the OData Extension for Data Aggregation. Not all servers support it. Check server capabilities in `$metadata` annotations.

### "Cannot aggregate navigation property"

**Fix:** Use `expand()` within `$apply` to navigate before aggregating:
```
$apply=expand(Items)/groupby((Category), aggregate(Items/Price with sum as Revenue))
```

## Batch Errors

### "Content-ID reference not found"

In JSON batch: ensure `dependsOn` references a valid `id` from a previous request. Reference uses `$rN` syntax in URL.

### "Changeset failed atomically"

All requests in an `atomicityGroup` failed because one failed. Check individual request errors in the batch response.

### Multipart Parsing Errors

- Boundary string in `Content-Type` must match boundary markers
- Each part requires `Content-Type: application/http` and `Content-Transfer-Encoding: binary`
- Blank line between headers and body

## Metadata Issues

### "$metadata returns 404"

**Fix:** Verify the service root URL. Common mistake: `GET /api/Products/$metadata` instead of `GET /api/$metadata` (metadata is at service root, not entity set).

### "Type not found in metadata"

**Fix:** The type referenced in the request does not exist in the EDM. Check `$metadata` for correct type names including namespace: `Example.Product`, not just `Product`.

### Client Generation Fails

- Verify `$metadata` is valid CSDL XML
- Check for unsupported annotations that confuse the client generator
- Try `$format=json` for JSON CSDL (OData 4.01+)

## Performance Issues

### Slow $filter Queries

| Symptom | Cause | Fix |
|---|---|---|
| Slow string filter | No index on column | Add database index |
| `tolower()` in filter | Function prevents index usage | Use case-insensitive collation |
| Large `$skip` value | Offset scan | Use server-driven paging with `@odata.nextLink` |
| Complex `any()/all()` | Subquery per row | Optimize join strategy server-side |

### Slow $expand

**Cause:** Expanding many navigation properties generates multiple JOINs or subqueries.

**Fix:**
1. Use `$select` within `$expand` to reduce columns
2. Limit expansion depth
3. Fetch related data in separate requests for large collections
4. Consider `$apply` with `groupby` to aggregate instead of expanding

### Large Payloads

**Fix:**
1. Use `$select` to reduce properties
2. Use `$top` with server-driven paging
3. Request `odata.metadata=none` to reduce metadata overhead
4. Enable response compression (gzip)

## Common Status Codes

| Code | OData Meaning |
|---|---|
| 200 OK | Successful read or update |
| 201 Created | Successful create (POST) |
| 204 No Content | Successful delete or update without body |
| 400 Bad Request | Invalid query syntax |
| 401 Unauthorized | Authentication required |
| 403 Forbidden | Insufficient permissions |
| 404 Not Found | Entity or entity set not found |
| 405 Method Not Allowed | HTTP method not supported on this resource |
| 409 Conflict | Concurrency conflict (ETag mismatch on create) |
| 412 Precondition Failed | ETag mismatch on update/delete |
| 501 Not Implemented | Query option not supported by server |

## Debugging Tools

### Browser / curl

```bash
# Service document
curl https://api.example.com/odata/

# Metadata
curl https://api.example.com/odata/$metadata

# Query with verbose output
curl -v "https://api.example.com/odata/Products?\$filter=Price gt 20&\$select=Name,Price&\$top=5"
```

Note: escape `$` in shell with `\$` or use single quotes.

### Postman

Import OData collection from `$metadata` URL. Postman generates request templates for each entity set.

### OData Explorer

Microsoft provides OData sample services for testing:
- TripPin: `https://services.odata.org/V4/TripPinServiceRW/`
- Northwind: `https://services.odata.org/V4/Northwind/Northwind.svc/`
