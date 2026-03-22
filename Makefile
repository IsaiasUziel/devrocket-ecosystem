.PHONY: build run test clean install

BINARY_NAME=dr-sys
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")

build:
	go build -ldflags "-X main.version=$(VERSION)" -o bin/$(BINARY_NAME) ./cmd/devrocket

run: build
	./bin/$(BINARY_NAME)

test:
	go test ./...

clean:
	rm -rf bin/ dist/

install: build
	cp bin/$(BINARY_NAME) $(shell brew --prefix 2>/dev/null || echo /usr/local)/bin/
