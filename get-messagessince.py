#!/usr/bin/env python3
"""
Fetch a Reddit submission (trade thread) into messages.json
with optional limits on comment expansion and age.

•  --more-limit / MORE_LIMIT    : throttle replace_more()
•  --since      / START_TIMESTAMP : skip comments older than a given epoch
•  Progress reporting + 429 back-off
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

# ─────────────── runtime knobs ───────────────
REQUIRED_ENV_VARS = [
    "REDDIT_SCRIPT_ID",
    "REDDIT_SCRIPT_SECRET",
    "REDDITUSER",
    "REDDITUSERPASSWORD",
    "TRADE_THREAD",
]

PROGRESS_EVERY = 250
PROGRESS_SECONDS = 15

_last_tick = time.time()
_count = 0
_kept = 0  # comments that survive the --since filter


# ─────────────── helpers ───────────────
def env_or_exit(var: str, default=None):
    val = os.getenv(var, default)
    if val is None:
        print(f"Missing required env var: {var}", file=sys.stderr)
        sys.exit(1)
    return val


def tick_progress():
    global _last_tick, _count, _kept
    now = time.time()
    if (_count % PROGRESS_EVERY == 0) or (now - _last_tick >= PROGRESS_SECONDS):
        ts = datetime.utcnow().strftime("%H:%M:%S")
        print(
            f"[{ts}] scanned {_count:,} comments "
            f"({ _kept:,} kept after --since filter)…",
            file=sys.stderr,
            flush=True,
        )
        _last_tick = now


def backoff_sleep(exc: prawcore.TooManyRequests, attempt: int):
    retry_after = (
        getattr(exc, "response", None) and exc.response.headers.get("retry-after")
    )
    wait = int(retry_after) if retry_after else min(60, 2 ** attempt)
    print(f"[429] sleeping {wait}s before retry …", file=sys.stderr)
    time.sleep(wait)


def fetch_with_retry(func, *args, **kwargs):
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
    reddit = praw.Reddit(
        client_id=env_or_exit("REDDIT_SCRIPT_ID"),
        client_secret=env_or_exit("REDDIT_SCRIPT_SECRET"),
        username=env_or_exit("REDDITUSER"),
        password=env_or_exit("REDDITUSERPASSWORD"),
        user_agent="TradeFlair-v0.0.1",
        ratelimit_seconds=0,
    )
    yield reddit


# ─────────────── comment processing ───────────────
def process_comment(comment, since_ts):
    """
    Return the dict if the comment is newer than since_ts,
    otherwise None (and we don't recurse into its children).
    """
    global _count, _kept
    _count += 1
    tick_progress()

    if comment.created_utc <= since_ts:
        return None

    _kept += 1
    return {
        "id": comment.id,
        "author": str(comment.author) if comment.author else "[deleted]",
        "body": comment.body,
        "score": comment.score,
        "created_utc": comment.created_utc,
        "replies": [
            r
            for reply in comment.replies
            if (r := process_comment(reply, since_ts)) is not None
        ],
    }


# ─────────────── main ───────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=os.getenv("OUTPUT_FILE", "messages.json"))
    parser.add_argument(
        "--more-limit",
        type=int,
        default=int(os.getenv("MORE_LIMIT", "-1")),
        help="Pass to submission.comments.replace_more(limit=...). "
        "0 = skip, -1 = expand all (default -1).",
    )
    parser.add_argument(
        "--since",
        type=float,
        default=float(os.getenv("START_TIMESTAMP", "0")),
        help="Skip comments with created_utc <= this epoch time.",
    )
    args = parser.parse_args()

    trade_thread_url = env_or_exit("TRADE_THREAD")

    with reddit_client() as reddit:
        print("Fetching submission …", file=sys.stderr)
        submission = fetch_with_retry(reddit.submission, url=trade_thread_url)

        print(
            f"Loading comments (replace_more limit={args.more_limit}) …",
            file=sys.stderr,
        )
        fetch_with_retry(submission.comments.replace_more, limit=args.more_limit)
        print(
            f"replace_more done; walking {len(submission.comments):,} "
            "top-level comments.",
            file=sys.stderr,
        )

        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write('{\n')
            fh.write(f'  "thread_id": "{submission.id}",\n')
            fh.write(f'  "thread_title": {json.dumps(submission.title)},\n')
            fh.write('  "comments": [\n')

            first = True
            for top in submission.comments:
                obj = process_comment(top, args.since)
                if obj is None:
                    continue
                if not first:
                    fh.write(',\n')
                first = False
                json.dump(obj, fh, ensure_ascii=False)
            fh.write('\n  ]\n}\n')

    print(
        f"Done! scanned {_count:,}, kept {_kept:,}. "
        f"Wrote {args.out}.",
        file=sys.stderr,
    )


# ─────────────── entry point ───────────────
if __name__ == "__main__":
    missing = [v for v in REQUIRED_ENV_VARS if not os.getenv(v)]
    if missing:
        print(
            "Cannot start; missing env vars: " + ", ".join(missing),
            file=sys.stderr,
        )
        sys.exit(1)

    main()
