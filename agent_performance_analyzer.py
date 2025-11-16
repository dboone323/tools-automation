#!/usr/bin/env python3
"""
Agent Performance Analytics using scikit-learn
Provides predictive analytics and performance optimization for agents
"""

import json
import numpy as np
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict
import os
import sys

try:
    from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import StandardScaler, LabelEncoder
    from sklearn.metrics import (
        accuracy_score,
        mean_squared_error,
        classification_report,
    )
    from sklearn.cluster import KMeans

    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False
    print("Warning: scikit-learn not available, using basic analytics")

try:
    import joblib

    JOBLIB_AVAILABLE = True
except ImportError:
    JOBLIB_AVAILABLE = False
    print("Warning: joblib not available, cannot load trained models")


class AgentPerformanceAnalyzer:
    """Analyze and predict agent performance using machine learning"""

    def __init__(self, workspace_root: str = None):
        """Initialize the performance analyzer"""
        self.workspace_root = workspace_root or os.getcwd()
        self.models_dir = os.path.join(self.workspace_root, "models")

        if SKLEARN_AVAILABLE:
            self.performance_model = None
            self.failure_predictor = None
            self.scaler_time = StandardScaler()
            self.scaler_failure = StandardScaler()
            self.label_encoder = LabelEncoder()
        else:
            print("Scikit-learn not available, using basic statistics")
            self.performance_model = None
            self.failure_predictor = None
            self.scaler_time = None
            self.scaler_failure = None
            self.label_encoder = None

        # Try to load trained models
        self.load_trained_models()

    def load_trained_models(self):
        """Load pre-trained models from the models directory"""
        if not JOBLIB_AVAILABLE:
            print("Joblib not available, cannot load trained models")
            return

        try:
            # Load execution time model
            time_model_path = os.path.join(self.models_dir, "execution_time_model.pkl")
            time_scaler_path = os.path.join(
                self.models_dir, "execution_time_scaler.pkl"
            )

            if os.path.exists(time_model_path) and os.path.exists(time_scaler_path):
                self.performance_model = joblib.load(time_model_path)
                self.scaler_time = joblib.load(time_scaler_path)
                print("✓ Loaded trained execution time model")
            else:
                print("Execution time model not found, will use fallback")

            # Load failure probability model
            failure_model_path = os.path.join(
                self.models_dir, "failure_probability_model.pkl"
            )
            failure_scaler_path = os.path.join(
                self.models_dir, "failure_probability_scaler.pkl"
            )

            if os.path.exists(failure_model_path) and os.path.exists(
                failure_scaler_path
            ):
                self.failure_predictor = joblib.load(failure_model_path)
                self.scaler_failure = joblib.load(failure_scaler_path)
                print("✓ Loaded trained failure probability model")
            else:
                print("Failure probability model not found, will use fallback")

            # Load label encoder
            encoder_path = os.path.join(self.models_dir, "task_type_encoder.pkl")
            if os.path.exists(encoder_path):
                self.label_encoder = joblib.load(encoder_path)
                print("✓ Loaded task type encoder")
            else:
                print("Task type encoder not found")

        except Exception as e:
            print(f"Error loading trained models: {e}")
            print("Will use fallback methods")

    def load_performance_data(
        self, data_file: str = "agent_performance.json"
    ) -> pd.DataFrame:
        """Load and preprocess agent performance data"""
        try:
            with open(data_file, "r") as f:
                data = json.load(f)

            # Convert to DataFrame
            df = pd.DataFrame(data.get("performance_records", []))

            if df.empty:
                # Create sample data if none exists
                df = self._create_sample_data()

            # Preprocess data
            df = self._preprocess_data(df)

            return df

        except FileNotFoundError:
            print(f"Performance data file {data_file} not found. Creating sample data.")
            df = self._create_sample_data()
            return self._preprocess_data(df)

    def _create_sample_data(self) -> pd.DataFrame:
        """Create sample performance data for demonstration"""
        agents = [
            "agent_codegen",
            "agent_testing",
            "agent_deployment",
            "agent_monitoring",
        ]
        tasks = [
            "code_generation",
            "test_execution",
            "deployment",
            "monitoring",
            "security_scan",
        ]

        records = []
        base_time = datetime.now() - timedelta(days=30)

        for i in range(1000):  # Generate 1000 sample records
            agent = np.random.choice(agents)
            task_type = np.random.choice(tasks)

            # Simulate realistic performance metrics
            execution_time = np.random.exponential(10) + 5  # 5-15 seconds average
            success_rate = np.random.beta(8, 2)  # Generally high success rate
            cpu_usage = np.random.normal(60, 15)  # 60% average CPU
            memory_usage = np.random.normal(70, 20)  # 70% average memory

            # Add some correlation between agent type and performance
            if agent == "agent_testing":
                execution_time *= 1.5  # Testing takes longer
            elif agent == "agent_deployment":
                success_rate *= 0.9  # Deployment has more failures

            records.append(
                {
                    "timestamp": (base_time + timedelta(minutes=i * 2)).isoformat(),
                    "agent": agent,
                    "task_type": task_type,
                    "execution_time": round(execution_time, 2),
                    "success": np.random.random() < success_rate,
                    "cpu_usage": max(0, min(100, cpu_usage)),
                    "memory_usage": max(0, min(100, memory_usage)),
                    "task_complexity": np.random.randint(1, 10),
                }
            )

        return pd.DataFrame(records)

    def _preprocess_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """Preprocess the performance data"""
        # Convert timestamp to datetime
        df["timestamp"] = pd.to_datetime(df["timestamp"])

        # Extract time features
        df["hour"] = df["timestamp"].dt.hour
        df["day_of_week"] = df["timestamp"].dt.dayofweek
        df["month"] = df["timestamp"].dt.month

        if SKLEARN_AVAILABLE:
            # Encode categorical variables
            df["agent_encoded"] = self.label_encoder.fit_transform(df["agent"])
        else:
            # Simple encoding without sklearn
            agent_mapping = {agent: i for i, agent in enumerate(df["agent"].unique())}
            df["agent_encoded"] = df["agent"].map(agent_mapping)

        df["task_encoded"] = pd.Categorical(df["task_type"]).codes

        # Create success rate feature
        df["success_rate"] = df.groupby("agent")["success"].transform("mean")

        return df

    def train_performance_model(self, df: pd.DataFrame) -> Dict:
        """Train a model to predict execution time"""
        if not SKLEARN_AVAILABLE:
            # Fallback: return basic statistics
            mean_time = df["execution_time"].mean()
            std_time = df["execution_time"].std()
            return {
                "model_type": "basic_statistics",
                "mean_execution_time": mean_time,
                "std_execution_time": std_time,
                "note": "Using basic statistics (scikit-learn not available)",
            }

        # Features for prediction
        features = [
            "agent_encoded",
            "task_encoded",
            "hour",
            "day_of_week",
            "cpu_usage",
            "memory_usage",
            "task_complexity",
        ]

        X = df[features]
        y = df["execution_time"]

        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)

        # Train model
        self.performance_model = RandomForestRegressor(
            n_estimators=100, random_state=42
        )
        self.performance_model.fit(X_train_scaled, y_train)

        # Evaluate
        y_pred = self.performance_model.predict(X_test_scaled)
        mse = mean_squared_error(y_test, y_pred)
        rmse = np.sqrt(mse)

        return {
            "model_type": "execution_time_predictor",
            "rmse": rmse,
            "feature_importance": dict(
                zip(features, self.performance_model.feature_importances_)
            ),
        }

    def train_failure_predictor(self, df: pd.DataFrame) -> Dict:
        """Train a model to predict task failures"""
        features = [
            "agent_encoded",
            "task_encoded",
            "hour",
            "day_of_week",
            "cpu_usage",
            "memory_usage",
            "task_complexity",
        ]

        X = df[features]
        y = df["success"].astype(int)

        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)

        self.failure_predictor = RandomForestClassifier(
            n_estimators=100, random_state=42
        )
        self.failure_predictor.fit(X_train_scaled, y_train)

        y_pred = self.failure_predictor.predict(X_test_scaled)
        accuracy = accuracy_score(y_test, y_pred)

        return {
            "model_type": "failure_predictor",
            "accuracy": accuracy,
            "classification_report": classification_report(
                y_test, y_pred, target_names=["Failure", "Success"]
            ),
        }

    def predict_execution_time(
        self,
        task_type: str,
        cpu_usage: float,
        memory_usage: float,
        disk_usage: float = 0,
        process_count: int = 0,
        agent_count: int = 1,
        files_processed: int = 0,
        issues_found: int = 0,
    ) -> float:
        """Predict execution time for a task"""
        if self.performance_model and self.scaler_time:
            # Use trained model
            try:
                # Encode task type
                try:
                    task_encoded = self.label_encoder.transform([task_type])[0]
                except Exception:
                    task_encoded = 0  # Default for unknown task type

                # Create feature array (matching training features)
                features = np.array(
                    [
                        [
                            cpu_usage,
                            memory_usage,
                            disk_usage,
                            process_count,
                            agent_count,
                            task_encoded,
                            files_processed,
                            issues_found,
                        ]
                    ]
                )

                # Scale and predict
                features_scaled = self.scaler_time.transform(features)
                prediction = self.performance_model.predict(features_scaled)[0]

                return max(0, prediction)

            except Exception as e:
                print(
                    f"Error using trained model: {e}, falling back to basic prediction"
                )
                return self._basic_execution_time_prediction(
                    task_type,
                    cpu_usage,
                    memory_usage,
                    disk_usage,
                    process_count,
                    agent_count,
                    files_processed,
                    issues_found,
                )

        else:
            # Fallback to basic prediction
            return self._basic_execution_time_prediction(
                task_type,
                cpu_usage,
                memory_usage,
                disk_usage,
                process_count,
                agent_count,
                files_processed,
                issues_found,
            )

    def predict_failure_probability(
        self,
        task_type: str,
        cpu_usage: float,
        memory_usage: float,
        disk_usage: float = 0,
        process_count: int = 0,
        agent_count: int = 1,
        files_processed: int = 0,
        issues_found: int = 0,
        duration_seconds: int = 0,
    ) -> float:
        """Predict probability of task failure"""
        if self.failure_predictor and self.scaler_failure:
            # Use trained model
            try:
                # Encode task type
                try:
                    task_encoded = self.label_encoder.transform([task_type])[0]
                except Exception:
                    task_encoded = 0  # Default for unknown task type

                # Create feature array (matching training features)
                features = np.array(
                    [
                        [
                            cpu_usage,
                            memory_usage,
                            disk_usage,
                            process_count,
                            agent_count,
                            task_encoded,
                            files_processed,
                            issues_found,
                            duration_seconds,
                        ]
                    ]
                )

                # Scale and predict
                features_scaled = self.scaler_failure.transform(features)
                probabilities = self.failure_predictor.predict_proba(features_scaled)[0]

                return probabilities[0]  # Probability of failure (class 0)

            except Exception as e:
                print(
                    f"Error using trained model: {e}, falling back to basic prediction"
                )
                return self._basic_failure_probability_prediction(
                    task_type,
                    cpu_usage,
                    memory_usage,
                    disk_usage,
                    process_count,
                    agent_count,
                    files_processed,
                    issues_found,
                )

        else:
            # Fallback to basic prediction
            return self._basic_failure_probability_prediction(
                task_type,
                cpu_usage,
                memory_usage,
                disk_usage,
                process_count,
                agent_count,
                files_processed,
                issues_found,
            )

    def _basic_execution_time_prediction(
        self,
        task_type: str,
        cpu_usage: float,
        memory_usage: float,
        disk_usage: float,
        process_count: int,
        agent_count: int,
        files_processed: int,
        issues_found: int,
    ) -> float:
        """Basic execution time prediction using heuristics"""
        base_time = 10.0  # Base 10 seconds

        # Adjust based on task type
        task_multipliers = {
            "code_generation": 1.2,
            "test_execution": 1.5,
            "deployment": 1.8,
            "monitoring": 0.8,
            "security_scan": 1.3,
            "codegen": 1.2,
            "ai_automation": 1.4,
            "autofix": 1.1,
            "enhance": 1.6,
            "validate": 1.0,
            "test_codegen": 1.3,
            "search": 1.0,
            "security": 1.3,
            "build": 1.5,
            "generate": 1.2,
            "ux": 1.4,
            "debug": 1.1,
            "testing": 1.5,
            "swift": 1.3,
            "collaboration": 1.2,
            "documentation": 1.1,
        }

        multiplier = task_multipliers.get(task_type.lower(), 1.0)
        base_time *= multiplier

        # Adjust based on files processed
        if files_processed > 0:
            base_time *= 1 + (files_processed / 100)

        # Adjust based on issues found
        if issues_found > 0:
            base_time *= 1 + (issues_found / 10)

        # Adjust based on resource usage
        resource_factor = (cpu_usage + memory_usage + disk_usage) / 300  # Normalize
        base_time *= 1 + resource_factor

        # Adjust based on agent count
        if agent_count > 1:
            base_time *= 1 / agent_count  # Parallel processing

        return max(1.0, base_time)

    def _basic_failure_probability_prediction(
        self,
        task_type: str,
        cpu_usage: float,
        memory_usage: float,
        disk_usage: float,
        process_count: int,
        agent_count: int,
        files_processed: int,
        issues_found: int,
    ) -> float:
        """Basic failure probability prediction using heuristics"""
        base_probability = 0.05  # Base 5% failure rate

        # Adjust based on task type
        task_risks = {
            "deployment": 0.15,  # Higher risk
            "security_scan": 0.08,
            "test_execution": 0.07,
            "code_generation": 0.06,
            "monitoring": 0.03,
            "ai_automation": 0.08,
            "autofix": 0.06,
            "enhance": 0.07,
            "validate": 0.04,
            "test_codegen": 0.06,
            "search": 0.04,
            "security": 0.08,
            "build": 0.10,
            "generate": 0.06,
            "ux": 0.05,
            "debug": 0.07,
            "testing": 0.07,
            "swift": 0.06,
            "collaboration": 0.05,
            "documentation": 0.03,
        }

        risk = task_risks.get(task_type.lower(), 0.05)
        base_probability = risk

        # Adjust based on resource usage (higher usage = higher risk)
        resource_risk = (
            cpu_usage + memory_usage + disk_usage
        ) / 3000  # Small adjustment
        base_probability += resource_risk

        # Adjust based on issues found (more issues = higher risk)
        if issues_found > 0:
            base_probability += issues_found / 100

        # Adjust based on files processed (more files = slightly higher risk)
        if files_processed > 100:
            base_probability += (files_processed - 100) / 1000

        return min(0.95, max(0.01, base_probability))

    def cluster_agents_by_performance(
        self, df: pd.DataFrame, n_clusters: int = 3
    ) -> Dict:
        """Cluster agents by performance patterns"""
        # Aggregate performance metrics by agent
        agent_performance = (
            df.groupby("agent")
            .agg(
                {
                    "execution_time": "mean",
                    "success": "mean",
                    "cpu_usage": "mean",
                    "memory_usage": "mean",
                }
            )
            .reset_index()
        )

        # Prepare features for clustering
        features = ["execution_time", "success", "cpu_usage", "memory_usage"]
        X = agent_performance[features]

        # Scale features
        X_scaled = StandardScaler().fit_transform(X)

        # Perform clustering
        kmeans = KMeans(n_clusters=n_clusters, random_state=42)
        clusters = kmeans.fit_predict(X_scaled)

        agent_performance["cluster"] = clusters

        # Analyze clusters
        cluster_analysis = {}
        for cluster in range(n_clusters):
            cluster_data = agent_performance[agent_performance["cluster"] == cluster]
            cluster_analysis[f"cluster_{cluster}"] = {
                "agents": cluster_data["agent"].tolist(),
                "avg_execution_time": cluster_data["execution_time"].mean(),
                "avg_success_rate": cluster_data["success"].mean(),
                "avg_cpu_usage": cluster_data["cpu_usage"].mean(),
                "avg_memory_usage": cluster_data["memory_usage"].mean(),
            }

        return {
            "cluster_analysis": cluster_analysis,
            "agent_clusters": agent_performance.to_dict("records"),
        }

    def generate_performance_report(self, df: pd.DataFrame) -> Dict:
        """Generate a comprehensive performance report"""
        # Basic statistics
        total_tasks = len(df)
        success_rate = df["success"].mean()
        avg_execution_time = df["execution_time"].mean()

        # Agent performance breakdown
        agent_stats = (
            df.groupby("agent")
            .agg(
                {
                    "execution_time": ["mean", "std", "count"],
                    "success": "mean",
                    "cpu_usage": "mean",
                    "memory_usage": "mean",
                }
            )
            .round(3)
        )

        # Task type analysis
        task_stats = (
            df.groupby("task_type")
            .agg(
                {"execution_time": "mean", "success": "mean", "task_complexity": "mean"}
            )
            .round(3)
        )

        # Time-based analysis
        hourly_stats = (
            df.groupby("hour")
            .agg({"execution_time": "mean", "success": "mean"})
            .round(3)
        )

        return {
            "summary": {
                "total_tasks": total_tasks,
                "overall_success_rate": round(success_rate, 3),
                "average_execution_time": round(avg_execution_time, 2),
            },
            "agent_performance": agent_stats.to_dict(),
            "task_performance": task_stats.to_dict(),
            "hourly_patterns": hourly_stats.to_dict(),
            "generated_at": datetime.now().isoformat(),
        }


def main():
    """Command-line interface for the performance analyzer"""
    import argparse

    parser = argparse.ArgumentParser(description="Agent Performance Analyzer")
    parser.add_argument(
        "--workspace", "-w", default=os.getcwd(), help="Workspace root directory"
    )
    parser.add_argument(
        "command", choices=["predict", "train", "analyze"], help="Command to execute"
    )
    parser.add_argument("--cpu", type=float, help="CPU usage percentage")
    parser.add_argument("--memory", type=float, help="Memory usage percentage")
    parser.add_argument("--disk", type=float, default=0, help="Disk usage percentage")
    parser.add_argument("--processes", type=int, default=0, help="Process count")
    parser.add_argument(
        "--agent-count", type=int, default=1, help="Number of active agents"
    )
    parser.add_argument("--task-type", default="unknown", help="Task type")
    parser.add_argument(
        "--files", type=int, default=0, help="Number of files to process"
    )
    parser.add_argument("--issues", type=int, default=0, help="Number of issues found")

    args = parser.parse_args()

    analyzer = AgentPerformanceAnalyzer(args.workspace)

    if args.command == "predict":
        if not all([args.cpu, args.memory]):
            print("Error: --cpu and --memory are required for prediction")
            sys.exit(1)

        # Make predictions
        execution_time = analyzer.predict_execution_time(
            task_type=args.task_type,
            cpu_usage=args.cpu,
            memory_usage=args.memory,
            disk_usage=args.disk,
            process_count=args.processes,
            agent_count=args.agent_count,
            files_processed=args.files,
            issues_found=args.issues,
        )

        failure_prob = analyzer.predict_failure_probability(
            task_type=args.task_type,
            cpu_usage=args.cpu,
            memory_usage=args.memory,
            disk_usage=args.disk,
            process_count=args.processes,
            agent_count=args.agent_count,
            files_processed=args.files,
            issues_found=args.issues,
            duration_seconds=0,  # Not known for prediction
        )

        print(f"Predicted execution time: {execution_time:.2f} seconds")
        print(f"Failure probability: {failure_prob:.3f}")

    elif args.command == "train":
        print("Training models on real performance data...")
        # Import and run the training script
        try:
            import subprocess

            result = subprocess.run(
                [
                    sys.executable,
                    os.path.join(args.workspace, "train_ml_models.py"),
                    args.workspace,
                ],
                capture_output=True,
                text=True,
            )

            if result.returncode == 0:
                print("✓ Model training completed successfully")
                print(result.stdout)
            else:
                print("✗ Model training failed")
                print(result.stderr)
                sys.exit(1)

        except Exception as e:
            print(f"Error running training script: {e}")
            sys.exit(1)

    elif args.command == "analyze":
        print("Analyzing current performance data...")
        # Load and analyze data
        df = analyzer.load_performance_data(
            os.path.join(args.workspace, "agents", "performance_metrics.json")
        )

        if not df.empty:
            report = analyzer.generate_performance_report(df)
            print("\nPerformance Analysis Report:")
            print(f"Total tasks analyzed: {report['summary']['total_tasks']}")
            print(f"Success rate: {report['summary']['overall_success_rate']:.1%}")
            print(
                f"Average execution time: {report['summary']['average_execution_time']:.2f}s"
            )
        else:
            print("No performance data available for analysis")


if __name__ == "__main__":
    main()
