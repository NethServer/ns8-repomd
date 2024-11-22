#!/bin/bash

#
# Copyright (C) 2023 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

#
# Read from standard input a list of image references. Images hosted on
# docker.io are copied to ghcr.io/nethserver mirror. Configure
# REGISTRY_AUTH_FILE as documented for `podman login`.
#

if [ ! -f "${REGISTRY_AUTH_FILE:?missing configuration}" ]; then
    echo '{}' > "${REGISTRY_AUTH_FILE}"
fi

jq -r '.[].versions[].labels."org.nethserver.images"' | \
tr -s '[:blank:]' $'\n' | \
sed -En '\|^docker\.io| {s|^docker.io/([^/]+):|docker.io/library/\1:|;p}' | \
sort | \
uniq | \
exec podman run --init --rm -i --entrypoint=[] --volume="${REGISTRY_AUTH_FILE}":/tmp/auth.json:z \
docker://quay.io/skopeo/stable:latest \
bash -c ' while read -r image; do
    [[ -z "${image}" ]] && continue
    # Skip if image already exists
    echo -n "${image}"
    if ! skopeo inspect "docker://ghcr.io/nethserver/${image}" &>/dev/null ; then
        echo " uploading..."
        skopeo copy "docker://${image}" "docker://ghcr.io/nethserver/${image}"
    else
        echo " found."
    fi
done'
