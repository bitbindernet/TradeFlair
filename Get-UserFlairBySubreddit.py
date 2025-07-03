import json
import praw
import sys
import os

# Validate required environment variables
REQUIRED_ENV_VARS = ["REDDIT_SCRIPT_ID", "REDDIT_SCRIPT_SECRET", "REDDITUSER", "REDDITUSERPASSWORD"]
if not all(os.getenv(var) for var in REQUIRED_ENV_VARS):
    print("Cannot start, one or more missing environment variables:", ", ".join(REQUIRED_ENV_VARS))
    sys.exit(1)

if len(sys.argv) != 3:
    print("Usage: python GetSpecificUserFlair.py <subreddit_name> <username>")
    sys.exit(1)

subreddit_name = sys.argv[1]
username = sys.argv[2]

reddit = praw.Reddit(
    client_id=os.getenv("REDDIT_SCRIPT_ID"),
    client_secret=os.getenv("REDDIT_SCRIPT_SECRET"),
    username=os.getenv("REDDITUSER"),
    password=os.getenv("REDDITUSERPASSWORD"),
    user_agent="TradeFlair-v0.0.1"
)

subreddit = reddit.subreddit(subreddit_name)

flair = subreddit.flair.redditor(username)

if flair and flair['flair_text']:
    result = {username: flair['flair_text']}
else:
    result = {username: None}

print(json.dumps(result))