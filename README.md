# tunnel-manager Releases

Dieses Repository enthaelt oeffentliche Release-Pakete fuer den Cloudflare Tunnel Manager.

## Schnellstart

Stable installieren oder aktualisieren:

```bash
curl -fsSL https://raw.githubusercontent.com/ehive-dev/tunnel-manager-releases/main/install.sh | sudo bash
```

Pre-Release installieren:

```bash
curl -fsSL https://raw.githubusercontent.com/ehive-dev/tunnel-manager-releases/main/install.sh | sudo bash -s -- --pre
```

Bestimmte Version installieren:

```bash
curl -fsSL https://raw.githubusercontent.com/ehive-dev/tunnel-manager-releases/main/install.sh | sudo bash -s -- --tag v0.8.1
```

## Service

```bash
systemctl status tunnel-manager --no-pager
journalctl -u tunnel-manager -f
```

Health-Check lokal:

```bash
curl http://127.0.0.1:3005/healthz
```

## Lizenz

Die Nutzung ist fuer private und nicht-kommerzielle Zwecke erlaubt. Kommerzielle Nutzung benoetigt eine vorherige schriftliche Zustimmung von ehive. Siehe `LICENSE.txt` und `THIRD_PARTY_NOTICES.txt`.
