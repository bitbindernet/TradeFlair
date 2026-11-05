import assert from 'node:assert/strict';
import test from 'node:test';
import { getTrackedSubreddit, isTrackedTradeThread } from './config';

test('matches subreddit names case-insensitively', () => {
  assert.equal(getTrackedSubreddit('currencytradingcards')?.name, 'Currencytradingcards');
});

test('accepts the configured Currencytradingcards trade thread', () => {
  assert.equal(isTrackedTradeThread('Currencytradingcards', 't3_1456rzb'), true);
});

test('rejects comments on unrelated posts', () => {
  assert.equal(isTrackedTradeThread('Currencytradingcards', 't3_nottracked'), false);
});

test('rejects unconfigured subreddits', () => {
  assert.equal(isTrackedTradeThread('example', 't3_1456rzb'), false);
});
