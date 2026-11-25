#!/usr/bin/env bash
# On an ARM64 Debian test host: sudo bash tests/installer-defaults.sh OLD.deb NEW.deb
set -euo pipefail
[[ $EUID -eq 0 && $# -eq 2 ]] || { echo "Expected root, 0.9.18.deb and 0.9.28.deb" >&2; exit 2; }
old=$(realpath "$1")
new=$(realpath "$2")
[[ $(dpkg-deb -f "$old" Version) == 0.9.18 && $(dpkg-deb -f "$new" Version) == 0.9.28 ]]
if [[ ${TUNNEL_INSTALL_TEST_NS:-0} != 1 ]]; then
  exec unshare --net env TUNNEL_INSTALL_TEST_NS=1 bash "$0" "$old" "$new"
fi
installer=$(realpath "$(dirname "$0")/../install.sh")
fixture=$(mktemp -d)
export fixture EHIVE_RELEASE_ACCEPTANCE=1
trap 'rm -rf -- "$fixture"' EXIT
root="$fixture/root"
mkdir -p "$fixture/bin" "$root"/{bin,dev,tmp,etc/default,etc/tunnel-manager,var/lib/dpkg/updates,var/lib/tunnel-manager}
touch "$root/dev/null"
# Run package scripts inside a disposable dpkg root, with no service manager or network.
cp -L /bin/sh "$root/bin/sh"
for program in /bin/sh /usr/bin/{install,chmod,touch,mktemp,rm,dpkg,dpkg-query}; do
  cp -L --parents "$program" "$root"
  while read -r library; do cp -L --parents "$library" "$root"; done < <(
    ldd "$program" | awk '$2=="=>" {print $3} $1~/^\// {print $1}'
  )
done
for package in smarthub ca-certificates curl lrzsz caddy libpam0g; do
  dpkg-query -s "$package"
  echo
done > "$root/var/lib/dpkg/status"
cat > "$fixture/bin/dpkg" <<'SH'
#!/bin/sh
set -eu
if [ -e "$fixture/fail-once" ]; then
  case " $* " in *' --install '*) rm "$fixture/fail-once"; exit 1;; esac
fi
exec /usr/bin/dpkg --root="$fixture/root" --log="$fixture/dpkg.log" \
  --path-exclude='/opt/*' --force-confdef,confold "$@"
SH
cat > "$fixture/bin/dpkg-query" <<'SH'
#!/bin/sh
exec /usr/bin/dpkg-query --admindir="$fixture/root/var/lib/dpkg" "$@"
SH
cat > "$fixture/bin/curl" <<'SH'
#!/bin/sh
set -eu
case "$1" in
  -fsIL) exit 0;;
  -fL)
    while [ "$1" != -o ]; do shift; done
    cp "$TEST_ASSET" "$2";;
  -fsS) [ "$2" = 'http://127.0.0.1:3005/healthz' ];;
  *) exit 2;;
esac
SH
cat > "$fixture/bin/apt-get" <<'SH'
#!/bin/sh
case "$*" in
  'update -y') exit 0;;
  '-o Dpkg::Options::=--force-confold --no-remove -f install -y') touch "$fixture/repaired";;
  *) exit 2;;
esac
SH
printf '%s\n' '#!/bin/sh' 'echo "$*" >> "$fixture/services"' > "$fixture/bin/systemctl"
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH" TEST_ASSET="$new"
config="$root/etc/default/tunnel-manager"
env_file="$root/etc/tunnel-manager/.env"
state="$root/var/lib/tunnel-manager/fixture.state"
printf 'FIXTURE_ID=existing-device\n' > "$env_file"
chmod 600 "$env_file"
echo existing-state > "$state"
dpkg-deb --fsys-tarfile "$new" | tar -xOf - ./etc/default/tunnel-manager > "$fixture/expected"
dpkg --install "$old" </dev/null > "$fixture/old.log" 2>&1 || { cat "$fixture/old.log"; exit 1; }
[[ $(dpkg-query -W -f='${Status}' tunnel-manager) == 'install ok installed' ]]

run_install() {
  if ! bash "$installer" --tag v0.9.28 </dev/null > "$fixture/install.log" 2>&1; then
    cat "$fixture/install.log" >&2; exit 1
  fi
  cmp "$fixture/expected" "$config"
  grep -Fxq FIXTURE_ID=existing-device "$env_file"
  [[ $(stat -c %a "$env_file") == 600 ]]
  grep -Fxq existing-state "$state"
  [[ $(dpkg-query -W -f='${Status} ${Version}' tunnel-manager) == 'install ok installed 0.9.28' ]]
  echo "PASS $1"
}
echo HOST=0.0.0.0 > "$config"
run_install '0.9.18 to 0.9.28 with local startup settings'
echo PORT=3100 > "$config"
run_install 'same version with modified settings'
rm "$config"
run_install 'same version with missing settings'
echo PORT=3200 > "$config"
touch "$fixture/fail-once"
run_install 'retry after dependency repair'
test -e "$fixture/repaired"

# Assets with mismatching metadata are rejected before stopping the service.
: > "$fixture/services"
export TEST_ASSET="$old"
if bash "$installer" --tag v0.9.28 </dev/null > "$fixture/reject.log" 2>&1; then exit 1; fi
grep -q 'Paketname, Architektur oder Version' "$fixture/reject.log"
test ! -s "$fixture/services"
echo 'PASS mismatched version rejected before service stop'

# An additional conffile must never silently replace the device registration.
future="$fixture/future"
mkdir -p "$future"/{DEBIAN,etc/default,etc/tunnel-manager}
chmod 0755 "$future/DEBIAN"
printf '%s\n' 'Package: tunnel-manager' 'Version: 0.9.29' 'Architecture: arm64' \
  'Maintainer: Fixture <test@example.invalid>' 'Description: installer regression fixture' > "$future/DEBIAN/control"
printf '%s\n' /etc/default/tunnel-manager /etc/tunnel-manager/.env > "$future/DEBIAN/conffiles"
echo PORT=3005 > "$future/etc/default/tunnel-manager"
echo FIXTURE_ID=package > "$future/etc/tunnel-manager/.env"
export TEST_ASSET="$fixture/future.deb"
dpkg-deb --build "$future" "$TEST_ASSET" >/dev/null
bash "$installer" --tag v0.9.29 </dev/null > "$fixture/future.log" 2>&1 || { cat "$fixture/future.log"; exit 1; }
grep -Fxq FIXTURE_ID=existing-device "$env_file"
echo 'PASS extra local conffile preserved'
