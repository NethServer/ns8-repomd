#!/bin/bash

#
# Copyright (C) 2024 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

set -e

#
# Read from standard input a list of image references. Images hosted on
# docker.io and quay.io are copied to ghcr.io/nethserver mirror. Configure
# REGISTRY_AUTH_FILE as documented for `podman login`.
#

if [ ! -f "${REGISTRY_AUTH_FILE:?missing configuration}" ]; then
    echo '{}' > "${REGISTRY_AUTH_FILE}"
fi

jq -r '.[].versions[].labels."org.nethserver.images"' | \
tr -s '[:blank:]' $'\n' | \
sed -En -e 's|^docker\.io/([^/]+):|docker.io/library/\1:|' -e '\#^(docker|quay)\.io/#p' | \
sort | \
uniq | \
podman run --init --rm -i --entrypoint=[] --volume="${REGISTRY_AUTH_FILE}":/tmp/auth.json:z \
docker://quay.io/skopeo/stable:v1.22.3 \
bash -c '
declare -a failed_uploads rows
declare -i found=0 uploaded=0
while read -r image; do
    [[ -z "${image}" ]] && continue
    # Skip if image already exists
    echo -n "${image}" 1>&2
    if ! skopeo inspect "docker://ghcr.io/nethserver/${image}" &>/dev/null ; then
        echo " uploading..." 1>&2
        if skopeo copy "docker://${image}" "docker://ghcr.io/nethserver/${image}" 1>&2 ; then
            status="uploaded"
            uploaded+=1
        else
            status="**failed**"
            failed_uploads+=("${image}")
        fi
    else
        echo " found." 1>&2
        status="found"
        found+=1
    fi
    rows+=("| ${image%:*} | ${image##*:} | ${status} |")
done
if [[ ${#failed_uploads[@]} -gt 0 ]]; then
    echo "ERROR: skopeo copy failed ${#failed_uploads[@]} time(s)" 1>&2
    printf "\n### Sync registry mirrors failed\n\n"
    printf "Check the package settings of the following ghcr.io/nethserver items:\n\n"
    printf "* %s\n" "${failed_uploads[@]}"
    printf "\nGrant them write access for repository ns8-repomd.\n"
else
    printf "\n### Sync registry mirrors ok\n"
fi
printf "\nMirror images: %d found, %d uploaded, %d failed.\n\n" "${found}" "${uploaded}" "${#failed_uploads[@]}"
printf "| Image | Version | Status |\n"
printf "|---|---|---|\n"
printf "%s\n" "${rows[@]}"
[[ ${#failed_uploads[@]} -eq 0 ]]
'
