DATA_JSON = data-builder/metropolist-data.json
TRANSIT_STORE = store-builder/transit.store
APP_STORE = metropolist/metropolist/transit.store

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
	@echo "Imported transit.store into iOS app"

clean:
	rm -f $(DATA_JSON)
	rm -f $(TRANSIT_STORE) $(TRANSIT_STORE)-shm $(TRANSIT_STORE)-wal
	rm -f $(APP_STORE)
