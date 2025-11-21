#!/usr/bin/env python3
"""
Distributed State Manager
Provides shared state coordination for agents with Redis backend and in-memory fallback
"""

import json
import os
import sys
import time
import threading
from typing import Dict, List, Optional, Any, Set
from datetime import datetime, timedelta
import subprocess

class DistributedStateManager:
    """Manages distributed state across agents with Redis backend"""
    
    def __init__(self, redis_host: str = 'localhost', redis_port: int = 6379,
                 use_redis: bool = True):
        """Initialize state manager"""
        self.redis_client = None
        self.use_redis = use_redis
        self.fallback_store = {}
        self.locks = {}
        self.lock_mutex = threading.Lock()
        
        if use_redis:
            try:
                import redis
                self.redis_client = redis.StrictRedis(
                    host=redis_host, 
                    port=redis_port,
                    db=0,
                    decode_responses=True,
                    socket_connect_timeout=2
                )
                self.redis_client.ping()
                print(f"✅ Connected to Redis at {redis_host}:{redis_port}")
            except Exception as e:
                print(f"⚠️  Redis unavailable ({e}), using in-memory fallback")
                self.redis_client = None
    
    def set_state(self, key: str, value: Any, ttl: int = None) -> bool:
        """Set a state value with optional TTL (seconds)"""
        try:
            value_json = json.dumps(value)
            
            if self.redis_client:
                if ttl:
                    self.redis_client.setex(key, ttl, value_json)
                else:
                    self.redis_client.set(key, value_json)
                return True
            else:
                # Fallback to in-memory
                self.fallback_store[key] = {
                    'value': value_json,
                    'expires_at': time.time() + ttl if ttl else None
                }
                return True
        except Exception as e:
            print(f"❌ Error setting state for {key}: {e}", file=sys.stderr)
            return False
    
    def get_state(self, key: str, default: Any = None) -> Any:
        """Get a state value"""
        try:
            if self.redis_client:
                value_json = self.redis_client.get(key)
                if value_json:
                    return json.loads(value_json)
                return default
            else:
                # Fallback to in-memory
                entry = self.fallback_store.get(key)
                if entry:
                    # Check expiration
                    if entry['expires_at'] and entry['expires_at'] < time.time():
                        del self.fallback_store[key]
                        return default
                    return json.loads(entry['value'])
                return default
        except Exception as e:
            print(f"❌ Error getting state for {key}: {e}", file=sys.stderr)
            return default
    
    def delete_state(self, key: str) -> bool:
        """Delete a state value"""
        try:
            if self.redis_client:
                self.redis_client.delete(key)
                return True
            else:
                if key in self.fallback_store:
                    del self.fallback_store[key]
                return True
        except Exception as e:
            print(f"❌ Error deleting state for {key}: {e}", file=sys.stderr)
            return False
    
    def acquire_lock(self, lock_name: str, timeout: int = 10, 
                     wait_timeout: int = 30) -> bool:
        """
        Acquire a distributed lock
        
        Args:
            lock_name: Name of the lock
            timeout: Lock timeout in seconds
            wait_timeout: How long to wait to acquire lock
        
        Returns:
            True if lock acquired, False otherwise
        """
        lock_key = f"lock:{lock_name}"
        lock_value = f"{os.getpid()}:{time.time()}"
        start_time = time.time()
        
        while True:
            try:
                if self.redis_client:
                    # Try to acquire lock with Redis
                    acquired = self.redis_client.set(
                        lock_key, 
                        lock_value,
                        nx=True,  # Only set if not exists
                        ex=timeout  # Expire after timeout
                    )
                    if acquired:
                        return True
                else:
                    # Fallback to in-memory lock
                    with self.lock_mutex:
                        entry = self.locks.get(lock_name)
                        if not entry or entry['expires_at'] < time.time():
                            self.locks[lock_name] = {
                                'value': lock_value,
                                'expires_at': time.time() + timeout
                            }
                            return True
                
                # Check if we've waited too long
                if time.time() - start_time > wait_timeout:
                    return False
                
                # Wait a bit before retrying
                time.sleep(0.1)
            except Exception as e:
                print(f"❌ Error acquiring lock {lock_name}: {e}", file=sys.stderr)
                return False
    
    def release_lock(self, lock_name: str) -> bool:
        """Release a distributed lock"""
        lock_key = f"lock:{lock_name}"
        
        try:
            if self.redis_client:
                self.redis_client.delete(lock_key)
                return True
            else:
                with self.lock_mutex:
                    if lock_name in self.locks:
                        del self.locks[lock_name]
                return True
        except Exception as e:
            print(f"❌ Error releasing lock {lock_name}: {e}", file=sys.stderr)
            return False
    
    def add_to_set(self, set_name: str, value: str) -> bool:
        """Add value to a distributed set"""
        try:
            if self.redis_client:
                self.redis_client.sadd(set_name, value)
                return True
            else:
                # Fallback to in-memory
                current = self.get_state(set_name, set())
                if not isinstance(current, set):
                    current = set(current) if current else set()
                current.add(value)
                self.set_state(set_name, list(current))
                return True
        except Exception as e:
            print(f"❌ Error adding to set {set_name}: {e}", file=sys.stderr)
            return False
    
    def remove_from_set(self, set_name: str, value: str) -> bool:
        """Remove value from a distributed set"""
        try:
            if self.redis_client:
                self.redis_client.srem(set_name, value)
                return True
            else:
                current = self.get_state(set_name, set())
                if not isinstance(current, set):
                    current = set(current) if current else set()
                current.discard(value)
                self.set_state(set_name, list(current))
                return True
        except Exception as e:
            print(f"❌ Error removing from set {set_name}: {e}", file=sys.stderr)
            return False
    
    def get_set_members(self, set_name: str) -> Set[str]:
        """Get all members of a distributed set"""
        try:
            if self.redis_client:
                return self.redis_client.smembers(set_name)
            else:
                current = self.get_state(set_name, [])
                return set(current) if current else set()
        except Exception as e:
            print(f"❌ Error getting set {set_name}: {e}", file=sys.stderr)
            return set()
    
    def increment_counter(self, counter_name: str, amount: int = 1) -> int:
        """Atomically increment a counter"""
        try:
            if self.redis_client:
                return self.redis_client.incrby(counter_name, amount)
            else:
                with self.lock_mutex:
                    current = self.get_state(counter_name, 0)
                    new_value = current + amount
                    self.set_state(counter_name, new_value)
                    return new_value
        except Exception as e:
            print(f"❌ Error incrementing counter {counter_name}: {e}", file=sys.stderr)
            return 0
    
    def publish_event(self, channel: str, message: Dict[str, Any]) -> bool:
        """Publish an event to a channel"""
        try:
            message_json = json.dumps(message)
            
            if self.redis_client:
                self.redis_client.publish(channel, message_json)
                return True
            else:
                # For fallback, just store in a list (limited pub/sub simulation)
                events = self.get_state(f"events:{channel}", [])
                events.append({
                    'message': message,
                    'timestamp': time.time()
                })
                # Keep only last 100 events
                self.set_state(f"events:{channel}", events[-100:])
                return True
        except Exception as e:
            print(f"❌ Error publishing to {channel}: {e}", file=sys.stderr)
            return False
    
    def register_agent(self, agent_name: str, metadata: Dict[str, Any] = None) -> bool:
        """Register an agent as active"""
        try:
            agent_key = f"agent:active:{agent_name}"
            agent_data = {
                'name': agent_name,
                'registered_at': time.time(),
                'pid': os.getpid(),
                'metadata': metadata or {}
            }
            
            # Set with 5-minute TTL (agent should refresh periodically)
            self.set_state(agent_key, agent_data, ttl=300)
            self.add_to_set('agents:active', agent_name)
            
            return True
        except Exception as e:
            print(f"❌ Error registering agent {agent_name}: {e}", file=sys.stderr)
            return False
    
    def unregister_agent(self, agent_name: str) -> bool:
        """Unregister an agent"""
        try:
            agent_key = f"agent:active:{agent_name}"
            self.delete_state(agent_key)
            self.remove_from_set('agents:active', agent_name)
            return True
        except Exception as e:
            print(f"❌ Error unregistering agent {agent_name}: {e}", file=sys.stderr)
            return False
    
    def get_active_agents(self) -> List[Dict[str, Any]]:
        """Get list of all active agents"""
        try:
            agent_names = self.get_set_members('agents:active')
            agents = []
            
            for name in agent_names:
                agent_data = self.get_state(f"agent:active:{name}")
                if agent_data:
                    agents.append(agent_data)
            
            return agents
        except Exception as e:
            print(f"❌ Error getting active agents: {e}", file=sys.stderr)
            return []
    
    def coordinate_task(self, task_id: str, agent_name: str, 
                       task_data: Dict[str, Any]) -> bool:
        """
        Coordinate a task across agents
        
        Args:
            task_id: Unique task identifier
            agent_name: Agent claiming the task
            task_data: Task information
        
        Returns:
            True if task claimed, False if already claimed
        """
        lock_name = f"task_claim:{task_id}"
        
        if self.acquire_lock(lock_name, timeout=5, wait_timeout=1):
            try:
                # Check if task already claimed
                task_key = f"task:active:{task_id}"
                existing = self.get_state(task_key)
                
                if existing and existing.get('agent') != agent_name:
                    # Task already claimed by another agent
                    return False
                
                # Claim the task
                task_info = {
                    'task_id': task_id,
                    'agent': agent_name,
                    'claimed_at': time.time(),
                    'data': task_data
                }
                
                self.set_state(task_key, task_info, ttl=3600)  # 1 hour TTL
                return True
            finally:
                self.release_lock(lock_name)
        
        return False
    
    def complete_task(self, task_id: str, result: Dict[str, Any]) -> bool:
        """Mark a task as complete"""
        try:
            task_key = f"task:active:{task_id}"
            task_info = self.get_state(task_key)
            
            if task_info:
                task_info['completed_at'] = time.time()
                task_info['result'] = result
                
                # Move to completed
                completed_key = f"task:completed:{task_id}"
                self.set_state(completed_key, task_info, ttl=86400)  # Keep for 1 day
                self.delete_state(task_key)
                
                return True
            return False
        except Exception as e:
            print(f"❌ Error completing task {task_id}: {e}", file=sys.stderr)
            return False
    
    def get_stats(self) -> Dict[str, Any]:
        """Get state manager statistics"""
        return {
            'backend': 'redis' if self.redis_client else 'in-memory',
            'active_agents': len(self.get_set_members('agents:active')),
            'agent_list': list(self.get_set_members('agents:active')),
            'fallback_keys': len(self.fallback_store) if not self.redis_client else 'N/A',
            'active_locks': len(self.locks) if not self.redis_client else 'N/A'
        }


def main():
    """CLI interface for state manager"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Distributed State Manager")
    parser.add_argument('--redis-host', default='localhost', help="Redis host")
    parser.add_argument('--redis-port', type=int, default=6379, help="Redis port")
    parser.add_argument('--no-redis', action='store_true', help="Use in-memory fallback")
    
    subparsers = parser.add_subparsers(dest='command', help='Command')
    
    # Set state
    set_parser = subparsers.add_parser('set', help='Set state value')
    set_parser.add_argument('key', help='State key')
    set_parser.add_argument('value', help='State value (JSON)')
    set_parser.add_argument('--ttl', type=int, help='TTL in seconds')
    
    # Get state
    get_parser = subparsers.add_parser('get', help='Get state value')
    get_parser.add_argument('key', help='State key')
    
    # Delete state
    del_parser = subparsers.add_parser('delete', help='Delete state value')
    del_parser.add_argument('key', help='State key')
    
    # List active agents
    subparsers.add_parser('agents', help='List active agents')
    
    # Stats
    subparsers.add_parser('stats', help='Show statistics')
    
    # Test coordination
    coord_parser = subparsers.add_parser('test-coord', help='Test coordination')
    coord_parser.add_argument('agent', help='Agent name')
    
    args = parser.parse_args()
    
    # Initialize state manager
    manager = DistributedStateManager(
        redis_host=args.redis_host,
        redis_port=args.redis_port,
        use_redis=not args.no_redis
    )
    
    if args.command == 'set':
        value = json.loads(args.value)
        if manager.set_state(args.key, value, ttl=args.ttl):
            print(f"✅ Set {args.key}")
        else:
            print(f"❌ Failed to set {args.key}")
    
    elif args.command == 'get':
        value = manager.get_state(args.key)
        print(json.dumps(value, indent=2))
    
    elif args.command == 'delete':
        if manager.delete_state(args.key):
            print(f"✅ Deleted {args.key}")
        else:
            print(f"❌ Failed to delete {args.key}")
    
    elif args.command == 'agents':
        agents = manager.get_active_agents()
        print(json.dumps(agents, indent=2))
    
    elif args.command == 'stats':
        stats = manager.get_stats()
        print(json.dumps(stats, indent=2))
    
    elif args.command == 'test-coord':
        # Test coordination
        print(f"🧪 Testing coordination for agent: {args.agent}")
        
        # Register agent
        if manager.register_agent(args.agent, {'test': True}):
            print(f"✅ Registered agent")
        
        # Try to coordinate a task
        task_id = f"test_task_{int(time.time())}"
        if manager.coordinate_task(task_id, args.agent, {'action': 'test'}):
            print(f"✅ Claimed task {task_id}")
            
            # Complete the task
            time.sleep(1)
            if manager.complete_task(task_id, {'status': 'success'}):
                print(f"✅ Completed task {task_id}")
        
        # Show stats
        stats = manager.get_stats()
        print(f"\n📊 Stats: {json.dumps(stats, indent=2)}")
        
        # Unregister
        if manager.unregister_agent(args.agent):
            print(f"✅ Unregistered agent")


if __name__ == '__main__':
    main()
