# OData Architecture Deep Dive

## Entity Data Model (EDM)

### Entity Type

Named structured type with a key. Corresponds to a domain object:
```xml
<EntityType Name="Product">
  <Key><PropertyRef Name="ID"/></Key>
  <Property Name="ID" Type="Edm.Int32" Nullable="false"/>
  <Property Name="Name" Type="Edm.String" MaxLength="100"/>
  <Property Name="Price" Type="Edm.Decimal" Precision="10" Scale="2"/>
  <NavigationProperty Name="Supplier" Type="Example.Supplier"/>
  <NavigationProperty Name="Reviews" Type="Collection(Example.Review)"/>
</EntityType>
```

### Complex Type

Structured type without a key. Cannot be directly addressed by URL:
```xml
<ComplexType Name="Address">
  <Property Name="Street" Type="Edm.String"/>
  <Property Name="City" Type="Edm.String"/>
  <Property Name="Country" Type="Edm.String"/>
</ComplexType>
```

### Entity Set and Singleton

```xml
<EntitySet Name="Products" EntityType="Example.Product">
  <NavigationPropertyBinding Path="Supplier" Target="Suppliers"/>
</EntitySet>
<Singleton Name="Company" Type="Example.Company"/>
```

### Derived Types (Inheritance)

```xml
<EntityType Name="SpecialProduct" BaseType="Example.Product">
  <Property Name="SpecialAttribute" Type="Edm.String"/>
</EntityType>
```

Query derived type: `GET /Products/Example.SpecialProduct` or `$filter=isof(Example.SpecialProduct)`.

### Open Types

Entity types declared `OpenType="true"` can contain dynamic properties not defined in schema. Clients must handle unknown properties.

### EDM Primitive Types

| Type | Description |
|---|---|
| `Edm.String` | UTF-8 string |
| `Edm.Int32` / `Edm.Int64` | Integer |
| `Edm.Decimal` | Decimal with precision/scale |
| `Edm.Boolean` | true/false |
| `Edm.DateTimeOffset` | Date/time with offset |
| `Edm.Date` / `Edm.TimeOfDay` | Date or time only |
| `Edm.Guid` | 128-bit UUID |
| `Edm.Binary` | Binary data |
| `Edm.Stream` | Binary stream |

## URL Structure

```
https://api.example.com/odata/Products(1)/Supplier?$select=Name&$expand=Contacts
```

Components: service root, entity set, key predicate, navigation segment, query options.

### Key Predicates

```
GET /Products(42)
GET /Products('widget-sku-001')
GET /OrderItems(OrderID=1,ItemNumber=3)
```

Alternate keys (4.01): `GET /Products(SKU='widget-001')`.

## Metadata

### Service Document

Entry point listing available entity sets, singletons, and function imports:
```json
{
  "@odata.context": ".../$metadata",
  "value": [
    {"name": "Products", "kind": "EntitySet", "url": "Products"},
    {"name": "Me", "kind": "Singleton", "url": "Me"}
  ]
}
```

### CSDL ($metadata)

```
GET /odata/$metadata
```

Returns XML (default) or JSON (4.01+). The `@odata.context` URL in every response points to the metadata section describing the response shape.

### Metadata Levels

- `odata.metadata=none` -- minimal annotations
- `odata.metadata=minimal` -- default; only `@odata.context`
- `odata.metadata=full` -- all type annotations on every property

## Navigation Properties

```
GET /Orders(1)/Items                 -- collection navigation
GET /Products(42)/Supplier           -- single navigation
GET /Products(42)/Supplier/Name      -- property on related entity
GET /Products(42)/Supplier/$ref      -- reference link only
```

### Managing Relationships

```http
POST /Orders(1)/Items/$ref
{"@odata.id": "https://api.example.com/odata/Products(42)"}
```

## CRUD Operations

### Create (POST)
```http
POST /Products
Content-Type: application/json
{"Name": "Widget", "Price": 29.99}

HTTP/1.1 201 Created
Location: /odata/Products(42)
```

### Read (GET)
```http
GET /Products(42)
HTTP/1.1 200 OK
ETag: "abc123"
```

### Update -- Full (PUT) / Partial (PATCH)

PUT replaces all properties. PATCH changes only specified properties. Include `If-Match` for optimistic concurrency.

### Delete
```http
DELETE /Products(42)
If-Match: "abc123"
```

### Upsert
```http
PATCH /Products(99)
If-None-Match: *
{"Name": "New Product", "Price": 19.99}
```

## Functions and Actions

**Functions** are side-effect-free (GET). **Actions** may have side effects (POST).

**Bound function** (called via entity URL):
```
GET /Customers(1)/Orders/Example.MostRecent()
```

**Unbound function** (called at service root):
```
GET /GetNearestAirport(lat=37.7749,lon=-122.4194)
```

**Bound action:**
```http
POST /Carts(42)/Example.CheckOut
{"paymentMethod": "CreditCard"}
```

## Deep Insert

Insert entity and related entities in one request:
```json
POST /Orders
{
  "CustomerID": "ALFKI",
  "Items": [
    {"ProductID": 42, "Quantity": 2},
    {"ProductID": 7, "Quantity": 1}
  ],
  "ShippingAddress": {"Street": "123 Main", "City": "Anytown"}
}
```
