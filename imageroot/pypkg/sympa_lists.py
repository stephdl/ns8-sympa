#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

#
# Sympa lists, read from the database and changed with the sympa CLI
#

import os
import re
import subprocess
import tempfile
from xml.sax.saxutils import escape

LIST_TYPES = [
    "discussion_list",
    "news-letter",
    "html-news-letter",
    "hotline",
    "private_working_group",
    "confidential",
    "public_web_forum",
]

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")


def _podman(*args, stdin=None):
    return subprocess.run(["podman", *args], input=stdin, capture_output=True, text=True)


def sympa_cli(*args, stdin=None):
    """Run the sympa command as the sympa user. Returns the CompletedProcess."""
    return _podman("exec", "-i", "sympa-app", "runuser", "-u", "sympa", "--", "sympa", *args, stdin=stdin)


def psql(query):
    proc = _podman("exec", "postgresql-app", "psql", "-U", "sympa", "-d", "sympa", "-At", "-F", "\t", "-c", query)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    return [line.split("\t") for line in proc.stdout.splitlines() if line]


def _list_config_values(name, keys):
    """Read some top level parameters of a list config file"""
    proc = _podman("exec", "sympa-app", "cat", f"/var/lib/sympa/list_data/{name}/config")
    values = {}
    if proc.returncode != 0:
        return values
    for line in proc.stdout.splitlines():
        key, _, value = line.partition(" ")
        if key in keys and key not in values:
            values[key] = value.strip()
    return values


def get_lists(domain):
    """Lists of the robot, with subject, status and subscribers"""
    lists = []
    # total_list is a cache Sympa fills later: count the subscribers instead
    rows = psql("SELECT l.name_list, l.status_list, COUNT(s.user_subscriber) FROM list_table l "
                "LEFT JOIN subscriber_table s ON s.list_subscriber = l.name_list AND s.robot_subscriber = l.robot_list "
                f"WHERE l.robot_list = '{domain}' GROUP BY l.name_list, l.status_list ORDER BY l.name_list")
    for name, status, total in rows:
        config = _list_config_values(name, ("subject",))
        lists.append({
            "name": name,
            "subject": config.get("subject", ""),
            "status": status,
            "subscribers": int(total or 0),
        })
    return lists


def list_exists(name, domain):
    return bool(psql(f"SELECT 1 FROM list_table WHERE name_list = '{name}' AND robot_list = '{domain}'"))


def create_list(name, domain, subject, list_type, owners, description):
    """Create a list from a Sympa template. Returns (ok, message)."""
    owner_xml = "".join(f"<owner multiple=\"1\"><email>{escape(owner)}</email></owner>" for owner in owners)
    xml = (
        '<?xml version="1.0" ?>\n<list>'
        f"<listname>{escape(name)}</listname>"
        f"<type>{escape(list_type)}</type>"
        f"<subject>{escape(subject)}</subject>"
        f"<description>{escape(description)}</description>"
        "<status>open</status>"
        # Sympa refuses a list without topic. An unknown topic is accepted and
        # dropped from the list config: lists stay out of the topic index
        "<topic>other</topic>"
        f"{owner_xml}"
        "</list>\n"
    )
    with tempfile.NamedTemporaryFile("w", suffix=".xml", delete=False) as fp:
        fp.write(xml)
        local_path = fp.name
    remote_path = f"/tmp/create-{name}.xml"
    try:
        proc = _podman("cp", local_path, f"sympa-app:{remote_path}")
        if proc.returncode != 0:
            return False, proc.stderr.strip()
        _podman("exec", "sympa-app", "chmod", "0644", remote_path)
        proc = sympa_cli("create", f"--input-file={remote_path}", domain)
        return proc.returncode == 0, (proc.stdout + proc.stderr).strip()
    finally:
        os.unlink(local_path)
        _podman("exec", "sympa-app", "rm", "-f", remote_path)


def purge_list(name, domain):
    proc = sympa_cli("close", "--mode=purge", f"{name}@{domain}")
    return proc.returncode == 0, (proc.stdout + proc.stderr).strip()
