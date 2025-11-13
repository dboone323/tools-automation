#!/usr/bin/env python3
"""
AI/ML Integration Framework for Tools Automation
Phase 7: Advanced AI/ML Integration

Provides unified interface to multiple AI services (Ollama, Hugging Face)
with intelligent routing, caching, and specialized models for code analysis,
performance prediction, and automated decision making.
"""

import json
import os
import time
import hashlib
import logging
from typing import Dict, List, Any, Optional, Union
from dataclasses import dataclass
from datetime import datetime, timedelta
import psutil
import statistics

# Optional imports with fallbacks
try:
    import asyncio
    import aiohttp
    import redis

    AI_DEPENDENCIES_AVAILABLE = True
except ImportError as e:
    print(f"AI dependencies not available: {e}")
    print("AI functionality will be disabled")
    AI_DEPENDENCIES_AVAILABLE = False

    # Create dummy classes/functions for when dependencies are missing
    class asyncio:
        @staticmethod
        def run(coro):
            raise RuntimeError("asyncio not available")

    class aiohttp:
        class ClientSession:
            pass

    class redis:
        class Redis:
            def __init__(self, **kwargs):
                pass

            def get(self, key):
                return None

            def setex(self, key, ttl, value):
                pass


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class AIModel:
    """Represents an AI model with its capabilities and metadata"""

    name: str
    provider: str  # 'ollama' or 'huggingface'
    model_id: str
    capabilities: List[str]  # ['code_analysis', 'text_generation', 'prediction', etc.]
    context_length: int
    performance_score: float  # 0-1 scale
    cost_per_token: float = 0.0
    rate_limit: int = 1000  # requests per hour


@dataclass
class AIRequest:
    """Represents an AI service request"""

    task_type: str
    prompt: str
    context: Dict[str, Any] = None
    max_tokens: int = 1000
    temperature: float = 0.7
    priority: str = "normal"  # 'low', 'normal', 'high', 'critical'


@dataclass
class AIResponse:
    """Represents an AI service response"""

    success: bool
    content: str
    model_used: str
    tokens_used: int
    processing_time: float
    confidence_score: float = 0.0
    metadata: Dict[str, Any] = None
    error_message: str = ""


class AIServiceManager:
    """Unified AI service manager with intelligent routing and caching"""

    def __init__(self, config_file: str = "free_ai_config.json"):
        if not AI_DEPENDENCIES_AVAILABLE:
            raise RuntimeError("AI dependencies not available")

        self.config = self._load_config(config_file)
        self.redis_client = redis.Redis(host="localhost", port=6379, db=0)
        self.models = self._initialize_models()
        self.session = None
        self.cache_ttl = 3600  # 1 hour cache

    def _load_config(self, config_file: str) -> Dict[str, Any]:
        """Load AI service configuration"""
        if os.path.exists(config_file):
            with open(config_file, "r") as f:
                loaded_config = json.load(f)
                logger.info(
                    f"Loaded config from {config_file}: {list(loaded_config.keys())}"
                )

                # Handle nested config structure
                if "services" in loaded_config:
                    # Convert nested structure to flat structure
                    config = {
                        "ollama": loaded_config["services"]["ollama"],
                        "huggingface": loaded_config["services"]["huggingface"],
                        "fallback_order": loaded_config.get(
                            "fallback_order", ["ollama", "huggingface"]
                        ),
                        "rate_limits": loaded_config.get("rate_limits", {}),
                    }
                    # Add models list for backward compatibility
                    config["ollama"]["models"] = list(
                        config["ollama"].get("models", {}).values()
                    )
                    config["huggingface"]["models"] = list(
                        config["huggingface"].get("models", {}).values()
                    )
                    return config
                else:
                    return loaded_config
        else:
            # Default configuration
            logger.info("Using default configuration")
            return {
                "ollama": {
                    "endpoint": "http://localhost:11434",
                    "models": ["llama2", "codellama"],
                },
                "huggingface": {
                    "endpoint": "https://api-inference.huggingface.co",
                    "token": os.environ.get("HUGGINGFACE_TOKEN", ""),
                    "models": ["microsoft/DialoGPT-medium", "microsoft/codebert-base"],
                },
                "fallback_order": ["ollama", "huggingface"],
                "rate_limits": {
                    "ollama": "unlimited",
                    "huggingface": "3000_requests/hour",
                },
            }

    def _initialize_models(self) -> Dict[str, AIModel]:
        """Initialize available AI models with specific versions"""
        models = {}

        # Ollama models - use specific versions for better control
        ollama_models = [
            AIModel(
                "llama2_7b",
                "ollama",
                "llama2:7b",
                ["text_generation", "general", "conversation"],
                4096,
                0.85,
                0.0,
                1000,
            ),
            AIModel(
                "llama2_latest",
                "ollama",
                "llama2:latest",
                ["text_generation", "creative", "general"],
                4096,
                0.87,
                0.0,
                1000,
            ),
            AIModel(
                "codellama_7b",
                "ollama",
                "codellama:7b",
                ["code_generation", "code_analysis", "code_review", "debugging"],
                4096,
                0.92,  # Higher score to prefer 7b for most tasks
                0.0,
                1000,
            ),
            AIModel(
                "codellama_13b",
                "ollama",
                "codellama:13b",
                [
                    "code_generation",
                    "code_analysis",
                    "code_review",
                    "debugging",
                    "complex_reasoning",
                    "very_complex_code",
                ],
                4096,
                0.88,  # Lower score so it's only used for very complex tasks
                0.0,
                500,
            ),
        ]

        # Hugging Face models
        hf_models = [
            AIModel(
                "codebert",
                "huggingface",
                "microsoft/codebert-base",
                ["code_analysis", "code_embedding", "code_similarity"],
                512,
                0.88,
                0.0,
                3000,
            ),
            AIModel(
                "dialogpt",
                "huggingface",
                "microsoft/DialoGPT-medium",
                ["text_generation", "conversation", "chat"],
                1024,
                0.82,
                0.0,
                3000,
            ),
        ]

        for model in ollama_models + hf_models:
            models[model.name] = model

        return models

    async def _get_session(self) -> aiohttp.ClientSession:
        """Get or create HTTP session"""
        if self.session is None or self.session.closed:
            self.session = aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=30)
            )
        return self.session

    def _get_cache_key(self, request: AIRequest) -> str:
        """Generate cache key for request"""
        content = f"{request.task_type}:{request.prompt}:{request.context}"
        return f"ai_cache:{hashlib.md5(content.encode()).hexdigest()}"

    async def _check_cache(self, cache_key: str) -> Optional[AIResponse]:
        """Check Redis cache for response"""
        try:
            cached = self.redis_client.get(cache_key)
            if cached:
                data = json.loads(cached)
                # Check if cache is still valid
                if time.time() - data.get("timestamp", 0) < self.cache_ttl:
                    return AIResponse(**data["response"])
        except Exception as e:
            logger.warning(f"Cache check failed: {e}")
        return None

    def _cache_response(self, cache_key: str, response: AIResponse):
        """Cache response in Redis"""
        try:
            data = {
                "timestamp": time.time(),
                "response": {
                    "success": response.success,
                    "content": response.content,
                    "model_used": response.model_used,
                    "tokens_used": response.tokens_used,
                    "processing_time": response.processing_time,
                    "confidence_score": response.confidence_score,
                    "metadata": response.metadata or {},
                    "error_message": response.error_message,
                },
            }
            self.redis_client.setex(cache_key, self.cache_ttl, json.dumps(data))
        except Exception as e:
            logger.warning(f"Cache storage failed: {e}")

    def _select_best_model(self, request: AIRequest) -> AIModel:
        """Select the best model for the given request with intelligent sizing"""
        task_type = request.task_type

        logger.info(f"🔍 DEBUG: Selecting model for task: {task_type}")
        logger.info(f"🔍 DEBUG: Available models: {list(self.models.keys())}")

        # Map task types to model capabilities
        capability_map = {
            "code_analysis": "code_analysis",
            "code_generation": "code_generation",
            "code_review": "code_review",
            "debugging": "debugging",
            "text_generation": "text_generation",
            "prediction": "prediction",
            "classification": "classification",
        }

        required_capability = capability_map.get(task_type, "general")
        logger.info(f"🔍 DEBUG: Required capability: {required_capability}")

        # Find models with the required capability
        candidates = [
            model
            for model in self.models.values()
            if required_capability in model.capabilities
        ]

        logger.info(f"🔍 DEBUG: Candidate models: {[m.name for m in candidates]}")

        if not candidates:
            # Fallback to general models
            candidates = [
                model
                for model in self.models.values()
                if "general" in model.capabilities
            ]
            logger.info(
                f"🔍 DEBUG: Fallback to general models: {[m.name for m in candidates]}"
            )

        if not candidates:
            # Ultimate fallback
            candidates = list(self.models.values())
            logger.info(
                f"🔍 DEBUG: Ultimate fallback models: {[m.name for m in candidates]}"
            )

        # Intelligent model selection based on task complexity and context
        candidates = self._prioritize_models_by_complexity(candidates, request)

        # Select based on performance score and provider preference
        try:
            candidates.sort(
                key=lambda m: (
                    m.performance_score,
                    -self.config["fallback_order"].index(
                        m.provider
                    ),  # Negative for reverse order
                ),
                reverse=True,
            )
        except (ValueError, KeyError):
            # If provider ordering fails, just sort by performance
            candidates.sort(key=lambda m: m.performance_score, reverse=True)

        selected = candidates[0]
        logger.info(
            f"🔍 DEBUG: Selected model {selected.name} ({selected.model_id}) with score {selected.performance_score}"
        )
        return selected

    def _prioritize_models_by_complexity(
        self, candidates: List[AIModel], request: AIRequest
    ) -> List[AIModel]:
        """Prioritize models based on task complexity and resource availability"""
        # Check system resources to prefer smaller models if resources are constrained
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            memory_percent = memory.percent

            # If system is under high load, prefer smaller models
            high_load = cpu_percent > 80 or memory_percent > 85

            if high_load:
                logger.info("System under high load, prioritizing smaller models")
                # Sort by model size (prefer smaller models under load)
                candidates.sort(
                    key=lambda m: self._estimate_model_size(m), reverse=False
                )
                return candidates
        except Exception as e:
            logger.warning(f"Could not check system resources: {e}")

        # For code-related tasks, consider code complexity
        if request.task_type in ["code_analysis", "code_review", "debugging"]:
            code = request.context.get("code", "") if request.context else ""
            code_length = len(code)

            # For very complex code (>2000 chars), prefer larger models
            if code_length > 2000:
                logger.info(
                    f"Complex code detected ({code_length} chars), prioritizing larger models"
                )
                candidates.sort(
                    key=lambda m: self._estimate_model_size(m), reverse=True
                )
                return candidates

        # For simple tasks or when we want speed, prefer smaller models
        if request.priority == "low" or request.max_tokens < 500:
            logger.info("Simple task detected, prioritizing smaller/faster models")
            candidates.sort(key=lambda m: self._estimate_model_size(m), reverse=False)
            return candidates

        # Default: sort by performance score
        return candidates

    def _estimate_model_size(self, model: AIModel) -> int:
        """Estimate model size based on name for prioritization"""
        name = model.model_id.lower()
        if "13b" in name:
            return 13
        elif "7b" in name:
            return 7
        elif "3b" in name:
            return 3
        elif "1.5b" in name:
            return 1
        else:
            return 7  # Default assumption

    async def _call_ollama(
        self, model: AIModel, prompt: str, **kwargs
    ) -> Dict[str, Any]:
        """Call Ollama API with enhanced error handling and debugging"""
        session = await self._get_session()
        url = f"{self.config['ollama']['endpoint']}/api/generate"

        payload = {"model": model.model_id, "prompt": prompt, "stream": False, **kwargs}

        logger.info(f"🔍 DEBUG: Calling Ollama API: {url}")
        logger.info(f"🔍 DEBUG: Model: {model.model_id}")
        logger.info(f"🔍 DEBUG: Prompt length: {len(prompt)} chars")
        logger.info(f"🔍 DEBUG: Payload keys: {list(payload.keys())}")

        # Check if Ollama service is running
        try:
            async with session.get(
                f"{self.config['ollama']['endpoint']}/api/tags",
                timeout=aiohttp.ClientTimeout(total=5),
            ) as health_response:
                if health_response.status != 200:
                    logger.error(
                        f"🔍 DEBUG: Ollama service health check failed: {health_response.status}"
                    )
                    raise Exception(
                        f"Ollama service not healthy: {health_response.status}"
                    )
                logger.info("🔍 DEBUG: Ollama service is healthy")
        except Exception as e:
            logger.error(f"🔍 DEBUG: Ollama health check failed: {e}")
            raise Exception(f"Cannot connect to Ollama service: {e}")

        try:
            logger.info("🔍 DEBUG: Sending API request...")
            timeout = aiohttp.ClientTimeout(
                total=60
            )  # Increased timeout for larger models
            async with session.post(url, json=payload, timeout=timeout) as response:
                logger.info(f"🔍 DEBUG: Response status: {response.status}")
                logger.info(f"🔍 DEBUG: Response headers: {dict(response.headers)}")

                response_text = await response.text()
                logger.info(
                    f"🔍 DEBUG: Response text length: {len(response_text)} chars"
                )
                logger.info(
                    f"🔍 DEBUG: Response text preview: {response_text[:200]}..."
                )

                if response.status == 200:
                    logger.info("🔍 DEBUG: Parsing JSON response...")
                    result = json.loads(response_text)
                    logger.info(
                        f"🔍 DEBUG: JSON parsed successfully. Keys: {list(result.keys())}"
                    )
                    response_content = result.get("response", "")
                    logger.info(
                        f"🔍 DEBUG: Response content length: {len(response_content)} chars"
                    )
                    return result
                else:
                    logger.error(
                        f"🔍 DEBUG: API returned error status {response.status}"
                    )
                    logger.error(f"🔍 DEBUG: Error response: {response_text}")
                    raise Exception(
                        f"Ollama API error: {response.status} - {response_text}"
                    )
        except json.JSONDecodeError as e:
            logger.error(f"🔍 DEBUG: JSON decode error: {e}")
            logger.error(f"🔍 DEBUG: Raw response text: {response_text}")
            raise Exception(f"Invalid JSON response from Ollama: {e}")
        except asyncio.TimeoutError as e:
            logger.error(f"🔍 DEBUG: Request timed out: {e}")
            raise Exception(f"Ollama API request timed out: {e}")
        except aiohttp.ClientError as e:
            logger.error(f"🔍 DEBUG: HTTP client error: {e}")
            raise Exception(f"Ollama HTTP client error: {e}")
        except Exception as e:
            logger.error(f"🔍 DEBUG: Unexpected error: {e}")
            logger.error(f"🔍 DEBUG: Error type: {type(e).__name__}")
            raise

    async def _call_huggingface(
        self, model: AIModel, prompt: str, **kwargs
    ) -> Dict[str, Any]:
        """Call Hugging Face API"""
        session = await self._get_session()
        url = f"{self.config['huggingface']['endpoint']}/models/{model.model_id}"

        headers = {}
        if self.config["huggingface"].get("token"):
            headers["Authorization"] = f"Bearer {self.config['huggingface']['token']}"

        payload = {"inputs": prompt, "parameters": kwargs}

        async with session.post(url, json=payload, headers=headers) as response:
            if response.status == 200:
                return await response.json()
            else:
                raise Exception(f"Hugging Face API error: {response.status}")

    async def process_request(self, request: AIRequest) -> AIResponse:
        """Process an AI request with intelligent routing and caching"""
        start_time = time.time()

        # Check cache first
        cache_key = self._get_cache_key(request)
        cached_response = await self._check_cache(cache_key)
        if cached_response:
            logger.info(f"Cache hit for request: {request.task_type}")
            return cached_response

        # Select best model
        model = self._select_best_model(request)

        try:
            # Call the appropriate API
            if model.provider == "ollama":
                result = await self._call_ollama(
                    model,
                    request.prompt,
                    max_tokens=request.max_tokens,
                    temperature=request.temperature,
                )
                content = result.get("response", "")
                tokens_used = result.get("eval_count", len(content.split()))

            elif model.provider == "huggingface":
                result = await self._call_huggingface(
                    model,
                    request.prompt,
                    max_new_tokens=request.max_tokens,
                    temperature=request.temperature,
                )
                # Hugging Face returns list of results
                if isinstance(result, list) and result:
                    content = result[0].get("generated_text", "")
                else:
                    content = str(result)
                tokens_used = len(content.split())

            else:
                raise Exception(f"Unknown provider: {model.provider}")

            processing_time = time.time() - start_time

            response = AIResponse(
                success=True,
                content=content,
                model_used=model.name,
                tokens_used=tokens_used,
                processing_time=processing_time,
                confidence_score=model.performance_score,
                metadata={"provider": model.provider, "model_id": model.model_id},
            )

            # Cache successful responses
            if response.success:
                self._cache_response(cache_key, response)

            return response

        except Exception as e:
            processing_time = time.time() - start_time
            logger.error(f"AI request failed: {e}")

            return AIResponse(
                success=False,
                content="",
                model_used=model.name,
                tokens_used=0,
                processing_time=processing_time,
                error_message=str(e),
            )

    async def analyze_code(self, code: str, task: str = "review") -> AIResponse:
        """Analyze code using AI models"""
        prompts = {
            "review": f"Please review this code and provide feedback:\n\n{code}",
            "bug_detection": f"Analyze this code for potential bugs:\n\n{code}",
            "optimization": f"Suggest optimizations for this code:\n\n{code}",
            "documentation": f"Generate documentation for this code:\n\n{code}",
        }

        prompt = prompts.get(task, prompts["review"])
        request = AIRequest(
            task_type="code_analysis",
            prompt=prompt,
            context={"code": code, "task": task},
        )

        return await self.process_request(request)

    async def predict_performance(self, metrics: Dict[str, Any]) -> AIResponse:
        """Predict system performance based on metrics"""
        prompt = f"""Analyze these system metrics and predict potential performance issues:

{json.dumps(metrics, indent=2)}

Provide insights on:
1. Current performance status
2. Potential bottlenecks
3. Recommended optimizations
4. Future scaling considerations
"""

        request = AIRequest(
            task_type="prediction", prompt=prompt, context={"metrics": metrics}
        )

        return await self.process_request(request)

    async def generate_code(
        self, description: str, language: str = "python"
    ) -> AIResponse:
        """Generate code based on description"""
        prompt = f"Generate {language} code for: {description}\n\nProvide clean, well-documented code:"

        request = AIRequest(
            task_type="code_generation",
            prompt=prompt,
            context={"description": description, "language": language},
        )

        return await self.process_request(request)

    async def close(self):
        """Close HTTP session"""
        if self.session and not self.session.closed:
            await self.session.close()


# Global instance
ai_manager = AIServiceManager()


async def test_ai_services():
    """Test AI services functionality"""
    print("🧪 Testing AI Services...")

    # Test code analysis
    test_code = """
def calculate_average(numbers):
    total = 0
    for num in numbers:
        total += num
    return total / len(numbers)
"""

    print("Testing code analysis...")
    response = await ai_manager.analyze_code(test_code, "review")
    print(f"✅ Code analysis: {response.success}")
    if response.success:
        print(f"Model used: {response.model_used}")
        print(f"Response preview: {response.content[:200]}...")

    # Test performance prediction
    test_metrics = {
        "cpu_percent": 75.5,
        "memory_percent": 82.3,
        "disk_usage": 45.2,
        "active_connections": 150,
        "response_time_p95": 250,
    }

    print("\nTesting performance prediction...")
    response = await ai_manager.predict_performance(test_metrics)
    print(f"✅ Performance prediction: {response.success}")
    if response.success:
        print(f"Model used: {response.model_used}")
        print(f"Response preview: {response.content[:200]}...")

    print("\n🎉 AI Services test completed!")


if __name__ == "__main__":
    asyncio.run(test_ai_services())
