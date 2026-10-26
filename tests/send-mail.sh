#!/bin/bash

#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

# Send a message to the mail module on this node, the body defaults to the subject
mto=${1:?missing mto}
mfrom=${2:?missing mfrom}
subject=${3:?missing subject}
body=${4:-${subject}}

curl -s --upload-file - --crlf \
    --mail-from "${mfrom}" \
    --mail-rcpt "${mto}" \
    "smtp://127.0.0.1:25/${mfrom/#*@/}" <<EOF
From: <${mfrom}>
To: <${mto}>
Subject: ${subject}
Message-ID: <$(uuidgen)@${mfrom/#*@/}>
Date: $(date -R)
MIME-Version: 1.0
Content-Type: text/plain; charset="UTF-8"

${body}
EOF
