import { redis } from '@devvit/web/server';

const COMMENTS_HASH = 'tradeflair:comments';
const OUTBOX_KEY = 'tradeflair:outbox';

export type QueuedComment = {
  eventType: 'CommentCreate' | 'CommentDelete';
  commentId: string;
  postId: string;
  parentId?: string;
  subredditId?: string;
  subredditName?: string;
  authorId?: string;
  authorName?: string;
  body?: string;
  permalink?: string;
  createdAt?: string;
  observedAt: string;
  deletedAt?: string;
};

export async function enqueueComment(record: QueuedComment): Promise<void> {
  await redis.hSet(COMMENTS_HASH, {
    [record.commentId]: JSON.stringify(record),
  });

  const existingScore = await redis.zScore(OUTBOX_KEY, record.commentId);
  if (existingScore == null) {
    await redis.zAdd(OUTBOX_KEY, {
      member: record.commentId,
      score: Date.now(),
    });
  }
}

export async function removeStoredBodyAndQueueDeletion(
  record: QueuedComment
): Promise<void> {
  await enqueueComment({
    ...record,
    body: undefined,
    permalink: undefined,
  });
}

export async function getPendingCount(): Promise<number> {
  return await redis.zCard(OUTBOX_KEY);
}

// v0.0.2 will use these helpers to batch records to the TradeFlair API.
export async function peekPending(limit = 100): Promise<QueuedComment[]> {
  const members = await redis.zRange(OUTBOX_KEY, 0, Math.max(0, limit - 1), { by: 'rank' });
  if (members.length === 0) return [];

  const records: QueuedComment[] = [];
  for (const { member } of members) {
    const raw = await redis.hGet(COMMENTS_HASH, member);
    if (raw) records.push(JSON.parse(raw) as QueuedComment);
  }
  return records;
}

export async function acknowledge(commentIds: string[]): Promise<void> {
  if (commentIds.length === 0) return;
  await redis.zRem(OUTBOX_KEY, commentIds);
  await redis.hDel(COMMENTS_HASH, commentIds);
}
