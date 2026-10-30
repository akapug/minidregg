# Batch B5 (files and media) writes. Reasoned from each package's OWN source, unpacked from the fetched
# .spk (no live probe; the no-probing rule). Sources are named per function. Packages: FileDrop 1.0.6
# d13f6723, Kiwix 0.1.0 eace6915, Groove Basin 1.5.1 209d45cd, Tube 1.1.13 cbba85a4.
b5_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# FileDrop 1.0.6 (zombiezen/filedrop: a Go server, -datadir=/filedrop, with the Angular client in
# filedrop/client/bundle.js). Routes read from that bundle's filedrop.Files service: GET /file/ answers
# {"entries":[{"name":...}]}, PUT /file/<name> uploads the raw body (Content-Type application/octet-stream)
# and needs the `write` permission (the owner's role has it, bridge-config permissions read/write/delete),
# GET /file/<name> downloads. Role 0 is "viewer" (read only): the run answered 403 "Insufficient Sandstorm
# permissions", so the table gives the owner role 1, "editor" (b5.tsv). The write is one PUT read back twice: the listing and the bytes.
write_FileDrop() {
  local put; put=$(req PUT /file/featured.txt -H 'Content-Type: application/octet-stream' --data-binary 'written by a resident')
  [[ $put =~ ^20 ]] || { echo "0 PUT /file/featured.txt $put: $(head -c 120 "$body" | tr -d '\n')"; return; }
  local list; list=$(req GET /file/)
  [[ $list == 200 ]] && jq -e '.entries | map(.name) | index("featured.txt")' "$body" >/dev/null || { echo "0 GET /file/ $list does not list featured.txt"; return; }
  local got; got=$(req GET /file/featured.txt)
  [[ $got == 200 ]] && grep -q 'written by a resident' "$body" && echo "1 PUT /file/featured.txt $put; GET /file/ $list lists it; GET /file/featured.txt $got"
}

# Kiwix 0.1.0 (orblivion/KiwixSandstorm: nginx on 8000 in front of kiwix-serve on 8080 and a Flask/uwsgi
# uploader). service-config/nginx.conf sends / and /upload* to the uploader and everything else to
# kiwix-serve; launcher.sh and kiwix-run/kiwix-delayed.sh start kiwix-serve only once /var/data/kiwix.zim
# exists. zim_uploader/uploader/app.py: POST /upload takes multipart `file` (a name ending .zim) plus the
# form field `contentRange` ("bytes 0-N/TOTAL", read unguarded), needs `uploader` in
# X-Sandstorm-Permissions, and on the last chunk renames the upload to kiwix.zim. Kiwix has no write of
# its own (it is a reader), so the write is that upload and the read is the served article:
# kiwix-serve names the book "kiwix", so GET /kiwix/A/Hello. b5-mkzim.py builds the smallest valid ZIM
# (one article, 650 bytes). LIMIT: the page's own uploader chunks at 10 MiB (main.js maxChunkSize), over
# the 8 MiB request bound, so real ZIMs through the page need the above-8-MiB body (APP-MARKET 2b);
# this recipe sends the one small chunk. nginx's client_max_body_size is 50M and the Flask limit 15 MiB.


# Groove Basin now uses apps/interfaces/groove-basin.json. Its live WebSocket
# token must remain open across multipart HTTP and bounded library-file reads;
# the native shared conversation executes those steps. See DATA-2026-10-28.md.

# Tube 1.1.13 (prologic/tube as packaged: /opt/app/tube, .sandstorm/launcher.sh, .sandstorm/config.json:
# port 8000, videos in /var/videos, uploads in /var/uploads, max_upload_size 100 MB, ffmpeg in
# /usr/bin). Routes read from the binary's route table and templates: POST /upload (the upload form posts
# multipart fields video_file, video_title, video_description; the server transcodes with ffmpeg
# -vcodec h264 -acodec aac, cuts a thumbnail with -vframes 1, and moves the result into the library),
# GET / redirects (303) to /v/<random id> once the library has a video (run evidence, 76758dba6), so the read-back follows it; /v/<id> plays, /t/<id> is the thumbnail, /feed.xml the RSS. The page is
# searched for the title and for the file name. b5-tube-clip.py writes a real 2.6 KB clip (ffmpeg needs a decodable stream). LIMITS: a real video
# is over the 8 MiB request bound (APP-MARKET 2b: the above-8-MiB body codec is not built); playback of
# /v/<id>.mp4 uses Range reads, fine for this clip.
# Run evidence (76758dba6): the upload was accepted (200) and the library had the video at once.
