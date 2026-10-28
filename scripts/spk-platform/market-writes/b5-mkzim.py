#!/usr/bin/env python3
"""b5-mkzim.py OUT.zim [MARKER]: write a minimal valid ZIM (major version 5) holding one article.

Kiwix serve starts only once a ZIM exists, so the Kiwix write is the upload of a ZIM; this builds the
smallest one: namespace A holds the article "Hello" (also the main page), namespace M the metadata
kiwix-serve reads (Title, Language, Creator, Publisher, Date, Description, Counter). One uncompressed
cluster (info byte 1). Layout per the ZIM file format: 80-byte header, MIME list, URL pointer list (u64),
title pointer list (u32), directory entries, cluster, cluster pointer list, MD5 of everything before it.
The result is read back by this script's own parser before it exits 0.
"""
import hashlib, struct, sys

out = sys.argv[1]
marker = sys.argv[2] if len(sys.argv) > 2 else "featured by a resident"
mimes = [b"text/html", b"text/plain"]
html = ("<html><head><title>Hello</title></head><body><h1>Hello</h1><p>%s</p></body></html>" % marker).encode()
entries = [  # (namespace, url, mime index, blob)
    ("A", "Hello", 0, html),
    ("M", "Counter", 1, b"text/html=1"),
    ("M", "Creator", 1, b"featured"),
    ("M", "Date", 1, b"2026-10-28"),
    ("M", "Description", 1, b"A one-article library written by a resident"),
    ("M", "Language", 1, b"eng"),
    ("M", "Publisher", 1, b"featured"),
    ("M", "Title", 1, b"Featured"),
]
entries.sort(key=lambda e: (e[0], e[1]))  # the URL pointer list is ordered by namespace then URL
n = len(entries)
mime_list = b"".join(m + b"\0" for m in mimes) + b"\0"
dirents = []
for i, (ns, url, mi, _) in enumerate(entries):
    dirents.append(struct.pack("<HBcIII", mi, 0, ns.encode(), 0, 0, i) + url.encode() + b"\0" + b"\0")
mime_pos = 80
url_pos = mime_pos + len(mime_list)
title_pos = url_pos + 8 * n
dirent_pos = title_pos + 4 * n
offs, p = [], dirent_pos
for d in dirents:
    offs.append(p); p += len(d)
cluster_pos = p
blobs = [e[3] for e in entries]
base = 4 * (len(blobs) + 1)
boffs, q = [], base
for b in blobs:
    boffs.append(q); q += len(b)
boffs.append(q)
cluster = b"\x01" + b"".join(struct.pack("<I", o) for o in boffs) + b"".join(blobs)
cluster_ptr_pos = cluster_pos + len(cluster)
checksum_pos = cluster_ptr_pos + 8
main_page = [i for i, e in enumerate(entries) if e[:2] == ("A", "Hello")][0]
header = struct.pack("<IHH16sIIQQQQIIQ", 0x044D495A, 5, 0, hashlib.md5(html).digest(), n, 1,
                     url_pos, title_pos, cluster_ptr_pos, mime_pos, main_page, 0xFFFFFFFF, checksum_pos)
body = (header + mime_list + b"".join(struct.pack("<Q", o) for o in offs) + b"".join(struct.pack("<I", i) for i in range(n))
        + b"".join(dirents) + cluster + struct.pack("<Q", cluster_pos))
data = body + hashlib.md5(body).digest()
open(out, "wb").write(data)

# read it back the way a reader does
h = struct.unpack_from("<IHH16sIIQQQQIIQ", data, 0)
assert h[0] == 0x044D495A and h[1] == 5 and h[4] == n and h[5] == 1 and h[12] == len(data) - 16
assert hashlib.md5(data[:h[12]]).digest() == data[h[12]:]
uo = struct.unpack_from("<Q", data, h[6] + 8 * h[10])[0]
mi, pl, ns, rev, cl, bl = struct.unpack_from("<HBcIII", data, uo)
assert ns == b"A" and data[uo + 16:uo + 16 + 5] == b"Hello" and cl == 0
co = struct.unpack_from("<Q", data, h[8])[0]
bo = struct.unpack_from("<2I", data, co + 1 + 4 * bl)
assert data[co + 1 + bo[0]:co + 1 + bo[1]] == html
print(len(data))
