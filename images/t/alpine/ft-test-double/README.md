# File Transfer Protocols Test Double

This image provides fundamental scripts to set up the ftp test double server.

This image defines the environment variable `FTD_DISABLE_SECURITY_DEFAULTS`, defaulted to `true` in this build. This means that the server is not supposed to create default security password and keys but expects them to be provided. This is intended behavior, user SHOULD prepare the keys and secrets upfront.

However, in case this is too cumbersome, set the variable on some other value at utilization time.

This server is expected to open FTP, FTP/S and SFTP ports, one for each protocol.
