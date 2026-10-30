# The Mini project site

Static pages for GitHub Pages: plain HTML and one stylesheet (`site.css`, light and dark),
no JavaScript, no external fonts or scripts.

| Page | Content |
| --- | --- |
| `index.html` | what Mini is, where to try it, the shutdown date and the free and paid routes, links to the README, the experience document and the plan |
| `language.html` | Objective Bend: Core4, one example, what is and is not proved |
| `laws.html` | laws, object records, the Objective pin, activities, seats, and which a Host runs |
| `architecture.html` | admission, laws, receipts, consent, private rooms, agreement |
| `edition.html` | what the next build carries: built, in progress, not in this edition; each line is a row of `docs/STATUS.md` |
| `status.html` | **generated**: the table in `docs/STATUS.md` (`gen-status.py`); every row names the landing commit or journey row it rests on |
| `join.html` | a redirect to the join page on the demo host (the door owns the join copy) |

## Rules

- Every factual sentence comes from a file at main, and `SOURCES.md` maps it to file and
  lines. When a source changes, change the page and the map together. Where a page and
  the repository disagree, the repository is right.
- Never edit `status.html`. Edit the table in `docs/STATUS.md`, then run
  `python3 website/gen-status.py`. The header and footer are copied from `index.html`.
- A code block marked `<pre data-source="PATH">` must be text of `PATH`.
- `python3 website/gen-status.py --check` (the `website` row of `scripts/local-gates.sh`,
  and a step of `.github/workflows/pages.yml`) fails on a stale status page or a drifted
  code block, and runs two controls that must be refused.

## Deploy

`.github/workflows/pages.yml` publishes this directory on every push to `main` that
touches `website/` or `docs/STATUS.md`, after the check passes. Local preview: open
`index.html`, or `python3 -m http.server -d website 8080`.
