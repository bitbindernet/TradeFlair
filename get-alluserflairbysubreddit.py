import json
import praw
import sys
import os

# Validate required environment variables
REQUIRED_ENV_VARS = ["REDDIT_SCRIPT_ID", "REDDIT_SCRIPT_SECRET", "REDDITUSER", "REDDITUSERPASSWORD", "TRADE_THREAD", "SUBREDDIT_NAME"]
if not all(os.getenv(var) for var in REQUIRED_ENV_VARS):
    print("Cannot start, one or more missing environment variables:", ", ".join(REQUIRED_ENV_VARS))
    sys.exit(1)

reddit = praw.Reddit(
client_id     = os.getenv("REDDIT_SCRIPT_ID"),
client_secret = os.getenv("REDDIT_SCRIPT_SECRET"),
username      = os.getenv("REDDITUSER"),
password      = os.getenv("REDDITUSERPASSWORD"),
user_agent    = "TradeFlair-v0.0.1"
)

TRADE_THREAD   = os.getenv("TRADE_THREAD")
#SUBREDDIT_NAME = os.getenv("SUBREDDIT_NAME")
subreddit_name = os.getenv("SUBREDDIT_NAME", "TradeFlair")  # Default subreddit
user_flairs = {}
subreddit = reddit.subreddit(subreddit_name)
for flair in subreddit.flair(limit=None):  # Iterate over all subreddit members
    if flair["user"] and flair["flair_text"]:
        username = flair["user"].name
        flair_text = flair["flair_text"]
        #flair_count = re.search(r'\d+', flair_text)
        user_flairs[username] = flair_text
                

print(json.dumps(user_flairs))