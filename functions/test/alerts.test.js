"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const a = require("../alerts");

const SETTINGS = a.normaliseSettings({});

const TEAMS = {
  teamA: { name: "Afghanistan", players: [
    { id: "a1", name: "Rahmanullah Gurbaz" }, { id: "a2", name: "Ibrahim Zadran" },
    { id: "a9", name: "Rashid Khan" },
  ] },
  teamB: { name: "India", players: [
    { id: "b1", name: "Abhishek Sharma" }, { id: "b2", name: "Shubman Gill" },
    { id: "b9", name: "Jasprit Bumrah" },
  ] },
};

function score(runs, wickets, balls) {
  return { runs, wickets, overs: Math.floor(balls / 6), balls: balls % 6 };
}

function snap({ scores, innings = 1, batting = "teamA", target = null, stats = {}, status = "live", format = "T20" }) {
  return a.buildSnapshot({
    meta: { status, format, title: "Afghanistan vs India, 1st T20I", matchDate: "2026-09-13" },
    teams: TEAMS,
    scores,
    liveMatch: { innings, battingTeam: batting, target },
    playerStats: stats,
  });
}

/** Feed snapshots through scoreEvents + applyCap like the function does. */
function run(snaps, settings = SETTINGS, state = null) {
  const sent = [];
  for (const s of snaps) {
    const { events, base } = a.scoreEvents(state, s, settings);
    const capped = a.applyCap(events, state, settings, s.day);
    const sentKeys = { ...((state && state.sent) || {}) };
    for (const e of capped.send) for (const k of [e.key, ...(e.marks || [])]) sentKeys[k] = 1;
    state = { ...(state || {}), base, counts: capped.counts, sent: sentKeys, seenLive: true };
    sent.push(...capped.send);
  }
  return { sent, state };
}

test("first look only records a baseline", () => {
  const { sent, state } = run([snap({ scores: { teamA: score(120, 5, 90) } })]);
  assert.equal(sent.length, 0);
  assert.equal(state.base.runs.teamA, 120);
});

test("re-writing the same data never sends again", () => {
  const s1 = snap({ scores: { teamA: score(0, 0, 0) }, stats: { a1: { runs: 0, balls: 0 } } });
  const s2 = snap({ scores: { teamA: score(48, 0, 30) }, stats: { a1: { runs: 45, balls: 28 } } });
  const s3 = snap({ scores: { teamA: score(53, 0, 32) }, stats: { a1: { runs: 50, balls: 30 } } });
  const { sent } = run([s1, s2, s3, s3, s3]);
  assert.deepEqual(sent.map((e) => e.key), ["bat50_a1_teamA"]);
});

test("the old 'need just 4' spam: one close-finish alert per stage", () => {
  const snaps = [snap({ scores: { teamA: score(156, 8, 120), teamB: score(100, 3, 84) }, innings: 2, batting: "teamB",
    target: { runs: 157, runsNeeded: 57, ballsRemaining: 36 } })];
  // Runs dribble in; every update is a separate write.
  for (let b = 85, need = 56; b <= 118; b++, need -= 1.5) {
    const n = Math.max(1, Math.round(need));
    snaps.push(snap({ scores: { teamA: score(156, 8, 120), teamB: score(157 - n, 3, b) }, innings: 2, batting: "teamB",
      target: { runs: 157, runsNeeded: n, ballsRemaining: 120 - b } }));
  }
  const { sent } = run(snaps);
  const chase = sent.filter((e) => e.kind === "chase");
  assert.ok(chase.length <= 2, `got ${chase.map((e) => e.title)}`);
  assert.equal(new Set(chase.map((e) => e.key)).size, chase.length);
});

test("wicket of a set batter gets the big-wicket title and dismissal text", () => {
  const before = snap({ scores: { teamB: score(80, 1, 50) }, batting: "teamB",
    stats: { b1: { runs: 62, balls: 30, isOut: false }, a9: { wickets: 0 } } });
  const after = snap({ scores: { teamB: score(80, 2, 51) }, batting: "teamB",
    stats: { b1: { runs: 62, balls: 31, isOut: true, dismissal: "c Nabi b Rashid Khan" }, a9: { wickets: 1 } } });
  const { sent } = run([before, after]);
  assert.equal(sent.length, 1);
  assert.match(sent[0].title, /Abhishek Sharma/);
  assert.match(sent[0].title, /HUGE WICKET|GONE for 62/);
  assert.equal(sent[0].body, "Abhishek Sharma c Nabi b Rashid Khan 62(31) · IND 80/2 (8.3)");
  assert.equal(sent[0].type, "wicket");
});

test("'key' mode skips routine wickets, 'all' mode sends them", () => {
  const before = snap({ scores: { teamB: score(80, 1, 50) }, batting: "teamB", stats: { b2: { runs: 12, balls: 10 } } });
  const after = snap({ scores: { teamB: score(80, 2, 51) }, batting: "teamB",
    stats: { b2: { runs: 12, balls: 11, isOut: true, dismissal: "lbw b Rashid Khan" } } });
  assert.equal(run([before, after]).sent.length, 0);
  const all = run([before, after], a.normaliseSettings({ wickets: "all" })).sent;
  assert.equal(all.length, 1);
  assert.match(all[0].title, /LBW/);
});

test("three wickets in quick time is one collapse alert", () => {
  const stats = (outs) => Object.fromEntries(["a1", "a2", "a9"].map((id, i) =>
    [id, { runs: 5, balls: 6, isOut: i < outs, dismissal: "b Bumrah" }]));
  const snaps = [0, 1, 2, 3].map((w) =>
    snap({ scores: { teamA: score(30, w, 30 + w * 4) }, stats: stats(w) }));
  const { sent } = run(snaps, a.normaliseSettings({ wickets: "all" }));
  const collapse = sent.filter((e) => e.key.startsWith("collapse"));
  assert.equal(collapse.length, 1);
  assert.match(collapse[0].title, /Afghanistan/);
});

test("a duck is always news", () => {
  const before = snap({ scores: { teamA: score(0, 0, 0) }, stats: { a1: { runs: 0, balls: 0 } } });
  const after = snap({ scores: { teamA: score(0, 1, 1) }, stats: { a1: { runs: 0, balls: 1, isOut: true, dismissal: "b Bumrah" } } });
  const { sent } = run([before, after]);
  assert.match(sent[0].title, /GOLDEN DUCK/);
});

test("innings break announces the target once", () => {
  const s1 = snap({ scores: { teamA: score(150, 8, 119) } });
  const s2 = snap({ scores: { teamA: score(156, 8, 120) } });
  const s3 = snap({ scores: { teamA: score(156, 8, 120), teamB: score(0, 0, 0) }, innings: 2, batting: "teamB",
    target: { runs: 157, runsNeeded: 157, ballsRemaining: 120 } });
  const { sent } = run([s1, s2, s3]);
  const breaks = sent.filter((e) => e.kind === "innings_break");
  assert.equal(breaks.length, 1);
  assert.match(breaks[0].title, /India need 157/);
  assert.match(breaks[0].body, /Afghanistan finish on 156\/8 \(20\)/);
});

test("bulk sync (worker adopting a match mid-way) sends nothing", () => {
  const empty = snap({ scores: { teamA: score(0, 0, 0) } });
  const full = snap({ scores: { teamA: score(156, 8, 120), teamB: score(120, 3, 90) }, innings: 2, batting: "teamB",
    target: { runs: 157, runsNeeded: 37, ballsRemaining: 30 },
    stats: { b1: { runs: 82, balls: 32 } } });
  const { sent, state } = run([empty, full]);
  assert.equal(sent.length, 0);
  assert.equal(state.base.runs.teamB, 120);
});

test("an undo followed by the same wicket again is not sent twice", () => {
  const settings = a.normaliseSettings({ wickets: "all" });
  const s0 = snap({ scores: { teamA: score(40, 1, 40) }, stats: { a1: { runs: 20, balls: 15 } } });
  const s1 = snap({ scores: { teamA: score(40, 2, 41) }, stats: { a1: { runs: 20, balls: 16, isOut: true } } });
  const { sent } = run([s0, s1, s0, s1], settings);
  assert.equal(sent.filter((e) => e.kind === "wicket").length, 1);
});

test("cap stops routine alerts but never the result or innings break", () => {
  const settings = a.normaliseSettings({ maxPerMatch: 1 });
  const events = [
    { kind: "milestone", key: "m1" }, { kind: "milestone", key: "m2" },
    { kind: "innings_break", key: "break_2" },
  ];
  const { send } = a.applyCap(events, null, settings, 1);
  assert.deepEqual(send.map((e) => e.key), ["m1", "break_2"]);
});

test("alerts off still moves the baseline", () => {
  const off = a.normaliseSettings({ enabled: false });
  const s1 = snap({ scores: { teamA: score(10, 0, 10) } });
  const s2 = snap({ scores: { teamA: score(60, 0, 30) }, stats: {} });
  const { state } = run([s1, s2], off);
  assert.equal(state.base.runs.teamA, 60);
});

// ── document events ──────────────────────────────────────────────────────────

const DOC = (meta, toss = {}) => ({
  meta: { title: "Afghanistan vs India, 1st T20I", matchDate: "2026-09-13", format: "T20", ...meta },
  teams: TEAMS,
  toss: { wonBy: "", decision: "", ...toss },
});

test("toss alert before the first ball", () => {
  const before = DOC({ status: "upcoming" });
  const after = DOC({ status: "upcoming" }, { wonBy: "teamB", decision: "bowl" });
  assert.ok(a.docChangeMatters(before, after));
  const events = a.docEvents(before, after, null, SETTINGS, { ballsBowled: 0, isRecent: true });
  assert.equal(events.length, 1);
  assert.match(events[0].title, /India/);
  assert.match(events[0].title, /BOWL|Afghanistan to bat/);
});

test("no toss alert when a match is picked up mid-way", () => {
  const events = a.docEvents(DOC({ status: "live" }), DOC({ status: "live" }, { wonBy: "teamA", decision: "bat" }),
    null, SETTINGS, { ballsBowled: 90, isRecent: true });
  assert.equal(events.length, 0);
});

test("result needs the match to have been followed live", () => {
  const before = DOC({ status: "live" });
  const after = DOC({ status: "completed", resultText: "India won by 7 wkts" });
  assert.equal(a.docEvents(before, after, null, SETTINGS, {}).length, 0);
  const events = a.docEvents(before, after, { seenLive: true }, SETTINGS, { scoreLine: "AFG 156/8 (20) · IND 157/3 (17.2)" });
  assert.equal(events.length, 1);
  assert.match(events[0].title, /INDIA WIN|Victory for India/);
  assert.equal(events[0].body, "India won by 7 wkts · AFG 156/8 (20) · IND 157/3 (17.2)");
  assert.equal(events[0].type, "match_result");
  // Already sent for this match (e.g. data restored next day): capped out.
  assert.equal(a.applyCap(events, { sent: { result: 1 } }, SETTINGS, 1).send.length, 0);
});

test("close and big results get their own titles", () => {
  const closeT = a.docEvents(DOC({ status: "live" }), DOC({ status: "completed", resultText: "India won by 1 wkt" }),
    { seenLive: true }, SETTINGS, {})[0].title;
  assert.match(closeT, /FINISH|THRILLER/);
  const bigT = a.docEvents(DOC({ status: "live" }), DOC({ status: "completed", resultText: "India won by 120 runs" }),
    { seenLive: true }, SETTINGS, {})[0].title;
  assert.match(bigT, /CRUSH|Dominant/);
});

test("reaction writes are ignored before any read", () => {
  const d = DOC({ status: "live" });
  assert.equal(a.docChangeMatters(d, { ...d, reactions: { fire: 3 } }), false);
});

// ── helpers ──────────────────────────────────────────────────────────────────

test("helpers", () => {
  assert.equal(a.describeDismissal("c Nabi b Rashid").kind, "caught");
  assert.equal(a.describeDismissal("caught").text, "");
  assert.equal(a.describeDismissal("st Gurbaz b Rashid").kind, "stumped");
  assert.equal(a.describeDismissal("run out (Nabi)").kind, "runout");
  assert.equal(a.shortName("India Women"), "IND-W");
  assert.equal(a.shortName("Barbados Royals"), "BR");
  assert.equal(a.formatScore(score(157, 3, 104)), "157/3 (17.2)");
  assert.equal(a.matchKey(DOC({})), "afghanistan-vs-india-1st-t20i-2026-09-13");
  assert.equal(a.matchKey({}), "");
  assert.equal(a.parseResult("Australia won by an innings and 12 runs").unit, "innings");
  assert.equal(a.normaliseSettings({ maxPerMatch: 999, wickets: "bogus" }).maxPerMatch, 40);
  assert.equal(a.normaliseSettings({ wickets: "bogus" }).wickets, "key");
  assert.ok(a.isRecent("2026-09-14", new Date("2026-09-14T10:00:00Z")));
  assert.ok(!a.isRecent("2026-09-01", new Date("2026-09-14T10:00:00Z")));
});

test("a whole T20 stays within the cap", () => {
  // Afghanistan 156/8 in 20, India chase it down in 17.2 with two fifties.
  const snaps = [snap({ scores: { teamA: score(0, 0, 0) }, stats: {} })];
  for (let b = 1; b <= 120; b++) {
    const runs = Math.round(b * 1.3);
    const wk = Math.min(8, Math.floor(b / 15));
    snaps.push(snap({ scores: { teamA: score(runs, wk, b) } }));
  }
  const chaseStats = (b) => ({
    b1: { runs: Math.min(82, Math.round(b * 2.5)), balls: Math.min(32, b), isOut: b > 34, dismissal: "c Gurbaz b Rashid Khan" },
    b2: { runs: Math.round(b * 0.8), balls: b, isOut: false },
    a9: { wickets: b > 34 ? 1 : 0, runsConceded: 20, overs: 3 },
  });
  for (let b = 0; b <= 104; b++) {
    const runs = Math.min(157, Math.round(b * 1.51));
    snaps.push(snap({ scores: { teamA: score(156, 8, 120), teamB: score(runs, b > 34 ? 1 : 0, b) },
      innings: 2, batting: "teamB", stats: chaseStats(b),
      target: { runs: 157, runsNeeded: 157 - runs, ballsRemaining: 120 - b } }));
  }
  const { sent } = run(snaps);
  const capped = sent.filter((e) => !["toss", "innings_break", "result"].includes(e.kind));
  assert.ok(capped.length <= SETTINGS.maxPerMatch, `${capped.length} alerts`);
  assert.equal(new Set(sent.map((e) => e.key)).size, sent.length);
  assert.ok(sent.some((e) => e.kind === "innings_break"));
  assert.ok(sent.some((e) => /Abhishek Sharma/.test(e.title)));
});
