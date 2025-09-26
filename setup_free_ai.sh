#!/bin/bash

# Free AI Setup Script
# Sets up Ollama for local AI inference (completely free, no API costs)

set -e

echo "🤖 Setting up Free AI Services (Ollama + Hugging Face)"
echo "=================================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
  echo -e "${BLUE}[SETUP]${NC} $1"
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

# Check if running on macOS
if [[ $OSTYPE != "darwin"* ]]; then
  print_error "This script is designed for macOS. For Linux/Windows, please install Ollama manually."
  exit 1
fi

# Install Ollama
install_ollama() {
  print_status "Installing Ollama..."

  if command -v ollama >/dev/null 2>&1; then
    print_success "Ollama is already installed"
    return 0
  fi

  # Install Ollama using Homebrew
  if command -v brew >/dev/null 2>&1; then
    print_status "Installing Ollama via Homebrew..."
    brew install ollama
  else
    print_error "Homebrew not found. Please install Homebrew first: https://brew.sh/"
    print_status "Or install Ollama manually from: https://ollama.ai/download"
    exit 1
  fi

  print_success "Ollama installed successfully"
}

# Start Ollama service
start_ollama() {
  print_status "Starting Ollama service..."

  # Start Ollama in the background
  nohup ollama serve >ollama.log 2>&1 &
  OLLAMA_PID=$!

  # Wait for Ollama to start
  print_status "Waiting for Ollama to start..."
  sleep 5

  # Check if Ollama is running
  if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    print_success "Ollama is running on http://localhost:11434"
  else
    print_warning "Ollama may not have started properly. Check ollama.log for details."
  fi

  echo $OLLAMA_PID >ollama.pid
  print_success "Ollama PID saved to ollama.pid"
}

# Pull recommended models
pull_models() {
  print_status "Pulling recommended AI models..."

  # Pull a good general-purpose model (free)
  print_status "Pulling llama2 model..."
  ollama pull llama2

  # Pull a code-specialized model
  print_status "Pulling codellama model..."
  ollama pull codellama

  print_success "Models downloaded successfully"
}

# Setup Hugging Face (free tier)
setup_huggingface() {
  print_status "Setting up Hugging Face free inference API..."

  # Check if HF_TOKEN is set
  if [[ -z ${HF_TOKEN} ]]; then
    print_warning "Hugging Face token not found. Get one at: https://huggingface.co/settings/tokens"
    print_status "Set HF_TOKEN environment variable for better rate limits"
    echo "export HF_TOKEN='your_token_here'" >>~/.zshrc
  else
    print_success "Hugging Face token found"
  fi

  print_success "Hugging Face setup complete"
}

# Create configuration file
create_config() {
  print_status "Creating AI service configuration..."

  cat >free_ai_config.json <<'EOF'
{
  "primary_service": "ollama",
  "services": {
    "ollama": {
      "endpoint": "http://localhost:11434",
      "models": {
        "general": "llama2",
        "code": "codellama"
      },
      "cost": "free"
    },
    "huggingface": {
      "endpoint": "https://api-inference.huggingface.co",
      "models": {
        "general": "microsoft/DialoGPT-medium",
        "code": "microsoft/codebert-base"
      },
      "cost": "free_tier"
    }
  },
  "fallback_order": ["ollama", "huggingface"],
  "rate_limits": {
    "ollama": "unlimited",
    "huggingface": "3000_requests/hour"
  }
}
EOF

  print_success "Configuration created: free_ai_config.json"
}

# Test the setup
test_setup() {
  print_status "Testing AI services..."

  # Test Ollama
  if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    print_success "Ollama API is accessible"

    # Test a simple prompt
    response=$(curl -s -X POST http://localhost:11434/api/generate \
      -H "Content-Type: application/json" \
      -d '{"model": "llama2", "prompt": "Hello, test message", "stream": false}' | jq -r '.response // empty')

    if [[ -n $response ]]; then
      print_success "Ollama model test successful"
    else
      print_warning "Ollama model test failed - model may need more time to load"
    fi
  else
    print_error "Ollama API is not accessible"
  fi

  # Test Hugging Face (if token available)
  if [[ -n ${HF_TOKEN} ]]; then
    response=$(curl -s -X POST "https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium" \
      -H "Authorization: Bearer ${HF_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"inputs": "Hello, test message"}')

    if [[ $response != *"error"* ]]; then
      print_success "Hugging Face API test successful"
    else
      print_warning "Hugging Face API test failed - check token and rate limits"
    fi
  fi
}

# Create usage instructions
create_instructions() {
  print_status "Creating usage instructions..."

  cat >FREE_AI_SETUP.md <<'EOF'
# Free AI Services Setup Complete! 🎉

## What's Been Set Up

### 1. Ollama (Primary - 100% Free)
- **Local AI server** running on your machine
- **No API costs** - uses your computer's resources
- **Models installed**: llama2 (general), codellama (code)
- **Endpoint**: http://localhost:11434

### 2. Hugging Face (Backup - Free Tier)
- **Free inference API** with rate limits
- **3000 requests/hour** free tier
- **No credit card required**

## How to Use in Your Code

### Replace OpenAI Calls
```swift
// OLD (Paid)
let openai = OpenAI(apiKey: "your-key")

// NEW (Free)
let ollama = OllamaClient(baseURL: "http://localhost:11434")
let response = try await ollama.generate(model: "llama2", prompt: prompt)
```

### Replace Gemini Calls
```swift
// OLD (Paid)
let gemini = GeminiAPI(apiKey: "your-key")

// NEW (Free)
let response = try await ollama.generate(model: "codellama", prompt: prompt)
```

## Managing Ollama

### Start Ollama
```bash
ollama serve
```

### List Available Models
```bash
ollama list
```

### Pull More Models
```bash
ollama pull mistral  # Better general model
ollama pull llama2:13b  # Larger model
```

### Stop Ollama
```bash
pkill ollama
```

## Cost Comparison

| Service | Cost | Setup | Speed |
|---------|------|-------|-------|
| OpenAI GPT-4 | $0.03/1K tokens | API Key | Fast |
| Gemini Pro | $0.0015/1K chars | API Key | Fast |
| **Ollama Local** | **$0.00** | Local Install | Medium |
| Hugging Face | $0.00 (rate limited) | Token Optional | Slow |

## Next Steps

1. **Update your code** to use Ollama instead of paid APIs
2. **Test the performance** - local models are slower but free
3. **Consider model size** - larger models = better quality but slower
4. **Set up auto-start** if you want Ollama to run on boot

## Troubleshooting

- **Ollama not starting?** Check if port 11434 is available
- **Models not loading?** Try `ollama pull <model>` again
- **Slow responses?** Use smaller models or upgrade hardware
- **API errors?** Check Hugging Face token and rate limits

## Environment Variables

Add these to your `~/.zshrc`:

```bash
# Ollama
export OLLAMA_HOST=http://localhost:11434

# Hugging Face (optional)
export HF_TOKEN=your_token_here
```

Enjoy your FREE AI services! 🚀
EOF

  print_success "Instructions created: FREE_AI_SETUP.md"
}

# Main setup
main() {
  echo ""
  print_status "Starting Free AI Services Setup..."
  echo ""

  install_ollama
  start_ollama
  pull_models
  setup_huggingface
  create_config
  test_setup
  create_instructions

  echo ""
  print_success "🎉 Free AI Services Setup Complete!"
  echo ""
  echo "📖 Read FREE_AI_SETUP.md for usage instructions"
  echo "🔧 Ollama is running at: http://localhost:11434"
  echo "💰 You just saved on AI API costs!"
  echo ""
}

# Run main function
main "$@"
