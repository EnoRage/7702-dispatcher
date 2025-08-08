#!/bin/bash

echo "🚀 Starting 7702 Dispatcher Demo..."
echo ""

# Function to cleanup background processes
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    if [ ! -z "$ANVIL_PID" ]; then
        kill $ANVIL_PID 2>/dev/null
        echo "✅ Anvil stopped"
    fi
    exit 0
}

# Set up cleanup on script exit
trap cleanup EXIT

# Check if Anvil is already running
if curl -s http://127.0.0.1:8545 > /dev/null 2>&1; then
    echo "✅ Anvil is already running"
else
    # Start Anvil in background with optimized settings for faster execution
    echo "⛓️  Starting Anvil..."
    anvil --chain-id 31337 --gas-limit 30000000 --hardfork prague --block-time 1 --gas-price 1000000000 &
    ANVIL_PID=$!

    # Wait for Anvil to start
    echo "⏳ Waiting for Anvil to start..."
    sleep 3

    # Check if Anvil is running
    if ! curl -s http://127.0.0.1:8545 > /dev/null; then
        echo "❌ Failed to start Anvil"
        exit 1
    fi

    echo "✅ Anvil started successfully"
fi

echo ""

# Run the demo script from the project root
echo "📜 Running 7702 Dispatcher Demo..."
cd /home/enormousrage/repos/7702-dispatcher
forge script demo/script/DeployDemo.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --non-interactive --gas-price 1000000000 -- --hardfork prague

echo ""
echo "🎉 Demo completed!"
echo ""
echo "Press Ctrl+C to stop Anvil and exit"
echo ""

# Keep the script running so Anvil stays alive (if we started it)
if [ ! -z "$ANVIL_PID" ]; then
    wait $ANVIL_PID
else
    echo "💡 Anvil was already running, press Ctrl+C to exit"
    while true; do
        sleep 1
    done
fi
