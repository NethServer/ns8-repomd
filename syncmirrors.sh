#!/bin/bash

#
# Copyright (C) 2024 Nethesis S.r.l.
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
podman run --init --rm -i --entrypoint=[] --volume="${REGISTRY_AUTH_FILE}":/tmp/auth.json:z \
docker://quay.io/skopeo/stable:latest \
bash -c '
declare -a failed_uploads
while read -r image; do
    [[ -z "${image}" ]] && continue
    # Skip if image already exists
    echo -n "${image}" 1>&2
    if ! skopeo inspect "docker://ghcr.io/nethserver/${image}" &>/dev/null ; then
        echo " uploading..." 1>&2
        skopeo copy "docker://${image}" "docker://ghcr.io/nethserver/${image}" 1>&2 || {
            failed_uploads+=("${image}")
        }
    else
        echo " found." 1>&2
    fi
done
if [[ ${#failed_uploads[@]} -gt 0 ]]; then
    echo "ERROR: skopeo copy failed ${#failed_uploads[@]} time(s)" 1>&2
    printf "\n### Sync registry mirrors failed\n\n"
    printf "Check the package settings of the following ghcr.io/nethserver items:\n\n"
    printf "* %s\n" "${failed_uploads[@]}"
    printf "\nGrant them write access for repository ns8-repomd.\n"
    exit 1
else
    printf "\n### Uploads ok\n\n"
fi
'
