#!/usr/bin/env python3
"""
ML Model Training Script for Agent Performance Analysis

This script trains machine learning models on real agent performance data
to predict execution times and failure probabilities.
"""

import json
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier
from sklearn.metrics import mean_squared_error, accuracy_score, classification_report
from sklearn.preprocessing import StandardScaler, LabelEncoder
import joblib
import os
import sys
from datetime import datetime
import logging

# Set up logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class AgentPerformanceTrainer:
    def __init__(self, workspace_root):
        self.workspace_root = workspace_root
        self.models_dir = os.path.join(workspace_root, "models")
        self.data_dir = os.path.join(workspace_root, "agents")

        # Create models directory if it doesn't exist
        os.makedirs(self.models_dir, exist_ok=True)

        # File paths
        self.performance_log = os.path.join(self.data_dir, "performance_metrics.json")
        self.task_history = os.path.join(self.data_dir, "task_execution_history.json")
        self.agent_status = os.path.join(workspace_root, "config", "agent_status.json")

    def load_performance_data(self):
        """Load performance metrics data"""
        try:
            with open(self.performance_log, "r") as f:
                data = json.load(f)
            return data.get("metrics", [])
        except (FileNotFoundError, json.JSONDecodeError) as e:
            logger.warning(f"Could not load performance data: {e}")
            return []

    def load_task_execution_data(self):
        """Load task execution history data"""
        try:
            with open(self.task_history, "r") as f:
                data = json.load(f)
            return data.get("execution_history", [])
        except (FileNotFoundError, json.JSONDecodeError) as e:
            logger.warning(f"Could not load task execution data: {e}")
            return []

    def load_agent_status_data(self):
        """Load agent status data"""
        try:
            with open(self.agent_status, "r") as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            logger.warning(f"Could not load agent status data: {e}")
            return {"agents": {}}

    def create_training_dataset(self):
        """Create a comprehensive training dataset from all available data"""
        logger.info("Creating training dataset...")

        # Load all data sources
        performance_data = self.load_performance_data()
        task_data = self.load_task_execution_data()
        agent_data = self.load_agent_status_data()

        if not performance_data:
            logger.error("No performance data available for training")
            return None

        if not task_data:
            logger.error("No task execution data available for training")
            return None

        # Convert performance data to DataFrame
        perf_df = pd.DataFrame(performance_data)

        # Convert timestamps - handle both string and numeric timestamps
        def parse_timestamp(ts):
            try:
                # Try as string first
                if isinstance(ts, str):
                    return pd.to_datetime(int(ts), unit="s")
                else:
                    return pd.to_datetime(ts, unit="s")
            except (ValueError, TypeError):
                logger.warning(f"Could not parse timestamp: {ts}")
                return pd.NaT

        perf_df["timestamp"] = perf_df["timestamp"].apply(parse_timestamp)
        perf_df = perf_df.dropna(subset=["timestamp"])
        perf_df = perf_df.sort_values("timestamp")

        # Convert numeric columns
        numeric_cols = [
            "cpu_usage",
            "memory_usage",
            "disk_usage",
            "process_count",
            "agent_count",
        ]
        for col in numeric_cols:
            perf_df[col] = pd.to_numeric(perf_df[col], errors="coerce")

        perf_df = perf_df.dropna()

        logger.info(f"Loaded {len(perf_df)} performance metrics")

        # Convert task data to DataFrame
        task_df = pd.DataFrame(task_data)

        # Create features from performance data
        features = []

        for _, task in task_df.iterrows():
            try:
                # Parse task timestamps
                task_start = pd.to_datetime(task["started"], unit="s")
                task_end = pd.to_datetime(task["completed"], unit="s")

                # Get performance metrics during task execution
                task_perf = perf_df[
                    (perf_df["timestamp"] >= task_start)
                    & (perf_df["timestamp"] <= task_end)
                ]

                # If no metrics during exact task period, get closest metrics
                if len(task_perf) == 0:
                    # Find metrics closest to task execution time
                    time_diff = (perf_df["timestamp"] - task_start).abs()
                    closest_idx = time_diff.idxmin()
                    task_perf = perf_df.loc[[closest_idx]]

                if len(task_perf) > 0:
                    # Aggregate performance metrics during task
                    avg_cpu = task_perf["cpu_usage"].mean()
                    avg_memory = task_perf["memory_usage"].mean()
                    avg_disk = task_perf["disk_usage"].mean()
                    avg_processes = task_perf["process_count"].mean()
                    avg_agents = task_perf["agent_count"].mean()

                    # Task features
                    task_type = task.get("type", "unknown")
                    files_processed = task.get("files_processed", 0)
                    issues_found = task.get("issues_found", 0)
                    duration = task["duration_seconds"]

                    # Determine if task failed
                    result = task.get("result", "success")
                    failed = 1 if result != "success" else 0

                    features.append(
                        {
                            "cpu_usage": avg_cpu,
                            "memory_usage": avg_memory,
                            "disk_usage": avg_disk,
                            "process_count": avg_processes,
                            "agent_count": avg_agents,
                            "task_type": task_type,
                            "files_processed": files_processed,
                            "issues_found": issues_found,
                            "duration_seconds": duration,
                            "failed": failed,
                        }
                    )
            except Exception as e:
                logger.warning(
                    f"Error processing task {task.get('task_id', 'unknown')}: {e}"
                )
                continue

        if not features:
            logger.error("No training features could be created")
            return None

        df = pd.DataFrame(features)

        # Handle missing values
        df = df.fillna(0)

        # Encode categorical variables
        le = LabelEncoder()
        df["task_type_encoded"] = le.fit_transform(df["task_type"])

        # Save label encoder for later use
        joblib.dump(le, os.path.join(self.models_dir, "task_type_encoder.pkl"))

        logger.info(f"Created training dataset with {len(df)} samples")
        logger.info(f"Features: {list(df.columns)}")
        logger.info(f"Task types: {df['task_type'].value_counts().to_dict()}")

        return df

    def train_execution_time_model(self, df):
        """Train model to predict execution time"""
        logger.info("Training execution time prediction model...")

        # Features for execution time prediction
        feature_cols = [
            "cpu_usage",
            "memory_usage",
            "disk_usage",
            "process_count",
            "agent_count",
            "task_type_encoded",
            "files_processed",
            "issues_found",
        ]

        X = df[feature_cols]
        y = df["duration_seconds"]

        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        # Scale features
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train.values)  # Convert to numpy array
        X_test_scaled = scaler.transform(X_test.values)

        # Train model
        model = RandomForestRegressor(n_estimators=100, random_state=42)
        model.fit(X_train_scaled, y_train)

        # Evaluate
        y_pred = model.predict(X_test_scaled)
        mse = mean_squared_error(y_test, y_pred)
        rmse = np.sqrt(mse)

        logger.info(".2f")
        logger.info(".2f")

        # Save model and scaler
        joblib.dump(model, os.path.join(self.models_dir, "execution_time_model.pkl"))
        joblib.dump(scaler, os.path.join(self.models_dir, "execution_time_scaler.pkl"))

        return model, scaler, rmse

    def train_failure_probability_model(self, df):
        """Train model to predict failure probability"""
        logger.info("Training failure probability prediction model...")

        # Features for failure prediction
        feature_cols = [
            "cpu_usage",
            "memory_usage",
            "disk_usage",
            "process_count",
            "agent_count",
            "task_type_encoded",
            "files_processed",
            "issues_found",
            "duration_seconds",
        ]

        X = df[feature_cols]
        y = df["failed"]

        # Check if we have enough failure samples
        failure_rate = y.mean()
        logger.info(".3f")

        if failure_rate == 0:
            logger.warning("No failure samples found, creating simple baseline model")

            # Create a simple model that always predicts 0 (no failure)
            from sklearn.dummy import DummyClassifier

            model = DummyClassifier(strategy="constant", constant=0)
            scaler = StandardScaler()

            # Fit scaler on the data
            scaler.fit(X.values)  # Fit on numpy array

            # Fit the model
            model.fit(scaler.transform(X.values), y)
            accuracy = (
                1.0  # Since all tasks succeeded, predicting success gives 100% accuracy
            )
        else:
            # Split data
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42
            )

            # Scale features
            scaler = StandardScaler()
            X_train_scaled = scaler.fit_transform(
                X_train.values
            )  # Convert to numpy array
            X_test_scaled = scaler.transform(X_test.values)

            # Train model
            model = RandomForestClassifier(n_estimators=100, random_state=42)
            model.fit(X_train_scaled, y_train)

            # Evaluate
            y_pred = model.predict(X_test_scaled)
            accuracy = accuracy_score(y_test, y_pred)

            logger.info(".3f")
            logger.info("Classification Report:")
            logger.info("\n" + classification_report(y_test, y_pred))

        # Save model and scaler
        joblib.dump(
            model, os.path.join(self.models_dir, "failure_probability_model.pkl")
        )
        joblib.dump(
            scaler, os.path.join(self.models_dir, "failure_probability_scaler.pkl")
        )

        return model, scaler, accuracy

    def train_models(self):
        """Main training function"""
        logger.info("Starting ML model training...")

        # Create training dataset
        df = self.create_training_dataset()
        if df is None or len(df) < 2:
            logger.error("Insufficient data for training (need at least 2 samples)")
            return False

        logger.info(f"Training dataset shape: {df.shape}")
        logger.info(f"Sample of data:\n{df.head()}")

        # Train execution time model
        try:
            time_model, time_scaler, time_rmse = self.train_execution_time_model(df)
            logger.info("✓ Execution time model trained successfully")
        except Exception as e:
            logger.error(f"Failed to train execution time model: {e}")
            return False

        # Train failure probability model
        try:
            failure_model, failure_scaler, failure_accuracy = (
                self.train_failure_probability_model(df)
            )
            logger.info("✓ Failure probability model trained successfully")
        except Exception as e:
            logger.error(f"Failed to train failure probability model: {e}")
            return False

        # Save training metadata
        metadata = {
            "training_date": datetime.now().isoformat(),
            "dataset_size": len(df),
            "features": list(df.columns),
            "execution_time_rmse": time_rmse,
            "failure_accuracy": failure_accuracy,
            "data_sources": {
                "performance_metrics": self.performance_log,
                "task_history": self.task_history,
                "agent_status": self.agent_status,
            },
        }

        with open(os.path.join(self.models_dir, "training_metadata.json"), "w") as f:
            json.dump(metadata, f, indent=2)

        logger.info("✓ All models trained and saved successfully")
        logger.info(f"✓ Models saved to: {self.models_dir}")
        logger.info(".2f")
        logger.info(".3f")

        return True


def main():
    """Main entry point"""
    if len(sys.argv) != 2:
        print("Usage: python train_ml_models.py <workspace_root>")
        sys.exit(1)

    workspace_root = sys.argv[1]

    if not os.path.exists(workspace_root):
        print(f"Error: Workspace root does not exist: {workspace_root}")
        sys.exit(1)

    trainer = AgentPerformanceTrainer(workspace_root)

    if trainer.train_models():
        print("✓ ML model training completed successfully")
        sys.exit(0)
    else:
        print("✗ ML model training failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
