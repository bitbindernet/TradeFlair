import praw
import sys
import os
import argparse

reddit = praw.Reddit(
client_id     = os.getenv("REDDIT_SCRIPT_ID"),
client_secret = os.getenv("REDDIT_SCRIPT_SECRET"),
username      = os.getenv("REDDITUSER"),
password      = os.getenv("REDDITUSERPASSWORD"),
user_agent    = "TradeFlair-v0.0.1"
)

def post_reply(comment_id: str, body: str):
    """
    Posts a reply to a given comment.

    :param comment_id: The ID of the Reddit comment to reply to.
    :param body: The body text of the reply.
    """
    try:
        comment = reddit.comment(id=comment_id)
        comment.reply(body)
        print(f"✅ Successfully replied to comment {comment_id}")
    except Exception as e:
        print(f"❌ Error posting reply to {comment_id}: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reply to a Reddit comment.")
    parser.add_argument("comment_id", help="The ID of the Reddit comment to reply to.")
    parser.add_argument("body", help="The body of the reply.")

    args = parser.parse_args()
    post_reply(args.comment_id, args.body)