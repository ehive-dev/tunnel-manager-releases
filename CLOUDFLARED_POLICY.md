# cloudflared update policy

`cloudflared-policy.json` controls the cloudflared version approved for eHive
devices.

- `approvedVersion` must be an existing stable release in the official
  `cloudflare/cloudflared` GitHub repository.
- `minimumSecureVersion` is the lowest version considered secure.
- `mandatory: true` installs `approvedVersion` automatically on devices that
  run an older version.
- `mandatory: false` only reports the available update; the user starts it in
  TunnelManager.
- `sequence` must increase with every policy change.

TunnelManager ignores download URLs and checksums from this repository. It
resolves the selected version through the official Cloudflare GitHub API and
requires the SHA-256 digest published for the platform-specific asset. It never
downgrades an installed version.
