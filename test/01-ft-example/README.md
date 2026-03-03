# FT Test Example

This test harness demonstrates the integration of:
- **cert-manager**: Certificate and SSH key generation
- **ft-test-double-classical**: ProFTPD server in classical (pre-quantum) TLS mode
- **ft-test-double-pq**: ProFTPD server in post-quantum hybrid TLS mode
- **ft-test-client**: Automated testing framework running all scenario combinations

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  cert-manager                                               │
│  - Generates Root CA                                        │
│  - Generates server certificate signed by Root CA           │
│  - Generates client SSH key pairs (RSA + ED25519)           │
│  - Outputs to ./data/subjects/01-ft-test/                   │
└──────────────────────────┬──────────────────────────────────┘
                           │ certs + keys ready
              ┌────────────┴────────────┐
              ▼                         ▼
┌─────────────────────────┐  ┌──────────────────────────────┐
│  ft-test-double-classical│  │  ft-test-double-pq           │
│  Classical TLS mode      │  │  Post-Quantum Hybrid mode    │
│  - FT_TLS_MODE=classical │  │  - FT_TLS_MODE=pq-hybrid     │
│  - FT_SFTP_KEY_TYPE=rsa  │  │  - FT_SFTP_KEY_TYPE=ed25519  │
│  - Port 2121 (FTP/FTPES) │  │  - Port 3121 (FTP/FTPES)     │
│  - Port 2990 (FTPS impl) │  │  - Port 3990 (FTPS impl)     │
│  - Port 2222 (SFTP)      │  │  - Port 3222 (SFTP)          │
└─────────────────────────┘  └──────────────────────────────┘
              │                         │
              └────────────┬────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  ft-test-client                                             │
│  - Runs run-scenarios.sh                                    │
│  - Iterates all 10 combinations (server × protocol × key)   │
│  - Uses shunit2 scenarios from ft-scenarios.sh              │
│  - Reports pass/fail per combination                        │
└─────────────────────────────────────────────────────────────┘
```

## Scenario Combinations (10 total)

| # | Server              | Protocol       | Key Type | Notes                        |
|---|---------------------|----------------|----------|------------------------------|
| 1 | classical           | ftp            | —        | Plain FTP, no TLS            |
| 2 | classical           | ftps           | —        | Explicit TLS (AUTH TLS)      |
| 3 | classical           | ftps-implicit  | —        | Implicit TLS port 2990       |
| 4 | classical           | sftp           | rsa      | Password auth                |
| 5 | classical           | sftp           | ed25519  | Key-based auth (ED25519 key) |
| 6 | pq                  | ftp            | —        | Plain FTP, no TLS            |
| 7 | pq                  | ftps           | —        | Explicit TLS (PQ provider)   |
| 8 | pq                  | ftps-implicit  | —        | Implicit TLS port 3990 (PQ)  |
| 9 | pq                  | sftp           | rsa      | Password auth                |
|10 | pq                  | sftp           | ed25519  | Key-based auth (ED25519 key) |

Each combination runs two shunit2 scenarios:
- **Scenario 1**: Transfer round trip with checksum (upload + download + sha256 verify)
- **Scenario 2**: Get from read-only folder (secondary user downloads file uploaded by primary)

## Prerequisites

Build the required images:

```powershell
# Build cert-manager
cd c:\iwcd\7u-container-images\images\s\alpine\cert-manager
.\build-local.bat
cd ..\..\..\t\alpine\cert-manager
.\build-local.bat
cd ..\..\..\u\alpine\cert-manager
.\build-local.bat

# Build ft-test-double
cd c:\iwcd\7u-container-images\images\s\alpine\ft-test-double
.\build-local.bat
cd ..\..\..\t\alpine\ft-test-double
.\build-local.bat
cd ..\..\..\u\alpine\ft-test-double
.\build-local.bat

# Build ft-test-client
cd c:\iwcd\7u-container-images\images\s\alpine\ft-test-client
.\build-local.bat
cd ..\..\..\t\alpine\ft-test-client
.\build-local.bat
cd ..\..\..\u\alpine\ft-test-client
.\build-local.bat
```

## Running the Tests

```powershell
cd c:\iwcd\7u-container-images\test\01-ft-example

# Run all 10 scenario combinations (interactive, with pause at end)
.\run-tests.bat

# Or run directly with docker compose
docker compose up --build

# View logs
docker compose logs -f ft-test-client

# Stop and cleanup
docker compose down -v
```

## Test Execution Flow

1. **cert-manager** starts first and generates:
   - Root CA certificate (`01-ca-ft-test`)
   - Server certificate (`02-ft-server`) signed by Root CA — both RSA and ED25519
   - Client SSH key pairs (`03-ft-client-keys`) — RSA and ED25519
   - Outputs to `./data/subjects/01-ft-test/*/out/`

2. **ft-test-double-classical** and **ft-test-double-pq** start in parallel after cert-manager is healthy:
   - Decrypt the RSA private key for TLS/FTPS
   - Generate/configure SFTP host keys (RSA for classical, ED25519 for pq)
   - Install client public keys into each user's `~/.ssh/authorized_keys`
   - Set up user home directories
   - Start ProFTPD

3. **ft-test-client** waits for both servers to be healthy, then:
   - Runs `run-scenarios.sh` which iterates all 10 combinations
   - For each combination: sets `FTC_HOST`, `FTC_PORT`, `FTC_PROTOCOL`, `FTC_KEY_TYPE`
   - Executes `ft-scenarios.sh` (shunit2) for each combination
   - Reports pass/fail per combination and overall summary

## Certificate and Key Structure

```
./data/subjects/01-ft-test/
├── 01-ca-ft-test/              # Root CA
│   ├── set-env.sh
│   └── out/
│       ├── rsa/                # RSA CA artifacts
│       └── ed25519/            # ED25519 CA artifacts
│
├── 02-ft-server/               # Server certificate (SANs include both service names)
│   ├── set-env.sh
│   ├── csr.config
│   ├── cert-gen.config
│   └── out/
│       ├── rsa/                # RSA server cert + key
│       └── ed25519/            # ED25519 server cert + key
│
└── 03-ft-client-keys/          # Client SSH key pairs (generated by cert-manager)
    ├── rsa/
    │   ├── id_client           # RSA private key
    │   └── id_client.pub       # RSA public key (installed in authorized_keys)
    └── ed25519/
        ├── id_client           # ED25519 private key
        └── id_client.pub       # ED25519 public key (installed in authorized_keys)
```

## Post-Quantum Cryptography

The `ft-test-double-pq` service uses the Open Quantum Safe (OQS) provider:

```
OpenSSL Configuration: openssl-pq-hybrid.cnf
├── Provider: default + oqsprovider
├── Key Exchange: x25519_kyber768 (Classical + ML-KEM-768)
├── Authentication: RSA, ECDSA, ED25519
└── Protected against: Quantum computers
```

To verify OQS provider is active on the PQ server:

```powershell
docker compose exec ft-test-double-pq openssl list -providers
```

## Virtual Users

| User      | Password  | Access                                    |
|-----------|-----------|-------------------------------------------|
| ftuser01  | Manage01  | Read/write to `private/` and `shared/`   |
| ftuser02  | Manage01  | Read-only to `shared/`                   |

## Configuration Files

| File                              | Purpose                                      |
|-----------------------------------|----------------------------------------------|
| `config/proftpd.conf`             | ProFTPD config (FTP/FTPS/SFTP virtual hosts) |
| `config/openssl-classical.cnf`    | OpenSSL config for classical TLS             |
| `config/openssl-pq-hybrid.cnf`    | OpenSSL config for PQ hybrid TLS             |
| `scripts/cert-manager-entrypoint.sh` | Generates certs + client SSH keys         |
| `scripts/ft-test-double-entrypoint.sh` | Prepares and starts ProFTPD             |
| `scripts/run-scenarios.sh`        | Iterates all 10 scenario combinations        |

## Troubleshooting

### Certificates not generated
```powershell
docker compose logs cert-manager
docker compose exec cert-manager ls -la /mnt/data/certmgr/01-ft-test/
```

### Server fails to start
```powershell
docker compose logs ft-test-double-classical
docker compose logs ft-test-double-pq
```

### Tests fail
```powershell
docker compose logs ft-test-client
```

### Clean up generated certificates (force regeneration)
```powershell
docker compose down -v
# Remove generated cert files
Remove-Item -Recurse -Force .\data\subjects\01-ft-test\01-ca-ft-test\out
Remove-Item -Recurse -Force .\data\subjects\01-ft-test\02-ft-server\out
Remove-Item -Recurse -Force .\data\subjects\01-ft-test\03-ft-client-keys
docker compose up --build
```

## Security Notes

⚠️ **FOR TESTING ONLY**

- Passwords are hardcoded in configuration files
- Private key passphrase (`TestOnly123`) is exposed in environment variables
- Self-signed certificates are used
- TLS certificate validation is disabled on the client side

**DO NOT use this configuration in production environments.**

## License

Copyright IBM Corp. 2026 - 2026
SPDX-License-Identifier: Apache-2.0