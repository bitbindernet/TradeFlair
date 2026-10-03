import { Hono } from 'hono';
import { serve } from '@hono/node-server';
import { createServer, getServerPort } from '@devvit/web/server';
import type {
  OnCommentCreateRequest,
  OnCommentDeleteRequest,
  TriggerResponse,
} from '@devvit/web/shared';
import { isTrackedTradeThread } from './config';
import {
  enqueueComment,
  getPendingCount,
  removeStoredBodyAndQueueDeletion,
} from './outbox';

const app = new Hono();

function toIso(value: unknown): string | undefined {
  if (value == null) return undefined;
  const date = value instanceof Date ? value : new Date(value as string | number);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

app.post('/internal/triggers/on-comment-create', async (c) => {
  const input = await c.req.json<OnCommentCreateRequest>();
  const comment = input.comment;
  const subreddit = input.subreddit;

  if (!comment?.id || !comment.postId) {
    return c.json<TriggerResponse>({ status: 'ok' });
  }

  if (!isTrackedTradeThread(subreddit?.name, comment.postId)) {
    return c.json<TriggerResponse>({ status: 'ok' });
  }

  await enqueueComment({
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
    observedAt: new Date().toISOString(),
  });

  console.log(
    `[TradeFlair] queued ${comment.id} from r/${subreddit?.name}; pending=${await getPendingCount()}`
  );

  return c.json<TriggerResponse>({ status: 'ok' });
});

app.post('/internal/triggers/on-comment-delete', async (c) => {
  const input = await c.req.json<OnCommentDeleteRequest>();
  const subreddit = input.subreddit;

  if (!isTrackedTradeThread(subreddit?.name, input.postId)) {
    return c.json<TriggerResponse>({ status: 'ok' });
  }

  await removeStoredBodyAndQueueDeletion({
    eventType: 'CommentDelete',
    commentId: input.commentId,
    postId: input.postId,
    parentId: input.parentId,
    subredditId: subreddit?.id,
    subredditName: subreddit?.name,
    authorId: input.author?.id,
    authorName: input.author?.username,
    createdAt: toIso(input.createdAt),
    deletedAt: toIso(input.deletedAt),
    observedAt: new Date().toISOString(),
  });

  console.log(`[TradeFlair] queued deletion tombstone for ${input.commentId}`);
  return c.json<TriggerResponse>({ status: 'ok' });
});

serve({
  fetch: app.fetch,
  createServer,
  port: getServerPort(),
});
