🛡️ S3 Bucket Security Tester

A lightweight Bash script to audit Amazon S3 buckets for misconfigurations.
Supports scanning a single bucket or bulk checking from a file with multithreaded execution.

🔍 Features
Anonymous checks using AWS CLI (--no-sign-request)

Detects:
- Public access (listable)
- Write access (upload test)
- Delete access (clean removal)
- Bucket ACLs, policies, region, versioning
- Safe testing: never modifies or deletes existing files
- Summary report after scan
