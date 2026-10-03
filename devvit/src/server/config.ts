export type TrackedSubreddit = {
  name: string;
  userFlairRequired: boolean;
  tradeThreadPostIds: readonly string[];
};

// Devvit apps are installed per-subreddit, so cross-subreddit discovery is not
// available from one installation. Keep an explicit allow-list here and verify
// the current installation against it.
export const TRACKED_SUBREDDITS: readonly TrackedSubreddit[] = [
  {
    name: 'Currencytradingcards',
    userFlairRequired: true,
    tradeThreadPostIds: ['t3_1456rzb'],
  },
  {
    name: 'CCAutoFlare',
    userFlairRequired: true,
    tradeThreadPostIds: ['t3_1j4k61w'],
  },
  {
    name: 'Spacetradingcards',
    userFlairRequired: true,
    tradeThreadPostIds: [],
  },
] as const;

export function getTrackedSubreddit(name: string | undefined): TrackedSubreddit | undefined {
  if (!name) return undefined;
  return TRACKED_SUBREDDITS.find(
    (subreddit) => subreddit.name.toLowerCase() === name.toLowerCase()
  );
}

export function isTrackedTradeThread(
  subredditName: string | undefined,
  postId: string | undefined
): boolean {
  if (!postId) return false;
  const subreddit = getTrackedSubreddit(subredditName);
  return subreddit?.tradeThreadPostIds.includes(postId) ?? false;
}
