FROM swift:5.9

WORKDIR /app

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the current directory contents into the container
COPY . .

# Build the application
RUN swift build

# Set the command to run when the container starts
CMD ["swift", "run", "MomentumFinance"]

# Expose port if needed for web interface
# EXPOSE 8080
