#!/usr/bin/env bash
set -Eeuo pipefail

git clone https://github.com/Blobby-Boi/BlobeVM
cd BlobeVM
pip install textual
python3 installer.py
if [[ ! -s options.json ]]; then
    echo "Installation options were not saved; select Install NOW in the installer and try again." >&2
    exit 1
fi
docker build -t blobevm . --no-cache
cd ..

sudo apt update
sudo apt install -y jq

mkdir -p Save
cp -r BlobeVM/root/config/* Save

json_file="BlobeVM/options.json"
docker rm -f BlobeVM >/dev/null 2>&1 || true

if jq -e ".enablekvm == true" "$json_file" >/dev/null && [[ -e /dev/kvm ]]; then
    docker run -d --name=BlobeVM -e PUID=1000 -e PGID=1000 --device=/dev/kvm --security-opt seccomp=unconfined -e TZ=Etc/UTC -e SUBFOLDER=/ -e TITLE=BlobeVM -p 0.0.0.0:3000:3000 --shm-size="2gb" -v "$(pwd)/Save:/config" --restart unless-stopped blobevm
else
    if jq -e ".enablekvm == true" "$json_file" >/dev/null; then
        echo "KVM is enabled in the installer settings, but /dev/kvm is unavailable; starting without hardware acceleration."
    fi
    docker run -d --name=BlobeVM -e PUID=1000 -e PGID=1000 --security-opt seccomp=unconfined -e TZ=Etc/UTC -e SUBFOLDER=/ -e TITLE=BlobeVM -p 0.0.0.0:3000:3000 --shm-size="2gb" -v "$(pwd)/Save:/config" --restart unless-stopped blobevm
fi

for attempt in {1..30}; do
    if curl --silent --output /dev/null --max-time 2 http://127.0.0.1:3000/; then
        echo "BlobeVM is ready at http://localhost:3000"
        echo "In Codespaces, open the Ports tab and open port 3000."
        exit 0
    fi
    if [[ "$(docker inspect --format='{{.State.Running}}' BlobeVM)" != "true" ]]; then
        echo "BlobeVM stopped during startup. Recent container logs:" >&2
        docker logs --tail 80 BlobeVM >&2
        exit 1
    fi
    sleep 2
done

echo "BlobeVM is running, but port 3000 did not respond. Recent container logs:" >&2
docker logs --tail 80 BlobeVM >&2
exit 1
