.PHONY: lint lint-fix format format-check periphery

lint:
	swiftlint lint metropolist/

lint-fix:
	swiftlint lint --fix metropolist/

format:
	swiftformat metropolist/

format-check:
	swiftformat --lint metropolist/

periphery:
	periphery scan
