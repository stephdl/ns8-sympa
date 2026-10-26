#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

#
# Sympa lists, read from the database and changed with the sympa CLI
#

import os
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


def _list_subjects():
    """Subject of every list config, read with one exec: {name: subject}"""
    proc = _podman("exec", "sympa-app", "sh", "-c",
                   "grep -sH '^subject ' /var/lib/sympa/list_data/*/config")
    subjects = {}
    for line in proc.stdout.splitlines():
        path, _, value = line.partition(":subject ")
        name = path.removesuffix("/config").rsplit("/", 1)[-1]
        subjects.setdefault(name, value.strip())
    return subjects


def count_lists():
    """Lists on the sympa-data volume, readable while the pod is stopped"""
    proc = _podman("volume", "inspect", "sympa-data", "--format", "{{.Mountpoint}}")
    if proc.returncode != 0:
        return 0
    path = os.path.join(proc.stdout.strip(), "list_data")
    if not os.path.isdir(path):
        return 0
    # List folders belong to the container sympa user: the module can see them, not read them
    with os.scandir(path) as entries:
        return sum(entry.is_dir() for entry in entries)


def get_lists(domain):
    """Lists of the robot, with subject, status and subscribers"""
    lists = []
    # total_list is a cache Sympa fills later: count the subscribers instead
    rows = psql("SELECT l.name_list, l.status_list, COUNT(s.user_subscriber) FROM list_table l "
                "LEFT JOIN subscriber_table s ON s.list_subscriber = l.name_list AND s.robot_subscriber = l.robot_list "
                f"WHERE l.robot_list = '{domain}' GROUP BY l.name_list, l.status_list ORDER BY l.name_list")
    subjects = _list_subjects() if rows else {}
    for name, status, total in rows:
        lists.append({
            "name": name,
            "subject": subjects.get(name, ""),
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
