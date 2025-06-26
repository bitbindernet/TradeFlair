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

def set_flair(subreddit_name: str, username: str, flair: str):

    subreddit = reddit.subreddit(subreddit_name)
    # Update the user's flair
    subreddit.flair.set(username, text=flair)


#def update_user_flair(username: str, subreddit_name: str):
#    """
#    Retrieves the current flair, increments the trade count, and updates the flair.
#
#    :param username: The Reddit username.
#    :param subreddit_name: The subreddit name (without the r/ prefix).
#    """
#    try:
#        subreddit = reddit.subreddit(subreddit_name)
#        
#        # Retrieve current flair
#        current_flair_text = None
#        for flair in subreddit.flair(username):
#            if flair["flair_text"]:
#                current_flair_text = flair["flair_text"]
#                break  # Stop after finding the first valid flair
#        
#        if not current_flair_text:
#            print(f" User {username} has no assigned flair. Assigning default...")
#            updated_flair = "Trades: 1"
#        else:
#            print(f" Current flair for {username}: {current_flair_text}")
#            
#            # Extract trade count using regex
#            match = re.search(r"Trades:\s*([\d.]+)", current_flair_text)
#            if match:
#                trade_count = float(match.group(1))  # Convert to float to handle decimals like 69.420
#                updated_trade_count = trade_count + 1  # Increment
#                
#                # Rebuild the flair string
#                updated_flair = f"Trades: {format_trade_count(updated_trade_count)}"
#                
#                print(f"✅ Updating flair to: {updated_flair}")
#            else:
#                print("❌ Could not extract trade count. Resetting to Trades: 1")
#                updated_flair = "Trades: 1"
#        
#        # Update the user's flair
#        subreddit.flair.set(username, text=updated_flair)
#        print(f"✅ Successfully updated {username}'s flair to '{updated_flair}'")
#
#    except Exception as e:
#        print(f"❌ Error updating flair for {username} in {subreddit_name}: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Set a users flair")
    parser.add_argument("subreddit_name", help="Subreddit, must have flair permissions")
    parser.add_argument("username", help="The reddit user")
    parser.add_argument("flair", help="The Flair to set")

    args = parser.parse_args()
    set_flair(args.subreddit_name, args.username, args.flair)