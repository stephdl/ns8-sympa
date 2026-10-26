#!/bin/bash

#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Send a Sympa command by mail to the mail module on this node
mto=${1:?missing mto}
mfrom=${2:?missing mfrom}
command=${3:?missing command}

curl -s --upload-file - --crlf \
    --mail-from "${mfrom}" \
    --mail-rcpt "${mto}" \
    "smtp://127.0.0.1:25/${mfrom/#*@/}" <<EOF
From: <${mfrom}>
To: <${mto}>
Subject: ${command}
Message-ID: <$(uuidgen)@${mfrom/#*@/}>
Date: $(date -R)
MIME-Version: 1.0
Content-Type: text/plain; charset="UTF-8"

${command}
EOF
