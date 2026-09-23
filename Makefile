.PHONY: run test install-macos

run:
	flutter run -d macos

test:
	flutter test

install-macos:
	flutter build macos --release --dart-define=APP_VERSION=$(shell git describe --tags --always)
	rm -rf /Applications/Kurokan.app
	cp -R build/macos/Build/Products/Release/Kurokan.app /Applications/
