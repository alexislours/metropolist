.PHONY: lint lint-fix format format-check build periphery

lint:
	swiftlint lint metropolist/

lint-fix:
	swiftlint lint --fix metropolist/

format:
	swiftformat metropolist/

format-check:
	swiftformat --lint metropolist/

build:
	xcodebuild -scheme metropolist -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

periphery:
	periphery scan
