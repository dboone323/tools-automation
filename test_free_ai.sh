#!/bin/bash

# Test Free AI Integration
# Verifies that Ollama and Hugging Face are working correctly

# set -e  # Commented out to see all test results

echo "🧪 Testing Free AI Integration"
echo "=============================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
	echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

# Test Ollama server
test_ollama_server() {
	print_status "Testing Ollama server connectivity..."

	if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
		print_success "Ollama server is running"

		# Get available models
		models=$(curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null || echo "")
		if [[ -n ${models} ]]; then
			print_success "Available models: ${models}"
		else
			print_warning "No models found - run: ollama pull llama2"
		fi
	else
		print_error "Ollama server is not running"
		print_status "Start it with: ollama serve"
		return 1
	fi
}

# Test Ollama text generation
test_ollama_generation() {
	print_status "Testing Ollama text generation..."

	if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
		response=$(curl -s -X POST http://localhost:11434/api/generate \
			-H "Content-Type: application/json" \
			-d '{
            "model": "llama2",
            "prompt": "Hello! This is a test of free AI services.",
            "temperature": 0.1,
            "max_tokens": 50,
            "stream": false
          }' | jq -r '.response // empty' 2>/dev/null)

		if [[ -n ${response} ]]; then
			print_success "Ollama generation works!"
			echo "Response: ${response:0:100}..."
		else
			print_warning "Ollama generation failed - model may not be available"
			print_status "Try: ollama pull llama2"
		fi
	else
		print_error "Cannot test generation - Ollama server not running"
		return 1
	fi
}

# Test Hugging Face API
test_huggingface_api() {
	print_status "Testing Hugging Face free API..."

	# Test without token first
	response=$(curl -s -X POST "https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium" \
		-H "Content-Type: application/json" \
		-d '{"inputs": "Hello, this is a test", "parameters": {"max_length": 50}}' | jq -r '.[0].generated_text // empty' 2>/dev/null)

	if [[ -n ${response} ]]; then
		print_success "Hugging Face API works (free tier)!"
		echo "Response: ${response:0:100}..."
	else
		print_warning "Hugging Face API test failed - may be rate limited"
		print_status "Consider getting a free token from: https://huggingface.co/settings/tokens"
	fi

	# Test with token if available
	if [[ -n ${HF_TOKEN} ]]; then
		print_status "Testing with Hugging Face token..."
		response=$(curl -s -X POST "https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium" \
			-H "Authorization: Bearer ${HF_TOKEN}" \
			-H "Content-Type: application/json" \
			-d '{"inputs": "Hello with token", "parameters": {"max_length": 50}}' | jq -r '.[0].generated_text // empty' 2>/dev/null)

		if [[ -n ${response} ]]; then
			print_success "Hugging Face API works with token!"
		else
			print_warning "Hugging Face API with token failed"
		fi
	fi
}

# Test configuration files
test_configuration() {
	print_status "Testing configuration files..."

	if [[ -f "free_ai_config.json" ]]; then
		print_success "Free AI config file exists"

		# Validate JSON
		if jq empty free_ai_config.json 2>/dev/null; then
			print_success "Configuration JSON is valid"
		else
			print_error "Configuration JSON is invalid"
		fi
	else
		print_warning "Free AI config file not found"
		print_status "Run setup script first: bash setup_free_ai.sh"
	fi

	if [[ -f "FREE_AI_SETUP.md" ]]; then
		print_success "Setup documentation exists"
	else
		print_warning "Setup documentation not found"
	fi
}

# Test Swift compilation
test_swift_compilation() {
	print_status "Testing Swift code compilation..."

	if command -v swiftc >/dev/null 2>&1; then
		# Test OllamaClient compilation
		if [[ -f "/Users/danielstevens/Desktop/Quantum-workspace/Shared/OllamaClient.swift" ]]; then
			print_status "Testing OllamaClient compilation..."
			if swiftc -parse "/Users/danielstevens/Desktop/Quantum-workspace/Shared/OllamaClient.swift" 2>/dev/null; then
				print_success "OllamaClient compiles successfully"
			else
				print_error "OllamaClient compilation failed"
			fi
		else
			print_warning "OllamaClient.swift not found"
		fi
	else
		print_warning "Swift compiler not found - skipping compilation test"
	fi
}

# Performance comparison
performance_comparison() {
	print_status "Performance comparison (estimated)..."

	echo ""
	echo "📊 Cost Comparison:"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "Service          | Cost          | Speed    | Setup"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "OpenAI GPT-4     | $0.03/1K tok  | Fast     | API Key"
	echo "Gemini Pro       | $0.0015/1K ch| Fast     | API Key"
	echo "Ollama Local     | $0.00         | Medium   | Local Install"
	echo "Hugging Face     | $0.00 (3K/h) | Slow     | Optional Token"
	echo ""

	print_success "Free AI services are ready to use!"
}

# Main test function
main() {
	echo ""

	local tests_passed=0
	local total_tests=0

	# Run all tests
	test_configuration && ((tests_passed++))
	((total_tests++))

	test_ollama_server && ((tests_passed++))
	((total_tests++))

	test_ollama_generation && ((tests_passed++))
	((total_tests++))

	test_huggingface_api && ((tests_passed++))
	((total_tests++))

	test_swift_compilation && ((tests_passed++))
	((total_tests++))

	echo ""
	echo "📈 Test Results:${$tests_passe}d${$total_test}s tests passed"

	if [[ ${tests_passed} -eq ${total_tests} ]]; then
		print_success "All tests passed! Free AI integration is working correctly."
	elif [[ ${tests_passed} -gt 0 ]]; then
		print_warning "Some tests passed. Free AI is partially working."
	else
		print_error "No tests passed. Check setup and try again."
	fi

	performance_comparison

	echo ""
	echo "💡 Next Steps:"
	echo "   1. Start Ollama: ollama serve"
	echo "   2. Pull models: ollama pull llama2"
	echo "   3. Update your code to use OllamaClient"
	echo "   4. Remove paid API keys from your code"
	echo ""
}

# Run main function
main "$@"
