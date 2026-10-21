APP = dist/SpaceSweep.app

.PHONY: build run debug test clean

build:
	./scripts/build-app.sh release

debug:
	./scripts/build-app.sh debug

run: build
	open "$(APP)"

test:
	swift build --build-tests
	swift test --skip-build --disable-xctest --enable-swift-testing

clean:
	swift package clean
	rm -rf dist
