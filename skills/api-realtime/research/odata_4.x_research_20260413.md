# OData 4.x — Comprehensive Research

## 1. Overview and Architecture

OData (Open Data Protocol) is an OASIS standard that enables REST-based data services. It is sometimes described as "ODBC for the web." The protocol enables querying and manipulating data using standard HTTP, with a rich query syntax built on top of URLs.

**Current versions:**
- OData 4.0 (OASIS Standard, 2014, Errata 03 — 2016)
- OData 4.01 (OASIS Standard, 2020) — significant additions (JSON batch, alternateKeys, etc.)
- OData 4.02 (OASIS Committee Specification Draft, 2024) — latest

The protocol is defined in three parts:
1. **Part 1: Protocol** — HTTP interaction semantics
2. **Part 2: URL Conventions** — Query option syntax
3. **Part 3: CSDL** (Common Schema Definition Language) — Metadata format (XML and JSON)

OData extensions:
- **OData Extension for Data Aggregation 4.0** — `$apply` query option
- **OData Extension for Temporal Data** — bi-temporal querying
- **OData Vocabularies** — annotation terms (Core, Capabilities, Measures, Authorization)

---

## 2. Entity Data Model (EDM)

The EDM is the abstract model that describes the data exposed by an OData service. All OData concepts map to EDM types.

### Core EDM Concepts

**Entity Type**: A named structured type with a key. Corresponds to a database table row or domain object.
```xml
<EntityType Name="Product">
  <Key>
    <PropertyRef Name="ID"/>
  </Key>
  <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
  <Property Name="Name" Type="Edm.String" Nullable="false" MaxLength="100"/>
  <Property Name="Price" Type="Edm.Decimal" Precision="10" Scale="2"/>
  <Property Name="Category" Type="Edm.String"/>
  <NavigationProperty Name="Supplier" Type="Example.Supplier"/>
  <NavigationProperty Name="Reviews" Type="Collection(Example.Review)"/>
</EntityType>
```

**Complex Type**: Structured type without a key. Cannot be directly addressed by URL.
```xml
<ComplexType Name="Address">
  <Property Name="Street" Type="Edm.String"/>
  <Property Name="City" Type="Edm.String"/>
  <Property Name="Country" Type="Edm.String"/>
  <Property Name="PostalCode" Type="Edm.String"/>
</ComplexType>
```

**Entity Set**: A named collection of entity instances. Addressable via URL.
```xml
<EntitySet Name="Products" EntityType="Example.Product">
  <NavigationPropertyBinding Path="Supplier" Target="Suppliers"/>
  <NavigationPropertyBinding Path="Reviews" Target="Reviews"/>
</EntitySet>
```

**Singleton**: A named single entity instance (not in a collection).
```xml
<Singleton Name="Company" Type="Example.Company"/>
```

### EDM Primitive Types

| Type | Description | Example |
|------|-------------|---------|
| `Edm.String` | UTF-8 string | `'Hello'` |
| `Edm.Int32` | 32-bit signed integer | `42` |
| `Edm.Int64` | 64-bit signed integer | `9007199254740992` |
| `Edm.Decimal` | Decimal with precision/scale | `3.14` |
| `Edm.Double` | IEEE 754 double | `3.14e0` |
| `Edm.Boolean` | true/false | `true` |
| `Edm.DateTime` | Deprecated in v4; use DateTimeOffset | — |
| `Edm.DateTimeOffset` | Date/time with offset | `2024-01-15T10:30:00Z` |
| `Edm.Date` | Calendar date | `2024-01-15` |
| `Edm.TimeOfDay` | Time of day | `10:30:00.000` |
| `Edm.Duration` | ISO 8601 duration | `'P1DT2H'` |
| `Edm.Guid` | 128-bit UUID | `00000000-0000-0000-0000-000000000000` |
| `Edm.Binary` | Binary data | base64 encoded |
| `Edm.Stream` | Binary stream (separate resource) | — |
| `Edm.GeographyPoint` | Geographic point | — |

### Open Types

An entity type or complex type can be declared `OpenType="true"`, meaning instances can contain properties not defined in the schema. The server may return additional dynamic properties; clients must handle unknown properties.

```xml
<EntityType Name="Product" OpenType="true">
  <Key><PropertyRef Name="ID"/></Key>
  <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
  <Property Name="Name" Type="Edm.String"/>
  <!-- additional runtime properties allowed -->
</EntityType>
```

### Derived Types (Inheritance)

OData supports single inheritance for both entity types and complex types:
```xml
<EntityType Name="SpecialProduct" BaseType="Example.Product">
  <Property Name="SpecialAttribute" Type="Edm.String"/>
</EntityType>
```

Query for specific derived type using cast segment:
```
GET /Products/Example.SpecialProduct
GET /Products?$filter=isof(Example.SpecialProduct)
```

In OData 4.01, derived structured types can redefine the type of a complex property or navigation property to a more specific subtype.

---

## 3. Service Document and Metadata

### Service Document

The entry point at the service root URL. Describes available entity sets, singletons, and function imports.

```
GET https://services.odata.org/V4/TripPinServiceRW/
Accept: application/json
```

Response:
```json
{
  "@odata.context": "https://services.odata.org/V4/TripPinServiceRW/$metadata",
  "value": [
    { "name": "People", "kind": "EntitySet", "url": "People" },
    { "name": "Airlines", "kind": "EntitySet", "url": "Airlines" },
    { "name": "Airports", "kind": "EntitySet", "url": "Airports" },
    { "name": "Me", "kind": "Singleton", "url": "Me" },
    { "name": "GetNearestAirport", "kind": "FunctionImport", "url": "GetNearestAirport" }
  ]
}
```

### Metadata Document ($metadata)

The CSDL document describing the full schema. Retrieved via:
```
GET https://services.odata.org/V4/TripPinServiceRW/$metadata
```

Returns XML by default. JSON CSDL supported in OData 4.01+:
```
GET /service/$metadata
Accept: application/json
```

The `@odata.context` URL in every response points to the metadata document section describing the response shape:
```json
{
  "@odata.context": "https://api.example.com/odata/$metadata#Products",
  "value": [...]
}
```

---

## 4. URL Structure

```
https://service.example.com/odata/Products(1)/Supplier?$select=Name,Address&$expand=Contacts
```

Components:
- `https://service.example.com/odata` — service root
- `/Products` — entity set
- `(1)` — key predicate
- `/Supplier` — navigation property segment
- `?$select=Name,Address` — system query option
- `&$expand=Contacts` — another system query option

### Key Predicates

Simple key:
```
GET /Products(42)
GET /Products('widget-sku-001')
GET /Products(guid'00000000-0000-0000-0000-000000000001')
```

Composite key:
```
GET /OrderItems(OrderID=1,ItemNumber=3)
```

Alternate keys (OData 4.01):
```xml
<Annotation Term="Core.AlternateKeys">
  <Collection>
    <Record><PropertyValue Property="Key">
      <Collection><Record>
        <PropertyValue Property="Name" String="SKU"/>
      </Record></Collection>
    </PropertyValue></Record>
  </Collection>
</Annotation>
```

Then: `GET /Products(SKU='widget-001')`

---

## 5. System Query Options

### $filter

Filter the result set by a boolean expression.

**Comparison operators:**
```
$filter=Price lt 100
$filter=Category eq 'Electronics'
$filter=Name ne null
$filter=Price ge 10 and Price le 100
$filter=Category eq 'A' or Category eq 'B'
$filter=not (Status eq 'Archived')
```

**Arithmetic:**
```
$filter=Price mul Quantity gt 1000
$filter=Price add Tax eq 110
```

**String functions:**
```
$filter=contains(Name, 'Widget')
$filter=startswith(Name, 'Pro')
$filter=endswith(Name, 'Plus')
$filter=tolower(Category) eq 'electronics'
$filter=length(Name) gt 5
$filter=indexof(Name, 'Widget') ge 0
$filter=substring(Name, 0, 3) eq 'Pro'
$filter=concat(FirstName, ' ', LastName) eq 'John Doe'
```

**Date/time functions:**
```
$filter=year(CreatedAt) eq 2024
$filter=month(CreatedAt) eq 1
$filter=CreatedAt gt 2024-01-01T00:00:00Z
$filter=date(CreatedAt) eq 2024-01-15
$filter=time(CreatedAt) lt 12:00:00.000
```

**Math functions:**
```
$filter=round(Price) eq 100
$filter=floor(Price) ge 99
$filter=ceiling(Price) le 101
```

**Type functions:**
```
$filter=isof(Example.SpecialProduct)
$filter=isof(Category, Example.SpecialCategory)
```

**Null handling:**
```
$filter=MiddleName eq null
$filter=MiddleName ne null
```

### Lambda Operators: any / all

Lambda operators filter on collection properties. Introduced properly in OData v4.

**any** — true if predicate holds for at least one element:
```
# Products with at least one tag containing 'sale'
GET /Products?$filter=Tags/any(t: contains(t, 'sale'))

# Orders with at least one item over $100
GET /Orders?$filter=Items/any(i: i/Price gt 100)

# Users with at least one license for a specific SKU
GET /users?$filter=assignedLicenses/any(l: l/skuId eq guid'184efa21-98c3-4e5d-95ab-d07053a96e67')
```

**all** — true if predicate holds for all elements:
```
# Products where all reviews have rating >= 4
GET /Products?$filter=Reviews/all(r: r/Rating ge 4)

# Orders where all items are in stock
GET /Orders?$filter=Items/all(i: i/InStock eq true)
```

**Nested lambda:**
```
# Hotels with all rooms having TV and base rate under $100
GET /Hotels?$filter=Rooms/all(r: r/Amenities/any(a: a eq 'tv') and r/BaseRate lt 100.0)
```

**Empty collection behavior**: `any()` on empty collection returns false. `all()` on empty collection returns true (vacuous truth). `any()` with no predicate returns true if collection is non-empty.

### $select

Return only specified properties:
```
GET /Products?$select=ID,Name,Price
GET /Products(1)?$select=Name,Category,Supplier/Name
```

`*` selects all declared properties. Custom annotations excluded unless explicitly selected.

### $expand

Include related entities inline:
```
GET /Orders?$expand=Items
GET /Orders?$expand=Items,Customer
GET /Orders?$expand=Items($select=ProductID,Quantity,Price)
GET /Orders?$expand=Items($filter=Price gt 50;$orderby=Price desc;$top=10)
GET /Products?$expand=Supplier($expand=Contacts($select=Name,Email))
```

Multiple expansions separated by comma. Nested query options inside `$expand` use semicolons.

**OData 4.01 enhancements:**
- `$expand=*` — expands all navigation properties (use cautiously)
- `$levels=max` — recursively expand (tree structures)
- `$expand=Orders($count=true)` — include count of related entities

### $orderby

Sort results:
```
GET /Products?$orderby=Price
GET /Products?$orderby=Price desc
GET /Products?$orderby=Category asc,Price desc
GET /Products?$orderby=Supplier/Name
```

Null ordering: OData leaves null ordering to server implementation.

### $top and $skip

```
GET /Products?$top=10
GET /Products?$top=10&$skip=20
```

`$top=0` returns no items but may still return `@odata.count` if `$count=true`.

Server-side paging: Server may impose a maximum page size and return `@odata.nextLink` regardless of `$top`.

### $count

Include total count of matching records:
```
GET /Products?$count=true
```

Response includes:
```json
{
  "@odata.count": 1543,
  "value": [...]
}
```

Inline count (unlike SKIP/TOP, counts the full filtered result). Can also address count directly:
```
GET /Products/$count
GET /Products/$count?$filter=Category eq 'Electronics'
```

### $search

Full-text search (implementation-defined semantics):
```
GET /Products?$search=widget
GET /Products?$search="widget pro"
GET /Products?$search=widget OR gadget
GET /Products?$search=widget AND NOT discontinued
```

Syntax is free-form; servers define what fields are searched.

### $format

Request specific response format:
```
GET /Products?$format=json
GET /Products?$format=application/json;odata.metadata=full
GET /Products?$format=xml
```

Metadata levels:
- `odata.metadata=none` — minimal annotations
- `odata.metadata=minimal` — default; only @odata.context
- `odata.metadata=full` — all type annotations on every property

---

## 6. $apply — Data Aggregation

Defined in the separate OData Extension for Data Aggregation 4.0 specification.

### Basic Aggregate

```
GET /Products?$apply=aggregate(Price with average as AvgPrice)
GET /Products?$apply=aggregate($count as ProductCount)
GET /Products?$apply=aggregate(Price with sum as TotalValue, $count as Count)
```

**Aggregate methods:** `sum`, `min`, `max`, `average`, `countdistinct`, `$count`

### groupby

```
GET /Products?$apply=groupby((Category), aggregate(Price with average as AvgPrice))
GET /Products?$apply=groupby((Category, Status))
GET /Products?$apply=groupby((Supplier/Name), aggregate(Price with max as MaxPrice, $count as Count))
```

### filter + groupby (composed transformations)

```
GET /Products?$apply=filter(Category eq 'Electronics')/groupby((Status), aggregate($count as Count))
GET /Orders?$apply=filter(Status eq 'Shipped')/groupby((Customer/Country), aggregate(TotalAmount with sum as Revenue))
```

Transformations are applied left to right with `/` as the pipe operator.

### expand in $apply (OData 4.01)

Expand within aggregation to navigate to related entities before aggregating:
```
GET /Orders?$apply=expand(Items)/groupby((Category), aggregate(Items/Price with sum as Revenue))
```

### compute

Add computed properties:
```
GET /Products?$apply=compute(Price mul TaxRate as TaxAmount)
```

### Full aggregation example

```
GET /Orders?$apply=
  filter(OrderDate ge 2024-01-01T00:00:00Z)/
  groupby(
    (Customer/Country, Status),
    aggregate(
      $count as OrderCount,
      TotalAmount with sum as Revenue,
      TotalAmount with average as AvgOrder
    )
  )&$orderby=Revenue desc&$top=10
```

---

## 7. CRUD Operations

### Create (POST)

```http
POST /Products
Content-Type: application/json

{
  "Name": "New Widget",
  "Price": 29.99,
  "Category": "Gadgets"
}

HTTP/1.1 201 Created
Location: https://api.example.com/odata/Products(42)
Content-Type: application/json

{
  "@odata.context": ".../$metadata#Products/$entity",
  "ID": 42,
  "Name": "New Widget",
  "Price": 29.99,
  "Category": "Gadgets"
}
```

### Read (GET)

```http
GET /Products(42)
HTTP/1.1 200 OK
Content-Type: application/json
ETag: "abc123"

{
  "@odata.context": ".../$metadata#Products/$entity",
  "ID": 42,
  "Name": "New Widget"
}
```

### Update — Full (PUT)

Replaces all properties. Properties not sent are reset to defaults/null:
```http
PUT /Products(42)
If-Match: "abc123"
Content-Type: application/json

{
  "Name": "Updated Widget",
  "Price": 34.99,
  "Category": "Gadgets"
}

HTTP/1.1 204 No Content
ETag: "def456"
```

### Update — Partial (PATCH)

Only specified properties are changed:
```http
PATCH /Products(42)
If-Match: "abc123"
Content-Type: application/json

{
  "Price": 34.99
}

HTTP/1.1 204 No Content
```

### Delete

```http
DELETE /Products(42)
If-Match: "abc123"

HTTP/1.1 204 No Content
```

### Upsert (PATCH/PUT with If-None-Match: *)

```http
PATCH /Products(99)
If-None-Match: *
Content-Type: application/json

{
  "Name": "New Product",
  "Price": 19.99
}
```

Creates if doesn't exist, updates if exists.

---

## 8. Navigation Properties

### Reading Related Entities

```
GET /Orders(1)/Items                    — collection nav property
GET /Orders(1)/Items(3)                 — specific item
GET /Products(42)/Supplier              — single nav property
GET /Products(42)/Supplier/Name         — property on related entity
GET /Products(42)/Supplier/$ref         — reference (link) only
```

### Managing Relationships

**Add link (bind existing entity):**
```http
POST /Orders(1)/Items/$ref
Content-Type: application/json

{
  "@odata.id": "https://api.example.com/odata/Products(42)"
}
```

**Change single-value nav property:**
```http
PATCH /Products(42)/Supplier/$ref
Content-Type: application/json

{
  "@odata.id": "https://api.example.com/odata/Suppliers(7)"
}
```

**Remove link:**
```http
DELETE /Orders(1)/Items(3)/$ref
```

---

## 9. Deep Insert

Insert an entity and its related entities in a single request:

```http
POST /Orders
Content-Type: application/json

{
  "CustomerID": "ALFKI",
  "OrderDate": "2024-01-15T10:00:00Z",
  "Items": [
    {
      "ProductID": 42,
      "Quantity": 2,
      "UnitPrice": 29.99
    },
    {
      "ProductID": 7,
      "Quantity": 1,
      "UnitPrice": 149.99
    }
  ],
  "ShippingAddress": {
    "Street": "123 Main St",
    "City": "Anytown",
    "Country": "US"
  }
}

HTTP/1.1 201 Created
Location: /Orders(1001)
```

OData 4.01 adds Content-ID referencing within deep insert for referencing newly created entities in subsequent nested operations.

---

## 10. Functions and Actions

### Bound vs Unbound

- **Bound**: First parameter is an entity type or collection — callable via entity URL
- **Unbound**: No entity binding — imported at service root

### Functions (Side-effect free, GET)

**Unbound function:**
```xml
<Function Name="GetNearestAirport" IsComposable="true">
  <Parameter Name="lat" Type="Edm.Double"/>
  <Parameter Name="lon" Type="Edm.Double"/>
  <ReturnType Type="Example.Airport"/>
</Function>
<FunctionImport Name="GetNearestAirport" Function="Example.GetNearestAirport" EntitySet="Airports"/>
```

Call: `GET /GetNearestAirport(lat=37.7749,lon=-122.4194)`

**Bound function:**
```xml
<Function Name="MostRecent" IsBound="true">
  <Parameter Name="bindingParameter" Type="Collection(Example.Order)"/>
  <ReturnType Type="Example.Order"/>
</Function>
```

Call: `GET /Customers(1)/Orders/Example.MostRecent()`

### Actions (May have side effects, POST)

**Unbound action:**
```xml
<Action Name="ResetData">
  <ReturnType Type="Edm.Boolean"/>
</Action>
<ActionImport Name="ResetData" Action="Example.ResetData"/>
```

Call:
```http
POST /ResetData
Content-Type: application/json

{}

HTTP/1.1 200 OK
{"value": true}
```

**Bound action:**
```xml
<Action Name="CheckOut" IsBound="true">
  <Parameter Name="bindingParameter" Type="Example.Cart"/>
  <Parameter Name="paymentMethod" Type="Edm.String" Nullable="false"/>
  <ReturnType Type="Example.Order"/>
</Action>
```

Call:
```http
POST /Carts(42)/Example.CheckOut
Content-Type: application/json

{
  "paymentMethod": "CreditCard"
}
```

OData 4.01: Non-binding parameters can be marked optional (`Nullable="true"` acts as optional for actions).

---

## 11. Batch Requests ($batch)

Allows sending multiple requests in a single HTTP call. Reduces round trips.

### Multipart/Mixed Format (OData 4.0+)

```http
POST /odata/$batch
Content-Type: multipart/mixed; boundary=batch_abc123

--batch_abc123
Content-Type: application/http
Content-Transfer-Encoding: binary

GET Products(1) HTTP/1.1

--batch_abc123
Content-Type: multipart/mixed; boundary=changeset_xyz789

--changeset_xyz789
Content-Type: application/http
Content-Transfer-Encoding: binary

POST Products HTTP/1.1
Content-Type: application/json

{"Name": "New Product", "Price": 9.99}

--changeset_xyz789
Content-Type: application/http
Content-Transfer-Encoding: binary

PATCH Products(5) HTTP/1.1
Content-Type: application/json

{"Price": 14.99}

--changeset_xyz789--
--batch_abc123--
```

**Changeset**: A group of modification requests treated atomically. All succeed or all fail. GET requests cannot be inside changesets.

### JSON Batch Format (OData 4.01+)

More concise, allows dependency ordering via `dependsOn`:

```http
POST /odata/$batch
Content-Type: application/json

{
  "requests": [
    {
      "id": "r1",
      "method": "GET",
      "url": "Products(1)"
    },
    {
      "id": "r2",
      "atomicityGroup": "g1",
      "method": "POST",
      "url": "Orders",
      "headers": { "Content-Type": "application/json" },
      "body": { "CustomerID": "ALFKI", "Total": 99.99 }
    },
    {
      "id": "r3",
      "atomicityGroup": "g1",
      "dependsOn": ["r2"],
      "method": "POST",
      "url": "$r2/Items",
      "headers": { "Content-Type": "application/json" },
      "body": { "ProductID": 42, "Qty": 1 }
    }
  ]
}
```

**`atomicityGroup`** in JSON batch = changeset in multipart. **`dependsOn`** specifies execution ordering. `$r2` references the URL of request r2's result.

Response:
```json
{
  "responses": [
    { "id": "r1", "status": 200, "body": {...} },
    { "id": "r2", "status": 201, "headers": { "Location": "/Orders(1001)" }, "body": {...} },
    { "id": "r3", "status": 201, "body": {...} }
  ]
}
```

---

## 12. Delta Queries (Change Tracking)

Delta queries allow clients to retrieve only what changed since the last synchronization.

### Requesting Delta

First request — get initial data plus a delta link:
```http
GET /Products?$deltatoken=latest
```

Or add `Prefer: odata.track-changes` to any query:
```http
GET /Products?$filter=Category eq 'Electronics'
Prefer: odata.track-changes

HTTP/1.1 200 OK
Preference-Applied: odata.track-changes

{
  "@odata.context": ".../$metadata#Products",
  "@odata.deltaLink": "https://api.example.com/odata/Products?$deltatoken=abc123xyz",
  "value": [...]
}
```

### Subsequent Delta Requests

Use the `@odata.deltaLink` from the previous response:
```http
GET /Products?$deltatoken=abc123xyz

{
  "@odata.deltaLink": "https://api.example.com/odata/Products?$deltatoken=def456uvw",
  "value": [
    {
      "@odata.id": "/Products(42)",
      "ID": 42,
      "Price": 34.99
    },
    {
      "@odata.context": ".../$metadata#Products/$deletedEntity",
      "id": "/Products(7)",
      "reason": "deleted"
    }
  ]
}
```

Delta payload contains:
- Modified entities (full or partial, depending on server implementation)
- Deleted entities as `@odata.context: .../$deletedEntity` entries with `reason: "deleted"` or `"changed"`

### Delta in Microsoft Ecosystem

**Microsoft Graph delta query:**
```
GET https://graph.microsoft.com/v1.0/users/delta

HTTP/1.1 200 OK
{
  "@odata.deltaLink": "https://graph.microsoft.com/v1.0/users/delta?$deltaToken=GqD...",
  "value": [...]
}
```

Microsoft Dataverse (Power Platform):
```http
GET /api/data/v9.2/accounts
Prefer: odata.track-changes

HTTP/1.1 200 OK
{
  "@odata.deltaLink": ".../accounts?$deltatoken=xxx",
  "value": [...]
}
```

Dynamics 365 Finance & Operations: Uses `changetracking` annotation in metadata and `DataAreId` field for change scoping.

---

## 13. Stream Properties

Stream properties allow binary data to be associated with an entity while stored/transferred separately.

```xml
<EntityType Name="Document" HasStream="true">
  <Key><PropertyRef Name="ID"/></Key>
  <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
  <Property Name="Name" Type="Edm.String"/>
  <Property Name="Content" Type="Edm.Stream"/>
</EntityType>
```

Reading stream:
```
GET /Documents(1)/$value          — default stream
GET /Documents(1)/Content         — named stream property
```

Uploading stream:
```http
PUT /Documents(1)/$value
Content-Type: application/pdf

[binary content]
```

OData 4.01: Stream properties can be requested inline within a response using `$expand`:
```
GET /Documents?$expand=Content
```

---

## 14. Microsoft Ecosystem

### ASP.NET Core OData 8.x

NuGet: `Microsoft.AspNetCore.OData` (v8.x for .NET 6+)

**Setup:**
```csharp
// Program.cs
builder.Services.AddControllers()
    .AddOData(options =>
    {
        options.Select().Filter().OrderBy().Expand().Count().SetMaxTop(100);
        options.AddRouteComponents("odata", GetEdmModel());
    });

static IEdmModel GetEdmModel()
{
    var builder = new ODataConventionModelBuilder();
    builder.EntitySet<Product>("Products");
    builder.EntitySet<Order>("Orders");
    builder.EntitySet<Customer>("Customers");
    return builder.GetEdmModel();
}
```

**Controller:**
```csharp
[ApiController]
[Route("odata")]
public class ProductsController : ODataController
{
    private readonly DbContext _db;

    [HttpGet("Products")]
    [EnableQuery(MaxExpansionDepth = 3, MaxNodeCount = 100, PageSize = 100)]
    public IQueryable<Product> Get() => _db.Products;

    [HttpGet("Products({key})")]
    [EnableQuery]
    public IActionResult Get([FromRoute] int key)
    {
        var product = _db.Products.FirstOrDefault(p => p.Id == key);
        if (product == null) return NotFound();
        return Ok(product);
    }

    [HttpPost("Products")]
    public async Task<IActionResult> Post([FromBody] Product product)
    {
        _db.Products.Add(product);
        await _db.SaveChangesAsync();
        return Created(product);
    }

    [HttpPatch("Products({key})")]
    public async Task<IActionResult> Patch([FromRoute] int key, [FromBody] Delta<Product> delta)
    {
        var product = await _db.Products.FindAsync(key);
        if (product == null) return NotFound();
        delta.Patch(product);
        await _db.SaveChangesAsync();
        return Updated(product);
    }
}
```

**[EnableQuery] parameters:**
- `MaxExpansionDepth` — limit `$expand` depth (prevents runaway queries)
- `MaxNodeCount` — limit complexity of `$filter` expression tree
- `PageSize` — server-enforced page size (ignores or caps client `$top`)
- `MaxTop` — maximum value allowed for `$top`
- `AllowedQueryOptions` — bitmask of allowed query options

### Microsoft Graph API

Graph API is built on OData 4.0. Base URL: `https://graph.microsoft.com/v1.0/`

Key OData features used:
```
GET /users?$select=id,displayName,mail&$top=25
GET /groups?$filter=startswith(displayName,'Sales')
GET /users/{id}/memberOf?$expand=members($select=id,displayName)
GET /me/events?$filter=start/dateTime ge '2024-01-01T00:00:00'
GET /drives/{id}/items/delta
```

### Microsoft Dynamics 365

- **Finance & Operations**: OData endpoint at `/data/` prefix. Entities exposed as data entities. Use `$crosscompany=true` for cross-company queries.
- **Customer Engagement / Dataverse**: OData endpoint at `/api/data/v9.x/`. Full OData 4.0 support including delta, $apply, $batch.
- **Business Central**: OData v4 at `/api/v2.0/` or custom pages via OData.

### SharePoint

SharePoint REST API supports OData-style queries but with some limitations:
```
GET /_api/lists/getbytitle('Documents')/items?$select=Title,Created&$filter=Created gt '2024-01-01T00:00:00Z'&$top=100&$orderby=Created desc
```

SharePoint uses `listItemEntityTypeFullName` for creating items. `$expand` works for lookup fields. Threshold of 5000 items for list views applies to OData queries too — use indexed columns and `$filter` on indexed fields.

---

## 15. SAP OData Services

SAP uses OData extensively:

- **Gateway** (OData 2.0/4.0): SAP Gateway framework for on-premise systems (ECC, S/4HANA on-prem)
- **S/4HANA Cloud APIs**: OData 4.0 services published on SAP API Business Hub
- **SAP Cloud SDK**: JavaScript/Java SDK that wraps OData services with typed clients

**SAP-specific conventions:**
- Service names often follow pattern: `API_PRODUCT_SRV`, `API_SALES_ORDER_SRV`
- SAP Gateway uses `sap-client=100` as URL parameter for client selection
- Cross-site request forgery: GET `/`  with `x-csrf-token: Fetch` header first, then use returned token for modifications

```bash
# Fetch CSRF token
curl -X GET https://host/sap/opu/odata/sap/API_PRODUCT_SRV/ \
  -H "x-csrf-token: Fetch" \
  -H "Authorization: Basic ..." \
  -c cookies.txt

# Use token for create
curl -X POST https://host/sap/opu/odata/sap/API_PRODUCT_SRV/A_Product \
  -H "x-csrf-token: <token from above>" \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"Material": "TEST001", "MaterialType": "FERT"}'
```

---

## 16. Apache Olingo

Apache Olingo is the primary open-source Java library for OData client and server development. Originally donated by SAP (used in SAP Gateway).

### Modules

- **Olingo V4 Server** — build OData 4.0 services on Java/Spring
- **Olingo V4 Client** — consume OData 4.0 services from Java
- **Olingo V2** — legacy OData 2.0 support (still in use for older SAP systems)

### Server Implementation (OData 4.0)

```java
@WebServlet(urlPatterns = {"/DemoService.svc/*"})
public class DemoServlet extends HttpServlet {
    @Override
    protected void service(HttpServletRequest req, HttpServletResponse resp) {
        ODataHttpHandler handler = OData.newInstance()
            .createHandler(getEdmProvider());
        handler.register(new DemoEntityCollectionProcessor());
        handler.register(new DemoEntityProcessor());
        handler.process(req, resp);
    }
}

public class DemoEntityCollectionProcessor implements EntityCollectionProcessor {
    public void readEntityCollection(ODataRequest request, ODataResponse response,
            UriInfo uriInfo, ContentType responseFormat) {
        // Parse URI, apply query options, build response
        EntityCollection entityCollection = getData();
        ODataSerializer serializer = odata.createSerializer(responseFormat);
        SerializerResult result = serializer.entityCollection(serviceMetadata,
            entityType, entityCollection,
            EntityCollectionSerializerOptions.with()
                .contextURL(ContextURL.with().entitySet(entitySet).build())
                .build());
        response.setContent(result.getContent());
        response.setStatusCode(HttpStatusCode.OK.getStatusCode());
        response.setHeader(HttpHeader.CONTENT_TYPE, responseFormat.toContentTypeString());
    }
}
```

### Client Usage (OData 4.0)

```java
ODataClient client = ODataClientFactory.getClient();
URI serviceUri = URI.create("https://services.odata.org/V4/TripPinServiceRW/");
URI peopleUri = client.newURIBuilder(serviceUri.toString())
    .appendEntitySetSegment("People")
    .filter("LastName eq 'Heathcote'")
    .select("FirstName", "LastName", "UserName")
    .top(10)
    .build();

ODataRetrieveResponse<ClientEntitySet> response = 
    client.getRetrieveRequestFactory()
          .getEntitySetRequest(peopleUri)
          .execute();

ClientEntitySet entitySet = response.getBody();
for (ClientEntity entity : entitySet.getEntities()) {
    System.out.println(entity.getProperty("UserName").getValue());
}
```

---

## 17. When to Use OData vs REST vs GraphQL

| Criteria | OData | Custom REST | GraphQL |
|----------|-------|-------------|---------|
| Standardized query language | Yes | No | Yes |
| Client-defined queries | Yes (within limits) | No | Yes |
| Binary protocol | No | No | No |
| Schema introspection | Yes ($metadata) | Optional (OpenAPI) | Yes (introspection) |
| Aggregation built-in | Yes ($apply) | No | No (resolver level) |
| Change tracking | Yes (delta) | No | No |
| Batch operations | Yes ($batch) | Custom | Mutations |
| Subscription/real-time | No | SSE/WebSocket | Subscriptions |
| Microsoft ecosystem | First-class | Good | Good |
| SAP ecosystem | First-class | Partial | Rare |
| Learning curve | High | Low | Medium |
| Tooling maturity | Medium | High | High |

**Use OData when:**
- Deep Microsoft ecosystem integration (Dynamics, SharePoint, Graph)
- SAP backend systems
- Power BI / Excel data connectivity required (Power Query uses OData)
- Need rich ad-hoc query capabilities for enterprise data consumers
- Replacing database-direct access with governed HTTP API
- Report/analytics use cases where different clients need different projections

**Use custom REST when:**
- Public-facing API where simplicity matters
- Mobile clients with known data requirements
- Fine-grained control over response shape and caching
- Non-tabular or highly irregular data

**Use GraphQL when:**
- Multiple clients (web, mobile, IoT) with varying data needs
- Rapid iteration with frontend teams
- Complex object graphs without tabular nature
- Real-time subscriptions required
- No Microsoft/SAP ecosystem constraints

---

## 18. Performance Considerations

### N+1 Problem with $expand

The most common OData performance trap. When expanding a navigation property, naive implementations execute one query per parent entity:

```
GET /Orders?$expand=Items
```

Poor implementation: 1 query for orders + N queries for items (one per order).
Correct implementation: JOIN in a single query, or batch load with `WHERE OrderID IN (...)`.

**ASP.NET Core OData with EF Core** handles this correctly when using `IQueryable` — EF Core translates the entire OData query including `$expand` into optimized SQL with JOINs.

**MaxExpansionDepth**: Set a maximum in `[EnableQuery]` to prevent exponential join depth:
```csharp
[EnableQuery(MaxExpansionDepth = 3)]
```

Deep: `?$expand=A($expand=B($expand=C($expand=D)))` — 4 levels of JOINs can be very expensive.

### Indexed Columns for $filter and $orderby

OData `$filter` translates directly to SQL `WHERE`. Ensure columns used in `$filter` are indexed. Particularly important for:
- DateTime range filters
- Category/status equality filters
- Sort columns in `$orderby`

### $top vs Server-Side Paging

Always set server-side `PageSize` in `[EnableQuery]`. Never allow unbounded queries:
```csharp
[EnableQuery(PageSize = 100, MaxTop = 500)]
```

Without this, `GET /Products` returns all millions of rows.

### $select to Reduce Payload

Encourage clients to use `$select` to reduce transferred data:
```
GET /Products?$select=ID,Name,Price   — 3 columns
GET /Products                          — all columns, often 10-20x larger
```

Can be enforced in some implementations by requiring `$select` or providing a default select list.

### $count Performance

`$count=true` requires two database operations: one for data, one for count (unless using window functions). For very large datasets, consider:
- Approximate counts from statistics
- Cached counts with TTL
- Excluding count from paginated endpoints

### Azure DevOps Analytics OData Guidelines

Microsoft publishes specific OData query guidelines for Azure DevOps:
- Do not use `Revisions` in `$expand` (explicitly blocked)
- Always filter with `$filter` before `$expand`
- Use `$select` to limit columns
- Avoid expanding multi-valued navigation properties without filtering
- Use `$apply` for aggregations rather than fetching raw data and computing client-side

---

## 19. Security

### Query Validation

Always validate and limit incoming OData queries. Without limits:
- A client can request `$expand=A($expand=B($expand=C(...)))` — exponential joins
- `$filter` with complex nested `or` expressions — exponential predicate evaluation
- `$top=999999999` — unbounded result sets

In ASP.NET Core OData:
```csharp
[EnableQuery(
    MaxExpansionDepth = 3,
    MaxNodeCount = 50,          // limit filter complexity
    MaxTop = 1000,
    MaxSkip = 100000,
    AllowedQueryOptions = AllowedQueryOptions.Select |
                          AllowedQueryOptions.Filter |
                          AllowedQueryOptions.OrderBy |
                          AllowedQueryOptions.Top |
                          AllowedQueryOptions.Skip |
                          AllowedQueryOptions.Count
)]
```

### Injection Prevention

OData filter expressions are parsed into expression trees before execution, not concatenated into SQL strings. When using EF Core with `IQueryable`, there is no SQL injection risk — queries are parameterized automatically.

Custom processors that build SQL from OData must use parameterized queries.

### Authorization / Row-Level Security

OData does not define authorization. Implement at the IQueryable level:

```csharp
[EnableQuery]
public IQueryable<Order> Get()
{
    var userId = User.FindFirst("sub")?.Value;
    // Only return orders belonging to current user
    return _db.Orders.Where(o => o.OwnerUserId == userId);
}
```

For resource-level authorization, check permissions before returning single entities:
```csharp
[HttpGet("Orders({key})")]
public async Task<IActionResult> Get([FromRoute] int key)
{
    var order = await _db.Orders.FindAsync(key);
    if (order == null) return NotFound();
    if (!await _authService.CanAccess(User, order)) return Forbid();
    return Ok(SingleResult.Create(_db.Orders.Where(o => o.Id == key)));
}
```

### CSRF for SAP Services

SAP OData services require a CSRF token for all write operations. Fetch it first:
```
GET /sap/opu/odata/sap/SERVICE_NAME/
x-csrf-token: Fetch
→ x-csrf-token: <token>
```

Then include in write requests: `x-csrf-token: <token>`

---

## 20. Diagnostics and Common Errors

### Error Response Format

OData errors use a standardized JSON format:
```json
{
  "error": {
    "code": "ValidationError",
    "message": "The property 'foo' does not exist on entity type 'Product'.",
    "innererror": {
      "message": "...",
      "type": "System.InvalidOperationException",
      "stacktrace": "..."
    }
  }
}
```

HTTP status codes: `400` for bad requests/query errors, `404` for missing entities, `405` for unsupported operations, `501` for not implemented.

### Common Query Errors

**Property does not exist:**
```
400 Bad Request
"message": "Could not find a property named 'LastNam' on type 'Example.Person'."
```
Fix: Verify exact property name in `/$metadata`. Property names are case-sensitive.

**Navigation property not found:**
```
400 Bad Request
"message": "Could not find a property named 'Produts' on type 'Example.Order'."
```

**$expand not allowed:**
```
400 Bad Request
"message": "The query specified in the URI is not valid. The property 'Revisions' cannot be used in the $expand query option."
```
Certain properties are blocked from expand (e.g., expensive collections in Azure DevOps Analytics).

**Filter type mismatch:**
```
400 Bad Request
"message": "Operator 'Add' incompatible with operand types 'Edm.String' and 'Edm.Int32'."
```

**Max expansion depth exceeded:**
```
400 Bad Request
"message": "The depth of the expand is 4, which exceeds the maximum allowed depth of 3."
```

**Max top exceeded:**
```
400 Bad Request
"message": "$top value '10000' exceeds the maximum allowed value '1000'."
```

**Unsupported aggregation method:**
```
400 Bad Request
"message": "The aggregation method 'median' is not supported."
```

### Debugging $metadata

Always check `/$metadata` first when troubleshooting:
```bash
curl https://api.example.com/odata/$metadata | xmllint --format -
```

Common metadata issues:
- Navigation property binding missing — `$expand` will fail or return no data
- Wrong entity set name — case-sensitive
- Missing `Nullable="false"` — POST will fail on required fields
- `ReferentialConstraint` missing — `$expand` may not auto-join correctly

### Performance Profiling

For ASP.NET Core OData with EF Core:
```csharp
// Enable EF Core query logging
services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlServer(connectionString)
       .LogTo(Console.WriteLine, LogLevel.Information)
       .EnableSensitiveDataLogging());
```

Inspect generated SQL — look for:
- Missing `WHERE` clauses (unbounded scans)
- N+1 queries (separate SELECT per entity)
- Missing `TOP` clause when `$top` should be applied

For Azure DevOps OData, use `$apply=aggregate($count as Count)` before fetching data to check result set size.

### Testing OData Services

**curl examples:**
```bash
# Get metadata
curl -s "https://api.example.com/odata/\$metadata" -H "Accept: application/xml"

# Test filter
curl -s "https://api.example.com/odata/Products?\$filter=Price%20lt%20100&\$select=ID,Name,Price" \
  -H "Accept: application/json"

# Test expand with filter
curl -s "https://api.example.com/odata/Orders?\$expand=Items(\$filter=Quantity%20gt%201)&\$top=5" \
  -H "Accept: application/json"

# Test aggregation
curl -s "https://api.example.com/odata/Products?\$apply=groupby((Category),aggregate(\$count%20as%20Count))" \
  -H "Accept: application/json"
```

**OData tools:**
- **OData Voyager** — browser-based OData explorer
- **OData CLI** — Microsoft CLI for generating OData client code
- **Postman** — full support for OData query option construction
- **Power BI** — has built-in OData connector; useful for testing data shape
- **LINQPad** — can connect to OData services directly

---

## 21. OData 4.01 vs 4.0 Key Differences

| Feature | 4.0 | 4.01 |
|---------|-----|------|
| Batch format | Multipart/mixed only | JSON batch added |
| Batch ordering | No dependency control | `dependsOn` in JSON batch |
| Alternate keys | Via annotations only | First-class support |
| $expand * | Not supported | Expand all nav properties |
| $levels | Limited | `max` value allowed |
| Deep insert Content-ID | Limited | Full Content-ID referencing |
| Derived type redefine | Not allowed | Properties can narrow type |
| Optional action params | Not specified | Explicitly supported |
| Stream inline in expand | Not supported | Supported |
| CSDL JSON format | Not specified | Standardized |

---

## Key References

- OData 4.0 Protocol: https://docs.oasis-open.org/odata/odata/v4.0/odata-v4.0-part1-protocol.html
- OData 4.01 Protocol: https://docs.oasis-open.org/odata/odata/v4.01/odata-v4.01-part1-protocol.html
- OData 4.02 (Draft): https://oasis-tcs.github.io/odata-specs/odata-protocol/odata-protocol.html
- OData Data Aggregation Extension: https://docs.oasis-open.org/odata/odata-data-aggregation-ext/v4.0/cs01/odata-data-aggregation-ext-v4.0-cs01.html
- ASP.NET Core OData 8 Overview: https://learn.microsoft.com/en-us/odata/webapi-8/Overview
- ASP.NET Core OData Query Options: https://learn.microsoft.com/en-us/odata/webapi-8/fundamentals/query-options
- Microsoft Graph Delta Query: https://learn.microsoft.com/en-us/graph/delta-query-overview
- Apache Olingo: https://olingo.apache.org/
- OData.org Documentation: https://www.odata.org/documentation/
