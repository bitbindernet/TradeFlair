import assert from 'node:assert/strict';
import test from 'node:test';
import type { OnCommentCreateRequest } from '@devvit/web/shared';
import { normalizeCommentCreate } from './ingest';

function event(overrides: Partial<OnCommentCreateRequest> = {}): OnCommentCreateRequest {
  return {
    comment: {
      id: 't1_comment123',
      postId: 't3_1456rzb',
      parentId: 't3_1456rzb',
      subredditId: 't5_currency',
      body: 'Confirmed trade with u/example',
      permalink: '/r/Currencytradingcards/comments/1456rzb/x/comment123/',
      createdAt: new Date('2026-11-04T23:00:00.000Z'),
    },
    subreddit: {
      id: 't5_currency',
      name: 'Currencytradingcards',
    },
    author: {
      id: 't2_example',
      username: 'example',
    },
    ...overrides,
  } as OnCommentCreateRequest;
}

test('normalizes a tracked CommentCreate event for the Redis outbox', () => {
  const result = normalizeCommentCreate(
    event(),
    new Date('2026-11-04T23:01:00.000Z')
  );

  assert.equal(result.status, 'queued');
  if (result.status !== 'queued') return;

  assert.deepEqual(result.record, {
    eventType: 'CommentCreate',
    commentId: 't1_comment123',
    postId: 't3_1456rzb',
    parentId: 't3_1456rzb',
    subredditId: 't5_currency',
    subredditName: 'Currencytradingcards',
    authorId: 't2_example',
    authorName: 'example',
    body: 'Confirmed trade with u/example',
    permalink: '/r/Currencytradingcards/comments/1456rzb/x/comment123/',
    createdAt: '2026-11-04T23:00:00.000Z',
    observedAt: '2026-11-04T23:01:00.000Z',
  });
});

test('ignores comments from posts that are not configured trade threads', () => {
  const input = event({
    comment: {
      ...event().comment,
      postId: 't3_some_other_post',
    },
  });

  assert.deepEqual(normalizeCommentCreate(input), {
    status: 'ignored',
    reason: 'untracked-thread',
  });
});

test('ignores CommentCreate payloads without a usable comment id/post id', () => {
  const input = event({ comment: undefined });

  assert.deepEqual(normalizeCommentCreate(input), {
    status: 'ignored',
    reason: 'missing-comment',
  });
});
