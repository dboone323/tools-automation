#!/usr/bin/env python3
"""
Working Performance Optimizer for Phase 3 Testing
"""

import psutil
import time
import os
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict

@dataclass
class PerformanceMetrics:
    cpu_percent: float
    memory_percent: float
    disk_usage: float
    timestamp: float

class PerformanceOptimizer:
    def __init__(self):
        self.metrics_history: List[PerformanceMetrics] = []
        self.cache: Dict = {}
        self.optimization_enabled = True
    
    def collect_metrics(self) -> PerformanceMetrics:
        """Collect current system performance metrics"""
        cpu = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory().percent
        disk = psutil.disk_usage('/').percent
        
        metrics = PerformanceMetrics(
            cpu_percent=cpu,
            memory_percent=memory,
            disk_usage=disk,
            timestamp=time.time()
        )
        
        self.metrics_history.append(metrics)
        
        # Keep only last 100 metrics
        if len(self.metrics_history) > 100:
            self.metrics_history = self.metrics_history[-100:]
        
        return metrics
    
    def get_performance_summary(self) -> Dict:
        """Get performance summary"""
        if not self.metrics_history:
            return {"status": "no_data"}
        
        recent_metrics = self.metrics_history[-10:] if len(self.metrics_history) >= 10 else self.metrics_history
        
        avg_cpu = sum(m.cpu_percent for m in recent_metrics) / len(recent_metrics)
        avg_memory = sum(m.memory_percent for m in recent_metrics) / len(recent_metrics)
        avg_disk = sum(m.disk_usage for m in recent_metrics) / len(recent_metrics)
        
        return {
            "status": "active",
            "avg_cpu_percent": round(avg_cpu, 2),
            "avg_memory_percent": round(avg_memory, 2),
            "avg_disk_usage": round(avg_disk, 2),
            "total_samples": len(self.metrics_history),
            "cache_size": len(self.cache)
        }
    
    def optimize_cache(self, key: str, value: any, ttl: int = 300):
        """Simple cache optimization"""
        self.cache[key] = {
            "value": value,
            "timestamp": time.time(),
            "ttl": ttl
        }
    
    def get_cached(self, key: str) -> Optional[any]:
        """Get cached value if valid"""
        if key in self.cache:
            item = self.cache[key]
            if time.time() - item["timestamp"] < item["ttl"]:
                return item["value"]
            else:
                del self.cache[key]
        return None
    
    def cleanup_cache(self):
        """Remove expired cache entries"""
        current_time = time.time()
        expired_keys = []
        
        for key, item in self.cache.items():
            if current_time - item["timestamp"] >= item["ttl"]:
                expired_keys.append(key)
        
        for key in expired_keys:
            del self.cache[key]
        
        return len(expired_keys)
    
    def get_optimization_suggestions(self) -> List[str]:
        """Get optimization suggestions based on current metrics"""
        suggestions = []
        
        if not self.metrics_history:
            return ["Collect performance metrics first"]
        
        latest = self.metrics_history[-1]
        
        if latest.cpu_percent > 80:
            suggestions.append("High CPU usage detected - consider optimizing intensive processes")
        
        if latest.memory_percent > 85:
            suggestions.append("High memory usage detected - consider increasing swap or reducing memory-intensive tasks")
        
        if latest.disk_usage > 90:
            suggestions.append("High disk usage detected - consider cleanup or expanding storage")
        
        if len(self.cache) > 1000:
            suggestions.append("Large cache detected - consider cleanup")
        
        if not suggestions:
            suggestions.append("System performance is optimal")
        
        return suggestions
    
    def get_status(self):
        """Get optimizer status"""
        return {
            "optimization_enabled": self.optimization_enabled,
            "metrics_collected": len(self.metrics_history),
            "cache_entries": len(self.cache),
            "last_collection": self.metrics_history[-1].timestamp if self.metrics_history else None
        }

# Global instance
_optimizer = None

def get_optimizer():
    global _optimizer
    if _optimizer is None:
        _optimizer = PerformanceOptimizer()
    return _optimizer

def main():
    optimizer = get_optimizer()
    
    print("Collecting performance metrics...")
    metrics = optimizer.collect_metrics()
    print(f"Current metrics: CPU {metrics.cpu_percent}%, Memory {metrics.memory_percent}%, Disk {metrics.disk_usage}%")
    
    # Test cache
    optimizer.optimize_cache("test_key", "test_value", 60)
    cached_value = optimizer.get_cached("test_key")
    print(f"Cache test: {cached_value}")
    
    # Get suggestions
    suggestions = optimizer.get_optimization_suggestions()
    print(f"Optimization suggestions: {suggestions}")
    
    print("Optimizer status:", optimizer.get_status())

if __name__ == "__main__":
    main()
