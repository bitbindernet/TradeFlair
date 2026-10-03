# TradeFlair Devvit

Initial Devvit port of the TradeFlair Reddit-facing ingestion layer.

## v0.0.1 scope

This version intentionally does **not** contain trade-confirmation logic or update user flair. It only:

1. receives Reddit `CommentCreate` events,
2. filters them to configured trade threads,
3. normalizes and stores the comment in Redis,
4. places the Reddit comment fullname in a FIFO-style Redis outbox,
5. records `CommentDelete` events as tombstones and removes stored body content.

The next phase will drain this outbox to the existing TradeFlair API/MySQL backend.

## Subreddit and trade-thread configuration

Edit `src/server/config.ts`.

Current seed configuration:

| Subreddit | User-flair capability required | Trade thread |
| --- | --- | --- |
| `Currencytradingcards` | yes | `t3_1456rzb` |
| `CCAutoFlare` | yes | `t3_1j4k61w` |
| `Spacetradingcards` | yes | not yet configured |

Devvit apps are installed per subreddit. A single installation cannot discover every subreddit on which another installation exists, so the explicit allow-list is deliberate. The event payload supplies the current subreddit and the app rejects anything not present in this configuration.

## Redis schema

`tradeflair:comments` is a Redis hash:

- field: Reddit comment fullname (`t1_...`)
- value: normalized JSON payload

`tradeflair:outbox` is a sorted set:

- member: Reddit comment fullname (`t1_...`)
- score: first queued timestamp in milliseconds

Because both structures use the Reddit comment fullname as the identity, repeated trigger delivery is idempotent. The stored payload is updated while the outbox contains only one work item.

## Local development

Requires Node 24+.

```bash
cd devvit
npm install
npx devvit login
npm run test:types
npm run test:unit
npm run build
npm run dev
```

`npm run dev` starts a Devvit playtest.

## Upload and publish

```bash
npm run deploy
npx devvit publish
```

The GitHub deploy workflow performs `devvit upload` only. Publishing remains a deliberate/manual release step.

## GitHub Actions authentication

Add a repository Actions secret named `DEVVIT_TOKEN` containing the full JSON contents of your local Devvit token file after `npx devvit login`:

PowerShell:

```powershell
Get-Content "$env:USERPROFILE\.devvit\token" -Raw
```

The workflow exposes it to the CLI as `DEVVIT_AUTH_TOKEN`.

## Planned v0.0.2

- add approved TradeFlair API domain to `permissions.http.domains`,
- add a scheduled outbox-drain task,
- POST queued comments in batches,
- acknowledge Redis records only after a successful API response,
- retry failures by leaving them in the outbox.
