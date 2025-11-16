#!/usr/bin/env python3
"""
Validate OpenAPI Specification

Validates the MCP server OpenAPI specification for correctness and completeness.

Run with: python3 docs/validate_openapi_spec.py
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Any, Optional

import yaml
from jsonschema import validate, ValidationError


class OpenAPIValidator:
    """Validates OpenAPI specifications"""

    def __init__(self, spec_path: Path):
        self.spec_path = spec_path
        self.spec: Optional[Dict[str, Any]] = None
        self.errors: List[str] = []
        self.warnings: List[str] = []

    def load_spec(self) -> bool:
        """Load the OpenAPI specification"""
        try:
            with open(self.spec_path, "r", encoding="utf-8") as f:
                if self.spec_path.suffix.lower() in [".yaml", ".yml"]:
                    self.spec = yaml.safe_load(f)
                else:
                    self.spec = json.load(f)
            return True
        except Exception as e:
            self.errors.append(f"Failed to load spec: {e}")
            return False

    def validate_basic_structure(self) -> bool:
        """Validate basic OpenAPI structure"""
        if not self.spec:
            return False

        # Check required top-level fields
        required_fields = ["openapi", "info", "paths"]
        for field in required_fields:
            if field not in self.spec:
                self.errors.append(f"Missing required field: {field}")
                return False

        # Validate OpenAPI version
        openapi_version = self.spec.get("openapi", "")
        if not openapi_version.startswith("3."):
            self.errors.append(f"Unsupported OpenAPI version: {openapi_version}")

        # Validate info section
        info = self.spec.get("info", {})
        required_info_fields = ["title", "version"]
        for field in required_info_fields:
            if field not in info:
                self.errors.append(f"Missing required info field: {field}")

        return len(self.errors) == 0

    def validate_paths(self) -> bool:
        """Validate paths section"""
        if not self.spec or "paths" not in self.spec:
            return False

        paths = self.spec["paths"]
        if not isinstance(paths, dict):
            self.errors.append("Paths must be an object")
            return False

        for path, methods in paths.items():
            if not isinstance(methods, dict):
                self.errors.append(f"Path {path} methods must be an object")
                continue

            for method, operation in methods.items():
                if method not in [
                    "get",
                    "post",
                    "put",
                    "delete",
                    "patch",
                    "options",
                    "head",
                ]:
                    self.errors.append(f"Invalid HTTP method: {method} for path {path}")
                    continue

                if not isinstance(operation, dict):
                    self.errors.append(f"Operation {method} {path} must be an object")
                    continue

                # Check for required operation fields
                if "responses" not in operation:
                    self.errors.append(f"Missing responses for {method} {path}")

        return len(self.errors) == 0

    def validate_schemas(self) -> bool:
        """Validate component schemas"""
        if not self.spec or "components" not in self.spec:
            return True  # Components are optional

        components = self.spec["components"]
        if "schemas" not in components:
            return True  # Schemas are optional

        schemas = components["schemas"]
        if not isinstance(schemas, dict):
            self.errors.append("Schemas must be an object")
            return False

        for schema_name, schema in schemas.items():
            if not isinstance(schema, dict):
                self.errors.append(f"Schema {schema_name} must be an object")
                continue

            # Basic schema validation
            if "type" in schema and schema["type"] not in [
                "object",
                "array",
                "string",
                "number",
                "integer",
                "boolean",
            ]:
                self.errors.append(
                    f"Invalid type in schema {schema_name}: {schema['type']}"
                )

        return len(self.errors) == 0

    def validate_references(self) -> bool:
        """Validate JSON references"""
        if not self.spec:
            return False

        def check_refs(obj: Any, path: str = "") -> None:
            if isinstance(obj, dict):
                for key, value in obj.items():
                    current_path = f"{path}.{key}" if path else key
                    if key == "$ref":
                        if not isinstance(value, str):
                            self.errors.append(
                                f"Invalid $ref at {path}: must be string"
                            )
                        elif not value.startswith("#/"):
                            self.errors.append(
                                f"Invalid $ref at {path}: must start with '#/"
                            )
                    else:
                        check_refs(value, current_path)
            elif isinstance(obj, list):
                for i, item in enumerate(obj):
                    check_refs(item, f"{path}[{i}]")

        check_refs(self.spec)
        return len(self.errors) == 0

    def validate_examples(self) -> bool:
        """Validate examples in the spec"""
        if not self.spec:
            return False

        def check_examples(obj: Any, path: str = "") -> None:
            if isinstance(obj, dict):
                for key, value in obj.items():
                    current_path = f"{path}.{key}" if path else key
                    if key == "example":
                        # Try to validate JSON examples
                        if "schema" in obj:
                            try:
                                validate(value, obj["schema"])
                            except ValidationError as e:
                                self.warnings.append(
                                    f"Example validation failed at {path}: {e.message}"
                                )
                    else:
                        check_examples(value, current_path)
            elif isinstance(obj, list):
                for i, item in enumerate(obj):
                    check_examples(item, f"{path}[{i}]")

        check_examples(self.spec)
        return True  # Warnings don't fail validation

    def run_validation(self) -> bool:
        """Run all validations"""
        print(f"🔍 Validating OpenAPI spec: {self.spec_path}")

        if not self.load_spec():
            return False

        validations = [
            self.validate_basic_structure,
            self.validate_paths,
            self.validate_schemas,
            self.validate_references,
            self.validate_examples,
        ]

        all_passed = True
        for validation in validations:
            if not validation():
                all_passed = False

        return all_passed

    def print_report(self) -> None:
        """Print validation report"""
        if self.errors:
            print("❌ Validation Errors:")
            for error in self.errors:
                print(f"  - {error}")

        if self.warnings:
            print("⚠️ Validation Warnings:")
            for warning in self.warnings:
                print(f"  - {warning}")

        if not self.errors and not self.warnings:
            print("✅ OpenAPI specification is valid!")


def main():
    """Main validation function"""
    spec_path = Path(__file__).parent / "mcp_openapi_spec.yaml"

    if not spec_path.exists():
        print(f"❌ OpenAPI spec not found: {spec_path}")
        return 1

    validator = OpenAPIValidator(spec_path)

    if validator.run_validation():
        validator.print_report()
        return 0
    else:
        validator.print_report()
        return 1


if __name__ == "__main__":
    sys.exit(main())
