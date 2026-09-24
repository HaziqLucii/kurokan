.PHONY: run run-linux test format analyze check install-macos

run:
	flutter run -d macos

run-linux:
	flutter run -d linux

format:
	dart format --output=none --set-exit-if-changed .

analyze:
	flutter analyze --fatal-infos

test:
	flutter test -x golden

check: format analyze test

install-macos:
	flutter build macos --release --dart-define=APP_VERSION=$(shell git describe --tags --always)
	rm -rf /Applications/Kurokan.app
	cp -R build/macos/Build/Products/Release/Kurokan.app /Applications/
