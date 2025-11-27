#!/usr/bin/env bash
set -e

if [ -z "$AZP_URL" ]; then
  echo "Error: AZP_URL is not set"
  exit 1
fi

if [ -z "$AZP_TOKEN" ]; then
  echo "Error: AZP_TOKEN is not set"
  exit 1
fi

export AZP_POOL=${AZP_POOL:-Default}
export AZP_AGENT_NAME=${AZP_AGENT_NAME:-$(hostname)}

cd /azp

cleanup() {
  echo "Cleanup. Removing Azure DevOps agent..."
  ./config.sh remove --unattended --auth pat --token "$AZP_TOKEN" || true
  exit 0
}

trap 'cleanup' INT TERM

echo "Configuring Azure DevOps agent..."

cat ./config.sh

./config.sh --unattended \
  --agent "$AZP_AGENT_NAME" \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "$AZP_POOL" \
  --acceptTeeEula & wait $!

echo "Starting Azure DevOps agent..."
./run.sh & wait $!
