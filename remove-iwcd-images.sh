#!/bin/bash
# Remove all Docker images prefixed with iwcd-
docker images --format "{{.Repository}}:{{.Tag}}" | grep '^iwcd-' | xargs -r docker rmi -f
