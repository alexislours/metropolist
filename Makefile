.PHONY: lint lint-fix format format-check build test test-ci periphery

lint:
	swiftlint lint metropolist/ metropolistWidgets/

lint-fix:
	swiftlint lint --fix metropolist/ metropolistWidgets/

format:
	swiftformat metropolist/ metropolistWidgets/ Shared/

format-check:
	swiftformat --lint metropolist/ metropolistWidgets/ Shared/

build:
	xcodebuild -scheme metropolist -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

test:
	@rm -rf .build/tests.xcresult
	@xcodebuild test -scheme metropolist \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
		-only-testing:metropolistTests \
		-resultBundlePath .build/tests.xcresult 2>&1 | xcbeautify --quiet
	@xcrun xcresulttool get test-results summary --path .build/tests.xcresult --compact \
		| jq -r '"", "  \(.result) — \(.passedTests) passed, \(.failedTests) failed, \(.skippedTests) skipped (\(.totalTestCount) total)", (if (.testFailures | length) > 0 then "  Failures:", (.testFailures[] | "    ✗ \(.testName): \(.failureText)") else empty end), ""'

test-ci:
	xcodebuild test -scheme metropolist \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
		-only-testing:metropolistTests 2>&1 | xcbeautify --renderer github-actions

periphery:
	periphery scan
