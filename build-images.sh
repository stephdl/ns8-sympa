#!/bin/bash

#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Terminate on error
set -e

# Third-party images pulled at runtime, pinned for Renovate
postgres_image="docker.io/postgres:18.6-alpine"

# Prepare variables for later use
images=()
# The image will be pushed to GitHub container registry
repobase="${REPOBASE:-ghcr.io/stephdl}"
# Configure the image name
reponame="sympa"

#
# Sympa application image: Sympa, Postfix and nginx from Rocky Linux + EPEL
#
buildah bud -f sympa/Containerfile -t "${repobase}/${reponame}-app" sympa
images+=("${repobase}/${reponame}-app")

# Create a new empty container image
container=$(buildah from scratch)

# Reuse existing nodebuilder-sympa container, to speed up builds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-sympa; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-sympa -v "${PWD}:/usr/src:Z" docker.io/library/node:lts
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-sympa \
    sh -c "corepack enable && yarn install && yarn build"

# Add imageroot directory to the container image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
# Two TCP ports: web (Traefik backend) and SMTP (inbound from the mail module)
buildah config --entrypoint=/ \
    --label="org.nethserver.authorizations=traefik@node:routeadm cluster:accountconsumer mail@any:mailadm,mailaddressadm" \
    --label="org.nethserver.tcp-ports-demand=2" \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.min-core=3.20.1" \
    --label="org.nethserver.volumes=sympa-data" \
    --label="org.nethserver.images=${postgres_image} ${repobase}/${reponame}-app:${IMAGETAG:-latest}" \
    "${container}"
# Commit the image
buildah commit "${container}" "${repobase}/${reponame}"

# Append the image URL to the images array
images+=("${repobase}/${reponame}")

#
# Setup CI when pushing to Github.
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "images=%s\n" "${images[*],,}" >> "${GITHUB_OUTPUT}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
