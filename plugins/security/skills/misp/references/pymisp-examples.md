# PyMISP Common Operations

**Create an event:**
```python
from pymisp import MISPEvent, MISPAttribute

event = MISPEvent()
event.info = "LockBit 3.0 campaign against healthcare"
event.threat_level_id = 1  # High
event.analysis = 1  # Ongoing
event.distribution = 1  # This Community

# Add attribute
attribute = MISPAttribute()
attribute.type = "ip-dst"
attribute.value = "198.51.100.42"
attribute.comment = "LockBit 3.0 C2 server"
attribute.to_ids = True
event.add_attribute("Network activity", attribute)

# Add tag
event.add_tag("tlp:amber")

result = misp.add_event(event)
```

**Search for events/attributes:**
```python
# Search by attribute value
results = misp.search(
    value="198.51.100.42",
    type_attribute="ip-dst",
    to_ids=True,
    include_correlations=True
)

# Search by tag
results = misp.search(tags=["tlp:amber", "ransomware"])

# Get events updated in last 24 hours
from datetime import datetime, timedelta
yesterday = datetime.now() - timedelta(hours=24)
results = misp.search(timestamp=int(yesterday.timestamp()))
```

**Export as STIX:**
```python
stix_bundle = misp.get_stix(
    event_id=1234,
    misp_stix_format="stix20"  # or "stix21"
)
```

**Add object to event:**
```python
from pymisp.tools import FileObject

event = misp.get_event(event_id, pythonify=True)
file_obj = FileObject(filepath="/path/to/malware.exe")
event.add_object(file_obj)
misp.update_event(event)
```
