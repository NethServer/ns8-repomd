#!/bin/bash

#
# Copyright (C) 2021 Nethesis S.r.l.
# http://www.nethesis.it - nethserver@nethesis.it
#
# This script is part of NethServer.
#
# NethServer is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License,
# or any later version.
#
# NethServer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NethServer.  If not, see COPYING.
#

set -e

if ! buildah containers --format "{{.ContainerName}}" | grep -q repomd-builder; then
    echo "Pulling Python runtime and Skopeo..."
    buildah from --name repomd-builder -v "${PWD}:/usr/src:Z" docker.io/library/python:3.11-alpine
    buildah run repomd-builder sh <<EOF
python3 -mvenv /opt/pyenv --upgrade-deps
/opt/pyenv/bin/pip3 install semver==3.0.1 filetype PyYAML
apk add skopeo
EOF
fi

buildah run --workingdir /usr/src repomd-builder /opt/pyenv/bin/python3 createrepo.py
