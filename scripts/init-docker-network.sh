#!/bin/bash

echo "Initializing Docker Network: devsecops-net"

if docker network inspect devsecops-net >/dev/null 2>&1; then
  echo "Docker network 'devsecops-net' already exists."
else
  docker network create devsecops-net
  echo "Docker network 'devsecops-net' created."
fi
