<!-- © AngelaMos | 2026 -->
<!-- README2.md -->

```
   ____          _   ____                  _
  / ___|___ _ __| |_/ ___|  ___ ___  _   _| |_
 | |   / _ \ '__| __\___ \ / __/ _ \| | | | __|
 | |__|  __/ |  | |_ ___) | (_| (_) | |_| | |_
  \____\___|_|   \__|____/ \___\___/ \__,_|\__|

   cybersecurity certification demand scanner
```

A command-line web scraper, written in Elixir, that pulls cybersecurity job
postings from public hiring APIs, isolates the genuine cybersecurity roles, and
reports which certifications employers ask for most. It writes a clean Markdown
report plus raw JSON/CSV. **Every number it prints is the real count it pulled —
nothing is fabricated.**

---

## TL;DR — bare Linux box to first scan

```sh
git clone https://github.com/CarterPerez-dev/exs-cyberjob-scraper.git
cd exs-cyberjob-scraper
./install.sh                       # installs Erlang + Elixir + deps, builds the binary
./certscout --sources greenhouse   # your first scan, no API keys, ~1 minute
```

That's the whole thing. Open `output/REPORT.md` when it finishes.

---

## What you need

- A **Debian / Ubuntu / Kali** machine (anything `apt`-based). Brand-new install is fine.
- Run as **root**, or as a user with **sudo**.
- An **internet connection**.

Nothing else. `install.sh` pulls in *everything* the project needs — you do not
need to install Elixir, Erlang, or any dependency by hand.

> Not on an apt distro? Install **Elixir 1.18+** however you like, then run
> `mix deps.get && mix compile && mix escript.build`. Or use the
> [Docker path](#no-install-docker-path) below — it needs nothing but Docker.

---

## Install

```sh
./install.sh
```

What it does, in order:

1. Installs system build tools (`build-essential`, `libssl-dev`, …) via `apt`.
2. Installs **[mise](https://mise.jdx.dev)**, the version manager, then uses it to
   install **Erlang/OTP 27 + Elixir 1.18**.
3. Installs Hex + Rebar, fetches the project's dependencies, and compiles.
4. Builds the standalone **`./certscout`** binary.

> **First run takes ~5-10 minutes** because Erlang compiles from source. Grab a
> coffee. It only happens once.
>
> If `install.sh` already finds a working Elixir 1.18+, it skips straight to step 3.
>
> After it finishes, `mix` is wired into new shells automatically. If `certscout`
> isn't found in your *current* shell, just open a new terminal (or run
> `eval "$(~/.local/bin/mise activate bash)"`).

---

## Run it

**Fastest (no keys, great smoke test):**

```sh
./certscout --sources greenhouse
```

**Full default scrape (workday + greenhouse):**

```sh
./certscout
```

**Tune it:**

```sh
./certscout --sources greenhouse,workday --target 8000 --top 10
./certscout --sources greenhouse --output reports/run1
```

Prefer a task runner? If you have [`just`](https://github.com/casey/just):

```sh
just install   # same as ./install.sh
just demo      # quick greenhouse-only run
just run       # full default scrape
just build     # (re)build the ./certscout binary
just test      # run the test suite
```

---

## Options

```
--sources a,b,c     Sources to scrape (workday,greenhouse,lever,ashby,remoteok,usajobs,adzuna)
--terms "x,y"       Search terms for keyword sources
--target N | all    Cap on cybersecurity postings to analyze (default 12000)
--top N             Number of certifications in the report (default 12)
--concurrency N     Max concurrent requests (default 24)
--delay MS          Max jitter delay per request in ms (default 25)
--output DIR        Output directory (default output)
--all               Analyze every posting, skip the cybersecurity filter
--country CC        Country code for Adzuna (default us)
--location "x,y"    Keep only postings whose location text contains one of these (case-insensitive)
--boards-file F     Override Greenhouse board tokens (one per line)
--workday-file F    Override Workday sites (lines: tenant,datacenter,site)
--lever-file F      Override Lever companies (one per line)
--ashby-file F      Override Ashby orgs (one per line)
--certs-file F      Override certification catalogue (JSON array)
-h, --help          Show this help
```

---

## Output

```
output/
  REPORT.md                 ranked report with logos, counts, and shares
  data/
    certifications.csv      rank, certification, issuer, postings, percent
    certifications.json     same ranking as JSON
    postings.json           analyzed cybersecurity postings + matched certs
    postings.csv            same postings as CSV
    summary.json            run metadata and the top certifications
  assets/                   downloaded certification logos
```

---

## Sources

Sources are pluggable. The defaults need no keys.

| Source | Auth | Notes |
|--------|------|-------|
| `workday` | none | Enterprise/defense Workday boards; keyword search, paginated, full descriptions. The volume engine. |
| `greenhouse` | none | Greenhouse public boards; one request returns every posting with its description. |
| `lever` | none | Lever public postings. |
| `ashby` | none | Ashby public job boards. Pass `--ashby-file lists/ashby_orgs.txt` for the bundled org list. |
| `remoteok` | none | Single public feed; small, good for a quick smoke test. |
| `usajobs` | free key | Federal/DoD postings, the richest certification source. Set `USAJOBS_API_KEY` and `USAJOBS_EMAIL`. |
| `adzuna` | free key | Market-wide keyword search, highest raw volume. Set `ADZUNA_APP_ID` and `ADZUNA_APP_KEY`. |

**Default sources:** `workday`, `greenhouse`.

**Optional API keys** (set as environment variables before running):

```sh
export USAJOBS_API_KEY=...   USAJOBS_EMAIL=...     # enables the usajobs source
export ADZUNA_APP_ID=...     ADZUNA_APP_KEY=...    # enables the adzuna source
```

Big, hand-verified company lists ship in [`lists/`](lists/) — point a source at one
with the matching `--*-file` flag (e.g. `--ashby-file lists/ashby_orgs.txt`).

---

## Regional filtering

`--location "x,y"` keeps only postings whose raw location text contains one of the
given terms (case-insensitive), applied after the cybersecurity filter and before
the certification count. Useful for scoping the report to a country or city, e.g.:

```sh
./certscout --sources greenhouse,workday --location "indonesia,jakarta,bali,surabaya,bandung"
```

Coverage depends entirely on what the underlying postings say and how many of the
scraped companies hire in that region — `workday`/`greenhouse`/`lever`/`ashby` scan
a hand-curated company list (`lists/`), so a country with few matching employers
will return a thin sample. `adzuna` does not currently operate in Indonesia (its
`--country` list is au, at, br, ca, de, fr, gb, in, it, mx, nl, nz, pl, sg, us, za,
ch, sp — no `id`), so it cannot be used to widen Indonesia coverage.

---

## Customizing the certifications

The certification catalogue lives in `lib/cert_scout/certifications.ex`. To scan
for a different set without touching code, pass `--certs-file` a JSON array of
`{slug, name, issuer, aliases, logo}` objects.

---

## No-install (Docker path)

Don't want to install Elixir at all? You only need Docker. The `Justfile`
auto-detects it and runs everything inside the official `elixir` image:

```sh
just demo                  # quick greenhouse-only run, fully containerized
just run --sources greenhouse,workday
```

That path mounts your source into the official `elixir` image and runs it with
`mix` each time — no image to manage, but nothing is precompiled. For a real
standalone image, build the `Dockerfile` instead: a multi-stage build that
compiles the `certscout` escript in an `elixir:1.18-otp-27-alpine` build stage,
then copies just the binary and `lists/` into a slim `erlang:27-alpine` runtime
stage.

```sh
just docker-build                          # docker build -t certscout .
just docker-run --sources greenhouse       # writes into ./output on the host
```

Or with plain Docker:

```sh
docker build -t certscout .
docker run --rm -v "$PWD/output":/app/output certscout --sources greenhouse
```

---

## Notes on conduct

CertScout only calls documented public hiring APIs, sends a descriptive
user-agent, limits concurrency, jitters requests, and backs off on HTTP 429. It
does not attempt to defeat anti-bot protections. Respect each site's terms of
service and robots policy before pointing it somewhere new.
