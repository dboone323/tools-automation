#!/usr/bin/env python3
"""
Dependency Analyzer
Analyzes relationships between TODO tasks and establishes dependency chains
"""

import re
from pathlib import Path
from typing import Dict, Any, List, Set
from collections import defaultdict


class DependencyAnalyzer:
    """Analyzes dependencies between TODO tasks"""

    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.config_dir = workspace_root / "config"

        # Dependency patterns to look for
        self.dependency_patterns = {
            "explicit": [
                r"depends on (.+)",
                r"requires (.+)",
                r"after (.+)",
                r"before (.+)",
                r"prerequisite: (.+)",
                r"blocked by (.+)",
            ],
            "file_references": [
                r"update (.+\.(swift|py|js|ts|json|yml|yaml))",
                r"modify (.+\.(swift|py|js|ts|json|yml|yaml))",
                r"fix (.+\.(swift|py|js|ts|json|yml|yaml))",
            ],
            "task_references": [
                r"TODO[:\s]*#?(\d+)",
                r"task[:\s]*#?(\d+)",
                r"issue[:\s]*#?(\d+)",
            ],
            "logical_dependencies": [
                r"implement (.+) first",
                r"complete (.+) before",
                r"finish (.+) then",
            ],
        }

        # File relationship mappings
        self.file_relationships = {
            "imports": self._analyze_import_dependencies,
            "config": self._analyze_config_dependencies,
            "tests": self._analyze_test_dependencies,
            "docs": self._analyze_doc_dependencies,
        }

    def _extract_explicit_dependencies(self, text: str) -> List[str]:
        """Extract explicitly mentioned dependencies from TODO text"""
        dependencies = []

        for pattern in self.dependency_patterns["explicit"]:
            matches = re.findall(pattern, text, re.IGNORECASE)
            dependencies.extend(matches)

        return dependencies

    def _extract_file_references(self, text: str) -> List[str]:
        """Extract file references from TODO text"""
        files = []

        for pattern in self.dependency_patterns["file_references"]:
            matches = re.findall(pattern, text, re.IGNORECASE)
            for match in matches:
                if isinstance(match, tuple):
                    files.append(match[0])  # Take the filename part
                else:
                    files.append(match)

        return files

    def _extract_task_references(self, text: str) -> List[str]:
        """Extract task/issue references from TODO text"""
        tasks = []

        for pattern in self.dependency_patterns["task_references"]:
            matches = re.findall(pattern, text, re.IGNORECASE)
            tasks.extend(matches)

        return tasks

    def _analyze_import_dependencies(self, file_path: str) -> List[str]:
        """Analyze import/dependency relationships for a file"""
        dependencies = []

        try:
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()

            # Swift imports
            if file_path.endswith(".swift"):
                swift_imports = re.findall(r"import\s+(\w+)", content)
                dependencies.extend([f"{imp}.swift" for imp in swift_imports])

            # Python imports
            elif file_path.endswith(".py"):
                py_imports = re.findall(
                    r"^(?:from\s+(\w+)|import\s+(\w+))", content, re.MULTILINE
                )
                for imp in py_imports:
                    if imp[0]:  # from import
                        dependencies.append(f"{imp[0]}.py")
                    elif imp[1]:  # direct import
                        dependencies.append(f"{imp[1]}.py")

            # JavaScript/TypeScript imports
            elif file_path.endswith((".js", ".ts")):
                js_imports = re.findall(
                    r'(?:import|require)\s+[\'"]([^\'"]+)[\'"]', content
                )
                dependencies.extend([imp.split("/")[-1] for imp in js_imports])

        except (FileNotFoundError, IOError):
            pass

        return dependencies

    def _analyze_config_dependencies(self, file_path: str) -> List[str]:
        """Analyze configuration file dependencies"""
        dependencies = []

        if file_path.endswith((".json", ".yml", ".yaml")):
            # Config files often depend on the code they configure
            base_name = Path(file_path).stem

            # Look for related source files
            for ext in [".swift", ".py", ".js", ".ts", ".java"]:
                related_file = Path(file_path).parent / f"{base_name}{ext}"
                if related_file.exists():
                    dependencies.append(str(related_file))

        return dependencies

    def _analyze_test_dependencies(self, file_path: str) -> List[str]:
        """Analyze test file dependencies"""
        dependencies = []

        if "test" in file_path.lower():
            # Test files depend on the code they test
            base_name = Path(file_path).stem

            # Remove test suffixes and look for source files
            source_name = re.sub(r"_?test.*", "", base_name, flags=re.IGNORECASE)

            for ext in [".swift", ".py", ".js", ".ts", ".java"]:
                source_file = Path(file_path).parent / f"{source_name}{ext}"
                if source_file.exists():
                    dependencies.append(str(source_file))

                # Also check parent directories
                parent_source = Path(file_path).parent.parent / f"{source_name}{ext}"
                if parent_source.exists():
                    dependencies.append(str(parent_source))

        return dependencies

    def _analyze_doc_dependencies(self, file_path: str) -> List[str]:
        """Analyze documentation dependencies"""
        dependencies = []

        if file_path.endswith((".md", ".txt", ".rst", ".adoc")):
            # Documentation often depends on the code it documents
            # Look for API docs, README files, etc.
            doc_name = Path(file_path).stem.lower()

            if "readme" in doc_name:
                # README depends on all major source files
                source_files = []
                for ext in [".swift", ".py", ".js", ".ts", ".java"]:
                    source_files.extend(list(self.workspace_root.rglob(f"*{ext}")))

                # Take top 5 most recently modified source files
                source_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                dependencies.extend([str(f) for f in source_files[:5]])

        return dependencies

    def _build_file_dependency_graph(
        self, todos: List[Dict[str, Any]]
    ) -> Dict[str, List[str]]:
        """Build a graph of file dependencies"""
        file_graph = defaultdict(list)

        # Extract all unique files mentioned in TODOs
        todo_files = set()
        for todo in todos:
            file_path = todo.get("file", "")
            if file_path:
                todo_files.add(file_path)

        # Analyze dependencies for each file
        for file_path in todo_files:
            full_path = self.workspace_root / file_path
            if full_path.exists():
                # Determine analysis type based on file
                if any(
                    word in file_path.lower() for word in ["import", "from", "require"]
                ):
                    deps = self._analyze_import_dependencies(str(full_path))
                elif any(
                    file_path.endswith(ext)
                    for ext in [".json", ".yml", ".yaml", ".xml"]
                ):
                    deps = self._analyze_config_dependencies(str(full_path))
                elif "test" in file_path.lower():
                    deps = self._analyze_test_dependencies(str(full_path))
                elif file_path.endswith((".md", ".txt", ".rst", ".adoc")):
                    deps = self._analyze_doc_dependencies(str(full_path))
                else:
                    deps = self._analyze_import_dependencies(str(full_path))

                file_graph[file_path].extend(deps)

        return dict(file_graph)

    def _detect_circular_dependencies(
        self, dependency_graph: Dict[str, List[str]]
    ) -> List[List[str]]:
        """Detect circular dependencies in the graph"""
        cycles = []

        def dfs(node: str, visited: Set[str], path: List[str]):
            if node in path:
                # Found a cycle
                cycle_start = path.index(node)
                cycles.append(path[cycle_start:] + [node])
                return

            if node in visited:
                return

            visited.add(node)
            path.append(node)

            for neighbor in dependency_graph.get(node, []):
                dfs(neighbor, visited, path)

            path.pop()
            visited.remove(node)

        visited = set()
        for node in dependency_graph:
            if node not in visited:
                dfs(node, visited, [])

        return cycles

    def analyze_todo_dependencies(self, todos: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze dependencies between TODO tasks"""
        dependency_info = {
            "explicit_dependencies": [],
            "file_dependencies": {},
            "task_references": [],
            "circular_dependencies": [],
            "dependency_chains": [],
            "priority_suggestions": [],
        }

        # Extract explicit dependencies
        for todo in todos:
            text = todo.get("text", "")
            deps = self._extract_explicit_dependencies(text)
            if deps:
                dependency_info["explicit_dependencies"].append(
                    {"todo": todo, "dependencies": deps}
                )

        # Extract task references
        for todo in todos:
            text = todo.get("text", "")
            tasks = self._extract_task_references(text)
            if tasks:
                dependency_info["task_references"].append(
                    {"todo": todo, "referenced_tasks": tasks}
                )

        # Build file dependency graph
        file_graph = self._build_file_dependency_graph(todos)
        dependency_info["file_dependencies"] = file_graph

        # Detect circular dependencies
        cycles = self._detect_circular_dependencies(file_graph)
        dependency_info["circular_dependencies"] = cycles

        # Build dependency chains
        chains = self._build_dependency_chains(file_graph)
        dependency_info["dependency_chains"] = chains

        # Generate priority suggestions
        suggestions = self._generate_priority_suggestions(todos, file_graph)
        dependency_info["priority_suggestions"] = suggestions

        return dependency_info

    def _build_dependency_chains(
        self, dependency_graph: Dict[str, List[str]]
    ) -> List[List[str]]:
        """Build dependency chains from the graph"""
        chains = []

        def build_chain(start: str, current_chain: List[str], visited: Set[str]):
            if start in visited:
                return

            current_chain.append(start)
            visited.add(start)

            # If this node has no dependencies, it's a chain end
            dependencies = dependency_graph.get(start, [])
            if not dependencies:
                if len(current_chain) > 1:  # Only add chains with dependencies
                    chains.append(current_chain.copy())
            else:
                # Continue the chain with dependencies
                for dep in dependencies:
                    if dep not in current_chain:  # Avoid cycles
                        build_chain(dep, current_chain, visited.copy())

            current_chain.pop()

        # Build chains starting from each node
        for node in dependency_graph:
            build_chain(node, [], set())

        return chains

    def _generate_priority_suggestions(
        self, todos: List[Dict[str, Any]], file_graph: Dict[str, List[str]]
    ) -> List[Dict[str, Any]]:
        """Generate priority suggestions based on dependencies"""
        suggestions = []

        # Create a map of files to TODOs
        file_to_todos = defaultdict(list)
        for todo in todos:
            file_path = todo.get("file", "")
            if file_path:
                file_to_todos[file_path].append(todo)

        # Analyze each dependency chain
        for chain in self._build_dependency_chains(file_graph):
            chain_suggestions = []

            for i, file_path in enumerate(chain):
                todos_for_file = file_to_todos.get(file_path, [])

                for todo in todos_for_file:
                    # Dependencies should have higher priority than dependents
                    base_priority = todo.get("priority", 5)
                    adjusted_priority = min(10, base_priority + (len(chain) - i - 1))

                    if adjusted_priority != base_priority:
                        chain_suggestions.append(
                            {
                                "todo": todo,
                                "original_priority": base_priority,
                                "suggested_priority": adjusted_priority,
                                "reason": f"Dependency chain position {i+1}/{len(chain)}",
                                "chain": chain,
                            }
                        )

            suggestions.extend(chain_suggestions)

        return suggestions

    def resolve_task_dependencies(
        self, tasks: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Resolve and order tasks based on dependencies"""
        # Create task ID to task mapping
        task_map = {task["id"]: task for task in tasks}

        # Build dependency graph
        dependency_graph = defaultdict(list)
        for task in tasks:
            task_id = task["id"]
            dependencies = task.get("dependencies", [])

            # Add explicit dependencies
            dependency_graph[task_id].extend(dependencies)

        # Perform topological sort
        ordered_tasks = []
        visited = set()
        visiting = set()

        def visit(task_id: str):
            if task_id in visiting:
                # Circular dependency detected
                return
            if task_id in visited:
                return

            visiting.add(task_id)

            for dep_id in dependency_graph.get(task_id, []):
                if dep_id in task_map:  # Only visit existing tasks
                    visit(dep_id)

            visiting.remove(task_id)
            visited.add(task_id)
            ordered_tasks.append(task_map[task_id])

        # Visit all tasks
        for task_id in task_map:
            if task_id not in visited:
                visit(task_id)

        return ordered_tasks


def main():
    """Test the dependency analyzer with sample TODOs"""
    workspace_root = Path(__file__).parent.parent
    analyzer = DependencyAnalyzer(workspace_root)

    # Sample TODOs with dependencies
    sample_todos = [
        {
            "file": "src/AuthService.swift",
            "line": 10,
            "text": "TODO: Implement user authentication service",
            "priority": 8,
        },
        {
            "file": "src/UserModel.swift",
            "line": 5,
            "text": "TODO: Create user data model (depends on database schema)",
            "priority": 7,
        },
        {
            "file": "config/database.json",
            "line": 15,
            "text": "TODO: Define database schema for users",
            "priority": 9,
        },
        {
            "file": "tests/AuthTests.py",
            "line": 20,
            "text": "TODO: Add unit tests for authentication (requires AuthService)",
            "priority": 6,
        },
        {
            "file": "README.md",
            "line": 25,
            "text": "TODO: Update API documentation (after implementing auth)",
            "priority": 4,
        },
    ]

    print("🔗 Testing Dependency Analyzer")
    print("=" * 50)

    dependency_info = analyzer.analyze_todo_dependencies(sample_todos)

    print(
        f"\n📋 Explicit Dependencies Found: {len(dependency_info['explicit_dependencies'])}"
    )
    for dep in dependency_info["explicit_dependencies"]:
        print(f"  - {dep['todo']['file']}: {dep['todo']['text'][:50]}...")
        print(f"    Depends on: {dep['dependencies']}")

    print(f"\n🔄 File Dependencies: {len(dependency_info['file_dependencies'])}")
    for file_path, deps in dependency_info["file_dependencies"].items():
        if deps:
            print(f"  - {file_path} depends on: {deps}")

    print(
        f"\n⚠️  Circular Dependencies: {len(dependency_info['circular_dependencies'])}"
    )
    for cycle in dependency_info["circular_dependencies"]:
        print(f"  - Cycle detected: {' -> '.join(cycle)}")

    print(f"\n⛓️  Dependency Chains: {len(dependency_info['dependency_chains'])}")
    for chain in dependency_info["dependency_chains"]:
        print(f"  - Chain: {' -> '.join(chain)}")

    print(f"\n🎯 Priority Suggestions: {len(dependency_info['priority_suggestions'])}")
    for suggestion in dependency_info["priority_suggestions"]:
        todo = suggestion["todo"]
        print(
            f"  - {todo['file']}: Priority {suggestion['original_priority']} -> {suggestion['suggested_priority']}"
        )
        print(f"    Reason: {suggestion['reason']}")


if __name__ == "__main__":
    main()
