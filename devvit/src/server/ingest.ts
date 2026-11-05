import type { OnCommentCreateRequest } from '@devvit/web/shared';
import { isTrackedTradeThread } from './config';
import type { QueuedComment } from './outbox';

export type CommentIngestResult =
  | { status: 'ignored'; reason: 'missing-comment' | 'untracked-thread' }
  | { status: 'queued'; record: QueuedComment };

function toIso(value: unknown): string | undefined {
  if (value == null) return undefined;

  const date = value instanceof Date ? value : new Date(value as string | number);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

/**
 * Convert a Devvit CommentCreate trigger payload into TradeFlair's normalized
 * queue record. This function intentionally performs no Redis or HTTP I/O so
 * the event contract can be unit tested independently.
 */
export function normalizeCommentCreate(
  input: OnCommentCreateRequest,
  observedAt = new Date()
): CommentIngestResult {
  const comment = input.comment;
  const subreddit = input.subreddit;

  if (!comment?.id || !comment.postId) {
    return { status: 'ignored', reason: 'missing-comment' };
  }

  if (!isTrackedTradeThread(subreddit?.name, comment.postId)) {
    return { status: 'ignored', reason: 'untracked-thread' };
  }

  return {
    status: 'queued',
    record: {
      eventType: 'CommentCreate',
      commentId: comment.id,
      postId: comment.postId,
      parentId: comment.parentId,
      subredditId: subreddit?.id ?? comment.subredditId,
      subredditName: subreddit?.name,
      authorId: input.author?.id,
      authorName: input.author?.username,
      body: comment.body,
      permalink: comment.permalink,
      createdAt: toIso(comment.createdAt),
      observedAt: observedAt.toISOString(),
    },
  };
}
