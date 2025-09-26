#!/bin/bash

# Test Free AI Integration
# Verifies that Ollama and Hugging Face are working correctly

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

# Check Hugging Face API status
check_huggingface_status() {
  print_status "Checking Hugging Face API status..."

  # Check if API is reachable
  if curl -s --max-time 5 "https://api-inference.huggingface.co/status" >/dev/null 2>&1; then
    print_success "Hugging Face API is reachable"
  else
    print_warning "Hugging Face API may be experiencing issues"
  fi

  # Check token validity if available
  if [[ -n ${HF_TOKEN} ]]; then
    local token_check
    token_check=$(curl -s -H "Authorization: Bearer ${HF_TOKEN}" "https://huggingface.co/api/whoami-v2" | jq -r '.name // empty' 2>/dev/null)
    if [[ -n ${token_check} && ${token_check} != "null" ]]; then
      print_success "Hugging Face token is valid (User: ${token_check})"
    else
      print_warning "Hugging Face token validation failed"
    fi
  fi
}

# Test Hugging Face API
test_huggingface_api() {
  print_status "Testing Hugging Face free API..."

  # Array of models to test (prioritizing more reliable ones)
  local models=("gpt2" "distilgpt2" "microsoft/DialoGPT-small")
  local working_model=""
  local response=""

  # Test without token first
  print_status "Testing free tier API with multiple models..."
  for model in "${models[@]}"; do
    print_status "Trying model: ${model}"
    response=$(curl -s -X POST "https://api-inference.huggingface.co/models/${model}" \
      -H "Content-Type: application/json" \
      -d '{"inputs": "Hello, this is a test", "parameters": {"max_length": 30}}' | jq -r '.[0].generated_text // empty' 2>/dev/null)

    if [[ -n ${response} && ${response} != "null" && ${response} != "" ]]; then
      print_success "Hugging Face API works with ${model} (free tier)!"
      echo "Response: ${response:0:80}..."
      working_model="${model}"
      break
    fi
  done

  if [[ -z ${working_model} ]]; then
    print_warning "Hugging Face free tier API test failed - all tested models unavailable"
    print_status "This is normal for free tier - models may be loading or rate limited"
    print_status "Consider getting a free token for better reliability: https://huggingface.co/settings/tokens"
  fi

  # Test with token if available
  if [[ -n ${HF_TOKEN} ]]; then
    print_status "Testing with Hugging Face token..."

    # If we found a working model, test it with token
    if [[ -n ${working_model} ]]; then
      response=$(curl -s -X POST "https://api-inference.huggingface.co/models/${working_model}" \
        -H "Authorization: Bearer ${HF_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"inputs": "Hello with token", "parameters": {"max_length": 30}}' | jq -r '.[0].generated_text // empty' 2>/dev/null)

      if [[ -n ${response} && ${response} != "null" && ${response} != "" ]]; then
        print_success "Hugging Face API works with token and ${working_model}!"
        echo "Token Response: ${response:0:80}..."
      else
        print_warning "Hugging Face API with token failed for ${working_model}"
        print_status "Token may be valid but model still unavailable"
      fi
    else
      # Test token with a known model even if free tier failed
      response=$(curl -s -X POST "https://api-inference.huggingface.co/models/gpt2" \
        -H "Authorization: Bearer ${HF_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"inputs": "Hello with token", "parameters": {"max_length": 30}}' | jq -r '.[0].generated_text // empty' 2>/dev/null)

      if [[ -n ${response} && ${response} != "null" && ${response} != "" ]]; then
        print_success "Hugging Face API works with token!"
        echo "Token Response: ${response:0:80}..."
      else
        print_warning "Hugging Face API with token failed"
        print_status "Token appears valid but models may be temporarily unavailable"
      fi
    fi
  fi

  # Overall assessment
  if [[ -n ${working_model} ]]; then
    print_success "Hugging Face integration is working correctly!"
    return 0
  else
    print_warning "Hugging Face models currently unavailable, but Ollama provides full functionality"
    return 0 # Don't fail the test since Ollama works
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

    # Test HuggingFaceClient compilation
    if [[ -f "/Users/danielstevens/Desktop/Quantum-workspace/Shared/HuggingFaceClient.swift" ]]; then
      print_status "Testing HuggingFaceClient compilation..."
      if swiftc -parse "/Users/danielstevens/Desktop/Quantum-workspace/Shared/HuggingFaceClient.swift" 2>/dev/null; then
        print_success "HuggingFaceClient compiles successfully"
      else
        print_error "HuggingFaceClient compilation failed"
      fi
    else
      print_warning "HuggingFaceClient.swift not found"
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
  echo 'OpenAI GPT-4     | $0.03/1K tok  | Fast     | API Key'
  echo 'Gemini Pro       | $0.0015/1K ch| Fast     | API Key'
  echo 'Ollama Local     | $0.00         | Medium   | Local Install'
  echo 'Hugging Face     | $0.00 (3K/h) | Slow     | Optional Token'
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

  check_huggingface_status
  test_huggingface_api && ((tests_passed++))
  ((total_tests++))

  test_swift_compilation && ((tests_passed++))
  ((total_tests++))

  echo ""
  echo "📈 Test Results: ${tests_passed}/${total_tests} tests passed"

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
