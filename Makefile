# Makefile for morpheus-openapi repository

# Variables
PROJECT_ROOT := $(shell git rev-parse --show-toplevel)
BUILD_DIR := $(PROJECT_ROOT)/build

# Default target
.DEFAULT_GOAL := help

# Help target
.PHONY: help
help: ## Show this help message
	@echo "Available targets:"
	@echo "  test      - Test that the openapi schema is valid by executing lint commands via docker"
	@echo "  build     - Builds bundled.yaml with redocly via docker"
	@echo "  generate  - Generates a Python client with OpenAPI Generator via docker"
	@echo "  lint      - Validate the openapi schema with both redocly and spectral"
	@echo "  clean     - Clean generated files"
	@echo "  help      - Show this help message"

# Check if docker is installed (cross-platform)
.PHONY: check-docker
check-docker:
ifeq ($(OS),Windows_NT)
	@where docker >nul 2>&1 || (echo Error: Docker is not installed or not in PATH && exit 1)
else
	@which docker > /dev/null 2>&1 || (echo "Error: Docker is not installed or not in PATH" && exit 1)
endif

# Test target - equivalent to rake test
.PHONY: test
test: lint ## Test that the openapi schema is valid by executing lint commands via docker

# Lint target - equivalent to rake docker:lint
.PHONY: lint
lint: redocly-lint spectral-lint ## Validate the openapi schema with both redocly and spectral

# Redocly lint - equivalent to rake docker:redocly_lint
.PHONY: redocly-lint
redocly-lint: check-docker ## Execute redocly/cli lint using docker
	@echo "Running Redocly lint..."
ifeq ($(OS),Windows_NT)
	docker run --rm -v "$(CURDIR):/spec" redocly/cli lint openapi.yaml --skip-rule no-invalid-media-type-examples
else
	docker run --rm -v "$(PWD):/spec" redocly/cli lint openapi.yaml --skip-rule no-invalid-media-type-examples
endif

# Spectral lint - equivalent to rake docker:spectral_lint
.PHONY: spectral-lint
spectral-lint: check-docker build ## Execute stoplight/spectral lint using docker
	@echo "Running Spectral lint..."
ifeq ($(OS),Windows_NT)
	docker run --rm -v "$(CURDIR):/tmp" -it stoplight/spectral lint -v -F error "/tmp/bundled.yaml" --ruleset "/tmp/.spectral.json"
else
	docker run --rm -v "$(PWD):/tmp" -it stoplight/spectral lint -v -F error "/tmp/bundled.yaml" --ruleset "/tmp/.spectral.json"
endif

# Build target - equivalent to rake build
.PHONY: build
build: check-docker ## Builds bundled.yaml with redocly via docker
	@echo "Building bundled.yaml..."
ifeq ($(OS),Windows_NT)
	docker run --rm -v "$(CURDIR):/spec" redocly/cli bundle --dereferenced openapi.yaml > bundled.yaml
else
	docker run --rm -v "$(PWD):/spec" redocly/cli bundle --dereferenced openapi.yaml > bundled.yaml
endif

# Generate target - equivalent to rake generate
.PHONY: generate
generate: check-docker build ## Generates a Python client with OpenAPI Generator via docker
	@echo "Generating Python client..."
ifeq ($(OS),Windows_NT)
	@if not exist "generated\morpheus-python-sdk" mkdir "generated\morpheus-python-sdk"
	@copy ".openapi-generator\.openapi-generator-ignore" "generated\morpheus-python-sdk\" >nul
else
	@mkdir -p generated/morpheus-python-sdk
	@cp .openapi-generator/.openapi-generator-ignore generated/morpheus-python-sdk/
endif
	docker run -v "$(CURDIR):/spec" -it \
		-e JAVA_OPTS=-DmaxYamlCodePoints=999999999 \
		openapitools/openapi-generator-cli \
		generate -g python -i /spec/bundled.yaml -o /spec/generated/morpheus-python-sdk \
		-c /spec/.openapi-generator/python-config.json

# Clean target - remove generated files
.PHONY: clean
clean: ## Clean generated files
	@echo "Cleaning generated files..."
ifeq ($(OS),Windows_NT)
	@if exist "bundled.yaml" del "bundled.yaml"
	@if exist "generated" rmdir /s /q "generated"
else
	@rm -f bundled.yaml
	@rm -rf generated/
endif
