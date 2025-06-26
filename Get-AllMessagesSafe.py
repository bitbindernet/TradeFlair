#!/usr/bin/env python3
"""
Download a Reddit trade‑thread (or any submission) into a streaming JSON
file (messages.json by default) that your PowerShell / SimplySql pipeline
can ingest later.

Features
────────
• Handles 429 Too‑Many‑Requests with exponential / Retry‑After back‑off
• Streams JSON to disk – no giant objects in memory
• Emits periodic progress messages so you know it’s still alive
• Environment‑variable driven, with an optional --out flag
"""

import argparse
import json
import os
import sys
import time
from contextlib import contextmanager
from datetime import datetime

import praw
import prawcore

# ─────────────────────────── configuration ──────────────────────────────
REQUIRED_ENV_VARS = [
    "REDDIT_SCRIPT_ID",
    "REDDIT_SCRIPT_SECRET",
    "REDDITUSER",
    "REDDITUSERPASSWORD",
    "TRADE_THREAD",
]

PROGRESS_EVERY = 250    # print after this many comments
PROGRESS_SECONDS = 15   # or after this many seconds

# globals for progress tracking
_last_tick = time.time()
_count = 0

# ─────────────────────────── utility helpers ─────────────────────────────
def env_or_exit(var: str) -> str:
    val = os.getenv(var)
    if not val:
        print(f"Missing required env var: {var}", file=sys.stderr)
        sys.exit(1)
    return val


def tick_progress():
    """Emit a status line every N comments or T seconds."""
    global _last_tick, _count
    now = time.time()
    if (_count % PROGRESS_EVERY == 0) or (now - _last_tick >= PROGRESS_SECONDS):
        ts = datetime.utcnow().strftime("%H:%M:%S")
        print(f"[{ts}] processed {_count:,} comments so far…",
              file=sys.stderr, flush=True)
        _last_tick = now


def backoff_sleep(exc: prawcore.TooManyRequests, attempt: int):
    retry_after = (
        getattr(exc, "response", None)
        and exc.response.headers.get("retry-after")
    )
    wait = int(retry_after) if retry_after else min(60, 2 ** attempt)
    print(f"[429] sleeping {wait}s before retry …", file=sys.stderr)
    time.sleep(wait)


def fetch_with_retry(func, *args, **kwargs):
    """Call a PRAW method, retrying politely on rate‑limit / transient errors."""
    attempt = 0
    while True:
        try:
            return func(*args, **kwargs)
        except prawcore.TooManyRequests as e:
            attempt += 1
            backoff_sleep(e, attempt)
        except prawcore.ResponseException:
            attempt += 1
            time.sleep(min(30, 2 ** attempt))


@contextmanager
def reddit_client():
    """Yield a PRAW client (auto‑retry handled elsewhere)."""
    reddit = praw.Reddit(
        client_id=env_or_exit("REDDIT_SCRIPT_ID"),
        client_secret=env_or_exit("REDDIT_SCRIPT_SECRET"),
        username=env_or_exit("REDDITUSER"),
        password=env_or_exit("REDDITUSERPASSWORD"),
        user_agent="TradeFlair-v0.0.1",
        ratelimit_seconds=0,  # we manage our own waiting
    )
    yield reddit
    # nothing to close explicitly

# ─────────────────────────── core processing ─────────────────────────────
def process_comment(comment):
    """Convert a PRAW Comment into the schema expected by PowerShell."""
    global _count
    _count += 1
    tick_progress()

    return {
        "id": comment.id,
        "author": str(comment.author) if comment.author else "[deleted]",
        "body": comment.body,
        "score": comment.score,
        "created_utc": comment.created_utc,
        "replies": [process_comment(r) for r in comment.replies],
    }


# ─────────────────────────── main routine ────────────────────────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--out",
        default=os.getenv("OUTPUT_FILE", "messages.json"),
        help="Path to write the JSON (default: messages.json)",
    )
    args = parser.parse_args()

    trade_thread_url = env_or_exit("TRADE_THREAD")

    with reddit_client() as reddit:
        print("Fetching submission …", file=sys.stderr)
        submission = fetch_with_retry(reddit.submission, url=trade_thread_url)

        print("Loading comments (replace_more) …", file=sys.stderr)
        fetch_with_retry(submission.comments.replace_more, limit=None)
        print(
            f"replace_more done; walking {len(submission.comments):,} "
            "top‑level comments.",
            file=sys.stderr,
        )

        with open(args.out, "w", encoding="utf-8") as fh:
            # JSON header
            fh.write('{\n')
            fh.write(f'  "thread_id": "{submission.id}",\n')
            fh.write(f'  "thread_title": {json.dumps(submission.title)},\n')
            fh.write('  "comments": [\n')

            first = True
            for top_comment in submission.comments:
                obj = process_comment(top_comment)
                if not first:
                    fh.write(',\n')
                first = False
                json.dump(obj, fh, ensure_ascii=False)
            fh.write('\n  ]\n}\n')

    print(
        f"Done! Wrote {args.out} with {_count:,} total comments.",
        file=sys.stderr,
    )


# ─────────────────────────── entry‑point ────────────────────────────────
if __name__ == "__main__":
    # quick env‑var sanity check
    missing = [v for v in REQUIRED_ENV_VARS if not os.getenv(v)]
    if missing:
        print("Cannot start; missing env vars: " + ", ".join(missing),
              file=sys.stderr)
        sys.exit(1)

    main()
