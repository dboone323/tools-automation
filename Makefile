SHELL := /bin/zsh
.PHONY: validate lint format

validate:
	@.ci/agent_validate.sh

lint:
	@swiftlint --strict || true

format:
	@swiftformat . --config .swiftformat || true
