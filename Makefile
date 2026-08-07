DATA_JSON = data-builder/metropolist-data.json
DATA_CHANGES = data-builder/metropolist-changes.json
TRANSIT_STORE = store-builder/transit.store
TRANSIT_INFO = store-builder/transit-info.json
APP_STORE = metropolist/metropolist/transit.store
APP_INFO = metropolist/metropolist/transit-info.json

.PHONY: all fetch data store import icons clean

all: store

# Step 0 (optional): Fetch latest raw data from IDFM APIs
fetch:
	cd data-builder && bun run fetch

# Step 1: Build JSON from raw IDFM/GTFS data (always runs — inputs are external GTFS files)
data:
	cd data-builder && bun run build-data.ts

# Step 2: Build SwiftData store from JSON
store: $(TRANSIT_STORE)

$(TRANSIT_STORE): $(DATA_JSON)
	cd store-builder && swift run -c release StoreBuilder

# Step 3: Copy store into iOS app bundle resources
import: $(TRANSIT_STORE)
	cp $(TRANSIT_STORE) $(APP_STORE)
	cp $(TRANSIT_INFO) $(APP_INFO)
	@echo "Imported transit.store into iOS app"

clean:
	rm -f $(DATA_JSON) $(DATA_CHANGES)
	rm -f $(TRANSIT_STORE) $(TRANSIT_STORE)-shm $(TRANSIT_STORE)-wal $(TRANSIT_INFO)
	rm -f $(APP_STORE) $(APP_INFO)
