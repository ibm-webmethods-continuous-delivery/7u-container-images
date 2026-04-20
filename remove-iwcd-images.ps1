# Remove all Docker images prefixed with iwcd-
docker images --format "{{.Repository}}:{{.Tag}}" |
    Where-Object { $_ -match '^iwcd-' } |
    ForEach-Object { docker rmi $_ -f }

# Made with Bob
