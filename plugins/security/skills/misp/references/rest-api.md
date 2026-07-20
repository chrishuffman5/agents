# MISP REST API: Key Endpoints and Search Body

### Key Endpoints

```
GET /events  -- List events
POST /events/add  -- Create event
GET /events/{id}  -- Get event
PUT /events/{id}  -- Update event
DELETE /events/{id}  -- Delete event

POST /attributes/add/{event_id}  -- Add attribute to event
GET /attributes/{id}  -- Get attribute
POST /attributes/delete/{id}  -- Delete attribute

POST /events/restSearch  -- Advanced event search
POST /attributes/restSearch  -- Advanced attribute search

GET /tags  -- List all tags
POST /sharing_groups/add  -- Create sharing group

GET /feeds  -- List feeds
POST /feeds/fetchFromFeed/{feed_id}  -- Fetch feed now

GET /warninglists  -- List warninglists
```

### REST Search Body

```json
{
  "returnFormat": "json",
  "type": "ip-dst",
  "to_ids": 1,
  "last": "7d",
  "tags": ["tlp:amber"],
  "includeEventTags": true,
  "page": 1,
  "limit": 100
}
```
