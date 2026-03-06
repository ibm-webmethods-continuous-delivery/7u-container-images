# IWCD Containers Images Builder

This sandbox provides a quick and safe way to build all container images in this repository.
It includes:
- **Docker-in-Docker**: Build images inside a containerized environment
- **Trivy**: Security scanning for container images (vulnerabilities, misconfigurations)
- **Hadolint**: Dockerfile quality and best practices scanning
- **Dependency Resolution**: Automatically builds dependent images
- **Scan Results**: Persistent storage of scan results with multiple formats

## Quick Start

### Build All Images
```bash
# From Windows - build only
cd c:\iwcd\7u-container-images\.sbx\7u-ci-builder
build.bat

# Build with security scanning
build.bat --scan

# Or using docker compose directly
docker compose run --rm 7u-ci-builder
docker compose run --rm -e ENABLE_SCAN=true 7u-ci-builder
```

### Build Specific Image
```bash
# From Windows - builds the image and its dependencies
build.bat u/alpine/git-guardian
build.bat t/alpine/cert-manager
build.bat s/alpine/iwcd-aio-base

# Build with security scanning
build.bat u/alpine/git-guardian --scan
build.bat t/alpine/cert-manager -s

# Or using docker compose with environment variable
docker compose run --rm -e BUILD_TARGET=u/alpine/git-guardian 7u-ci-builder
docker compose run --rm -e BUILD_TARGET=u/alpine/git-guardian -e ENABLE_SCAN=true 7u-ci-builder
```

## Security Scanning

### Hadolint (Pre-Build)
Scans Dockerfiles for:
- Best practices violations
- Common mistakes
- Security issues
- Deprecated instructions

**Output:** `scan-results/<image-name>/<image-name>_hadolint.txt`

### Trivy (Post-Build)
Scans built images for:
- OS vulnerabilities (CVEs)
- Application dependencies vulnerabilities
- Misconfigurations
- Secrets
- Generates Software Bill of Materials (SBOM)

**Outputs:**
- `scan-results/<image-name>/<image-name>_trivy_<timestamp>.json` - Detailed JSON
- `scan-results/<image-name>/<image-name>_trivy_<timestamp>.txt` - Human-readable table
- `scan-results/<image-name>/<image-name>_trivy_<timestamp>.sarif` - SARIF format (CI/CD)
- `scan-results/<image-name>/<image-name>_trivy_<timestamp>_sbom.json` - CycloneDX SBOM
- `scan-results/<image-name>/<image-name>_trivy_<timestamp>_sbom_spdx.json` - SPDX SBOM
- `scan-results/<image-name>/<image-name>_trivy_<timestamp>_summary.txt` - Vulnerability summary

### Scan Results Classification
- 🔴 **CRITICAL**: Immediate action required
- 🟠 **HIGH**: Action recommended
- 🟡 **MEDIUM**: Review recommended
- 🟢 **LOW**: Minor issues
- ✅ **CLEAN**: No vulnerabilities found

### Interactive Mode (for debugging)
```bash
# Start container with shell access
docker compose up -d
docker exec -it 7u-ci-builder-7u-ci-builder-1 sh

# Inside container, you can:
cd /workspace/images/u/alpine/git-guardian
sh build-local.sh

# Or use the build script
BUILD_TARGET=t/alpine/cert-manager sh /workspace/.sbx/7u-ci-builder/build.sh
```

## How It Works

1. **Shell Scripts**: Each image directory now has a `build-local.sh` script (counterpart to `build-local.bat`)
2. **Dependency Resolution**: Shell scripts automatically check for and build dependent images
3. **Main Build Script**: `build.sh` orchestrates the build process
4. **Windows Wrapper**: `build.bat` provides easy access from Windows

## Image Dependencies

The build system follows this dependency chain:
- `s/*` (System/Base images) - No dependencies
- `t/*` (Tool images) - Depend on corresponding `s/*` images
- `u/*` (User images) - Depend on corresponding `t/*` images

Example: Building `u/alpine/cert-manager` will automatically:
1. Check if `cert-manager-t:alpine` exists
2. If not, build it (which checks for `cert-manager-s:alpine`)
3. Build `cert-manager-u:alpine`

## Environment Variables

- `BUILD_TARGET`: Specifies what to build
  - `all` (default): Build all images
  - `<path>`: Build specific image (e.g., `u/alpine/git-guardian`)

## Notes

- The Docker socket is mounted from the host, allowing the container to build images
- All builds happen inside the container for consistency and isolation
- Built images are available on the host Docker daemon
