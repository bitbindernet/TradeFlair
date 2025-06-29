#!/usr/bin/env python3
import os
import json
import argparse
import pymysql
import praw

# ───── Reddit client from env vars ─────
reddit = praw.Reddit(
    client_id=os.getenv("REDDIT_SCRIPT_ID"),
    client_secret=os.getenv("REDDIT_SCRIPT_SECRET"),
    username=os.getenv("REDDITUSER"),
    password=os.getenv("REDDITUSERPASSWORD"),
    user_agent="TradeFlair-v0.0.1"
)

# ───── MySQL DB connection ─────
def get_mysql_cursor():
    conn = pymysql.connect(
        host=os.getenv("MYSQL_SERVER"),
        port=int(os.getenv("MYSQL_SERVER_PORT")),
        user=os.getenv("MYSQL_USER"),
        password=os.getenv("MYSQL_PASSWORD"),
        database="redditbot",
        charset="utf8mb4",
        autocommit=True
    )
    return conn.cursor()

def upsert_user(cursor, reddit_id):
    cursor.execute("""
        INSERT INTO users (redditId) VALUES (%s)
        ON DUPLICATE KEY UPDATE redditId=redditId
    """, (reddit_id,))
    cursor.execute("SELECT id FROM users WHERE redditId = %s", (reddit_id,))
    return cursor.fetchone()[0]

def upsert_message(cursor, comment, user_id, trade_thread_id):
    parent_id = comment.parent_id.replace("t1_", "").replace("t3_", "") if comment.parent_id else None
    body = comment.body if hasattr(comment, "body") else ""
    created_utc = int(comment.created_utc) if hasattr(comment, "created_utc") else 0

    cursor.execute("""
        INSERT INTO messages (redditId, redditParentId, body, created, userId, tradeThreadId)
        VALUES (%s, %s, %s, FROM_UNIXTIME(%s), %s, %s)
        ON DUPLICATE KEY UPDATE body=VALUES(body), created=VALUES(created), userId=VALUES(userId)
    """, (
        comment.id, parent_id, body, created_utc, user_id, trade_thread_id
    ))

# ───── Core logic ─────
def get_replies_to_message_ids(message_ids):
    """
    Given a list of comment IDs, return all descendant replies to those comments (full tree).
    """
    replies = []
    for msg_id in message_ids:
        try:
            comment = reddit.comment(id=msg_id)
            comment.refresh()
            descendants = comment.replies.list()
            replies.extend([r for r in descendants if isinstance(r, praw.models.Comment)])
        except Exception as e:
            print(f"❌ Error fetching replies for {msg_id}: {e}")
    return replies


def write_to_json(replies, filename="messages.json"):
    output = [{
        "id": r.id,
        "parent_id": r.parent_id.replace("t1_", ""),
        "author": r.author.name if r.author else "[deleted]",
        "body": r.body,
        "created_utc": r.created_utc
    } for r in replies]

    with open(filename, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2)
    print(f"✅ Wrote replies to {filename}")

def write_to_db(replies, trade_thread_id=2):
    cursor = get_mysql_cursor()
    for r in replies:
        try:
            author = r.author.name if r.author else "[deleted]"
            user_id = upsert_user(cursor, author)
            upsert_message(cursor, r, user_id, trade_thread_id)
        except Exception as e:
            print(f"❌ DB insert failed for comment {r.id}: {e}")
    print("✅ Wrote replies to MySQL database")

def write_to_stdout(replies):
    for r in replies:
        author = r.author.name if r.author else "[deleted]"
        preview = r.body.strip().replace('\n', ' ')[:80]
        print(f"↪️  Reply by {author} to {r.parent_id.replace('t1_', '')}: {preview}...")

# ───── CLI entrypoint ─────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch direct replies to one or more Reddit comment IDs.")
    parser.add_argument("--message-ids", nargs="+", required=True, help="One or more Reddit comment IDs")
    parser.add_argument("--stdout", action="store_true", help="Print replies to stdout")
    parser.add_argument("--json", action="store_true", help="Write replies to messages.json")
    parser.add_argument("--db", action="store_true", help="Insert replies into MySQL database")
    parser.add_argument("--thread-id", type=int, default=2, help="Trade thread ID to associate with DB inserts (default: 2)")
    args = parser.parse_args()

    replies = get_replies_to_message_ids(args.message_ids)

    if args.stdout:
        write_to_stdout(replies)
    if args.json:
        write_to_json(replies)
    if args.db:
        write_to_db(replies, args.thread_id)

    if not any([args.stdout, args.json, args.db]):
        print("⚠️  No output method selected. Use --stdout, --json, or --db.")
