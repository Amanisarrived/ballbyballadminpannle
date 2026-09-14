"use strict";

// Match alerts: decides which push notifications a match deserves.
//
// Pure functions only, so the rules can be tested without Firebase. index.js
// reads the data, calls these, and writes the result in one transaction.
//
// How repeats are avoided: every alert has a key (`wkt_teamA_3`, `result`) and
// a match remembers the keys it has sent. Events are found by comparing the
// match with the last snapshot this code saw (`base`), not with the previous
// database write, so re-writing the same data never re-sends anything.

const DEFAULT_SETTINGS = Object.freeze({
  enabled: true,
  toss: true,
  wickets: "key", // "all" | "key" | "off"
  milestones: true, // batter 50/100, bowler hauls, team totals
  inningsBreak: true,
  chase: true, // close finishes
  result: true, // result, super over, stumps
  powerplay: false,
  maxPerMatch: 12, // per day of play; the alerts below never count
});

const UNCAPPED = new Set(["toss", "innings_break", "result", "super_over", "stumps"]);

// More than this many balls between two looks means the data was synced in
// bulk (a match adopted mid-way, the worker back after downtime): not news.
const MAX_STEP_BALLS = 24;

// Never more than this many alerts from one score update.
const MAX_PER_UPDATE = 2;

const RULES = {
  t20: { powerplayOvers: 6, teamTotals: [200, 250], fastFifty: 25, fastHundred: 50, hauls: [4, 5], thrillerBalls: 30, rate: [8, 16] },
  t10: { powerplayOvers: 0, teamTotals: [150], fastFifty: 20, fastHundred: 40, hauls: [3, 4], thrillerBalls: 18, rate: [10, 20] },
  odi: { powerplayOvers: 10, teamTotals: [300, 350, 400], fastFifty: 30, fastHundred: 70, hauls: [5], thrillerBalls: 60, rate: [6.5, 13] },
  test: { powerplayOvers: 0, teamTotals: [], fastFifty: 0, fastHundred: 0, hauls: [5], thrillerBalls: 0, rate: [0, 0] },
};

const SHORT_NAMES = {
  india: "IND", pakistan: "PAK", australia: "AUS", england: "ENG",
  "south africa": "SA", "new zealand": "NZ", "sri lanka": "SL",
  bangladesh: "BAN", afghanistan: "AFG", "west indies": "WI",
  zimbabwe: "ZIM", ireland: "IRE", netherlands: "NED", scotland: "SCO",
  nepal: "NEP", "united arab emirates": "UAE", oman: "OMA",
  "united states of america": "USA", namibia: "NAM", canada: "CAN",
  "chennai super kings": "CSK", "mumbai indians": "MI",
  "royal challengers bengaluru": "RCB", "kolkata knight riders": "KKR",
  "sunrisers hyderabad": "SRH", "delhi capitals": "DC", "punjab kings": "PBKS",
  "rajasthan royals": "RR", "gujarat titans": "GT", "lucknow super giants": "LSG",
};

// ── small helpers ────────────────────────────────────────────────────────────

function int(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}

function obj(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function sum(values) {
  return values.reduce((total, v) => total + int(v), 0);
}

/** Same key -> same variant, so a retried transaction sends identical text. */
function pick(options, seed) {
  let hash = 0;
  for (const ch of String(seed)) hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
  return options[hash % options.length];
}

function fill(template, values) {
  return template.replace(/\{(\w+)\}/g, (_, name) => (values[name] ?? "").toString());
}

function ordinal(n) {
  const rest = n % 100;
  if (rest >= 11 && rest <= 13) return `${n}th`;
  return `${n}${{ 1: "st", 2: "nd", 3: "rd" }[n % 10] || "th"}`;
}

function shortName(name) {
  const lower = String(name || "").toLowerCase().trim();
  if (!lower) return "";
  const women = lower.endsWith(" women");
  const base = women ? lower.slice(0, -6).trim() : lower;
  const short = SHORT_NAMES[base] ||
    base.split(/\s+/).filter(Boolean).map((w) => w[0].toUpperCase()).slice(0, 3).join("");
  return women ? `${short}-W` : short;
}

function formatInfo(format) {
  const f = String(format || "").toUpperCase();
  if (f.includes("TEST") || f.includes("FIRST")) return "test";
  if (f.includes("ODI") || f.includes("LIST") || f.includes("50")) return "odi";
  if (f.includes("T10")) return "t10";
  return "t20";
}

function ballsOf(score) {
  const s = obj(score);
  return int(s.overs) * 6 + int(s.balls);
}

function hasPlay(score) {
  const s = obj(score);
  return int(s.runs) + int(s.wickets) + ballsOf(s) > 0;
}

function formatScore(score) {
  const s = obj(score);
  const overs = int(s.balls) ? `${int(s.overs)}.${int(s.balls)}` : `${int(s.overs)}`;
  return `${int(s.runs)}/${int(s.wickets)} (${overs})`;
}

function normaliseSettings(raw) {
  const r = obj(raw);
  const out = { ...DEFAULT_SETTINGS };
  for (const flag of ["enabled", "toss", "milestones", "inningsBreak", "chase", "result", "powerplay"]) {
    if (typeof r[flag] === "boolean") out[flag] = r[flag];
  }
  if (["all", "key", "off"].includes(r.wickets)) out.wickets = r.wickets;
  if (r.maxPerMatch !== undefined) out.maxPerMatch = Math.min(40, Math.max(1, int(r.maxPerMatch)));
  return out;
}

/** Stable id for the featured match, shared by both triggers. */
function matchKey(doc) {
  const meta = obj(obj(doc).meta);
  const teams = obj(obj(doc).teams);
  const label = meta.title ||
    [obj(teams.teamA).name, obj(teams.teamB).name].filter(Boolean).join(" vs ");
  if (!label) return "";
  return `${label} ${meta.matchDate || ""}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 140);
}

// ── snapshot of the match ────────────────────────────────────────────────────

/** Score key of the innings `side` is batting: `teamA`, or `teamA_inn2` in Tests. */
function battingKey(scores, side, kind) {
  if (!side) return "";
  if (kind !== "test") return side;
  for (const key of [`${side}_inn2`, `${side}_inn1`]) {
    if (hasPlay(scores[key])) return key;
  }
  return `${side}_inn1`;
}

function buildSnapshot({ meta, teams, scores, liveMatch, playerStats } = {}) {
  const m = obj(meta);
  const t = obj(teams);
  const live = obj(liveMatch);
  const allScores = obj(scores);
  const kind = formatInfo(m.format);
  const batting = ["teamA", "teamB"].includes(live.battingTeam) ? live.battingTeam : "";
  const bowling = batting ? (batting === "teamA" ? "teamB" : "teamA") : "";

  const sides = {};
  const players = {};
  for (const side of ["teamA", "teamB"]) {
    const team = obj(t[side]);
    const name = team.name || (side === "teamA" ? "Team A" : "Team B");
    sides[side] = { name, short: shortName(name) || name };
    for (const p of Array.isArray(team.players) ? team.players : []) {
      if (p && p.id) players[String(p.id)] = { name: p.name || "", side };
    }
  }

  return {
    status: String(m.status || ""),
    kind,
    rules: RULES[kind],
    day: int(m.day) || 1,
    title: m.title || "",
    innings: int(live.innings) || 1,
    batting,
    bowling,
    battingKey: battingKey(allScores, batting, kind),
    teams: sides,
    scores: allScores,
    target: live.target && typeof live.target === "object" ? live.target : null,
    players,
    stats: obj(playerStats),
  };
}

function baseFrom(snap, previous) {
  const balls = {};
  const runs = {};
  const wkts = {};
  for (const [key, score] of Object.entries(snap.scores)) {
    if (!score || typeof score !== "object") continue;
    balls[key] = ballsOf(score);
    runs[key] = int(score.runs);
    wkts[key] = int(score.wickets);
  }
  const players = {};
  for (const [pid, st] of Object.entries(snap.stats)) {
    if (!st || typeof st !== "object") continue;
    players[pid] = { r: int(st.runs), o: st.isOut === true, w: int(st.wickets) };
  }
  return {
    innings: snap.innings,
    batting: snap.batting,
    balls,
    runs,
    wkts,
    players,
    falls: obj(previous && previous.falls),
  };
}

function totalBalls(snap) {
  return sum(Object.values(snap.scores).map(ballsOf));
}

function scoreLine(snap) {
  const parts = [];
  for (const side of ["teamA", "teamB"]) {
    const key = snap.kind === "test" ? battingKey(snap.scores, side, "test") : side;
    if (hasPlay(snap.scores[key])) parts.push(`${snap.teams[side].short} ${formatScore(snap.scores[key])}`);
  }
  return parts.join(" · ");
}

/** "7 fours, 7 sixes"; blank when the scorer didn't record boundaries. */
function boundaries(st) {
  const parts = [];
  if (int(st.fours)) parts.push(`${int(st.fours)} four${int(st.fours) === 1 ? "" : "s"}`);
  if (int(st.sixes)) parts.push(`${int(st.sixes)} six${int(st.sixes) === 1 ? "" : "es"}`);
  return parts.join(", ");
}

function chaseText(snap) {
  const t = snap.target;
  if (!t || snap.kind === "test" || snap.innings < 2) return "";
  const need = int(t.runsNeeded);
  const left = int(t.ballsRemaining);
  return need > 0 && left > 0 ? ` · Need ${need} off ${left}` : "";
}

// ── dismissals ───────────────────────────────────────────────────────────────

const MANUAL_DISMISSALS = new Set(["bowled", "caught", "lbw", "run out", "stumped", "hit wicket"]);

/** Worker gives Cricbuzz text ("c Rashid b Naveen"); the panel gives a type. */
function describeDismissal(text) {
  const raw = String(text || "").trim();
  const l = raw.toLowerCase();
  let kind = "out";
  if (l.startsWith("retired")) kind = "retired";
  else if (l.startsWith("run out")) kind = "runout";
  else if (l.startsWith("lbw")) kind = "lbw";
  else if (l.startsWith("st ") || l === "stumped") kind = "stumped";
  else if (l.startsWith("c ") || l.startsWith("c&b") || l === "caught") kind = "caught";
  else if (l.startsWith("b ") || l === "bowled") kind = "bowled";
  else if (l.includes("hit wicket")) kind = "hitwicket";
  return { kind, text: MANUAL_DISMISSALS.has(l) ? "" : raw };
}

const WICKET_TITLES = {
  caught: ["CAUGHT! {name} has to walk ☝️", "Taken! {name} holes out ☝️"],
  bowled: ["BOWLED! {name}'s stumps go flying 🎯", "Timber! {name} is cleaned up 🎯"],
  lbw: ["PLUMB! {name} trapped LBW ☝️", "Finger goes up! {name} out LBW ☝️"],
  runout: ["RUN OUT! {name} short of the crease 🏃", "Direct hit! {name} run out 🎯"],
  stumped: ["STUMPED! {name} beaten by the keeper 🧤", "Lightning glovework! {name} stumped 🧤"],
  hitwicket: ["HIT WICKET! {name} treads on the stumps 😬"],
  out: ["WICKET! {name} departs 🎯", "OUT! {name} has to go 🎯"],
};

// ── score events ─────────────────────────────────────────────────────────────

function event(kind, key, title, body, extra = {}) {
  return { kind, key, title, body, ...extra };
}

function wicketEvents(base, next, snap, settings) {
  const key = snap.battingKey;
  const score = obj(snap.scores[key]);
  const prevW = int(base.wkts[key]);
  const nowW = int(score.wickets);
  if (!key || nowW <= prevW) return [];

  const ballsNow = ballsOf(score);
  const falls = [...(Array.isArray(base.falls[key]) ? base.falls[key] : [])];
  for (let i = prevW; i < nowW; i++) falls.push(ballsNow);
  next.falls = { ...base.falls, [key]: falls.slice(-10) };
  if (settings.wickets === "off") return [];

  const team = snap.teams[snap.batting];
  const line = `${team.short} ${formatScore(score)}${chaseText(snap)}`;
  const marks = [];
  for (let w = prevW + 1; w < nowW; w++) marks.push(`wkt_${key}_${w}`);

  // Batters who were not out at the last look, on the batting side.
  const gone = Object.entries(snap.stats)
    .filter(([pid, st]) => st && st.isOut === true && !(base.players[pid] && base.players[pid].o))
    .filter(([pid]) => !snap.players[pid] || snap.players[pid].side === snap.batting)
    .map(([pid, st]) => ({ pid, st, name: (snap.players[pid] || {}).name || "", how: describeDismissal(st.dismissal) }))
    .filter((p) => p.how.kind !== "retired");

  const recent = falls.filter((b) => ballsNow - b <= 18).length;
  if (recent >= 3 && nowW >= 3) {
    const latest = gone.find((p) => p.name);
    return [event("wicket", `collapse_${key}`, pick([
      "COLLAPSE! {team} lose 3 wickets in a flash 📉",
      "{team} in BIG trouble! 3 quick wickets 📉",
    ], `collapse_${key}`).replace("{team}", team.name),
    latest ? `${latest.name} the latest to go · ${line}` : line,
    { marks: [...marks, `wkt_${key}_${nowW}`], type: "wicket" })];
  }

  if (nowW - prevW >= 2) {
    return [event("wicket", `wkt_${key}_${nowW}`,
      pick(["DOUBLE STRIKE! {team} lose 2 quick wickets ⚡", "Two in two! {team} rocked ⚡"], `wkt_${key}_${nowW}`)
        .replace("{team}", team.name),
      line, { marks, type: "wicket" })];
  }

  const batter = gone.length === 1 ? gone[0] : null;
  const chasePressure = Boolean(snap.target && snap.innings >= 2 && snap.rules.thrillerBalls &&
    int(snap.target.ballsRemaining) <= snap.rules.thrillerBalls && int(snap.target.runsNeeded) > 0);
  const eventKey = `wkt_${key}_${nowW}`;

  if (!batter || !batter.name) {
    if (settings.wickets === "key" && !chasePressure) return [];
    return [event("wicket", eventKey, `WICKET! ${team.name} lose their ${ordinal(nowW)} 🎯`, line, { type: "wicket" })];
  }

  const runs = int(batter.st.runs);
  const balls = int(batter.st.balls);
  const important = runs >= 30 || runs === 0 || chasePressure;
  if (settings.wickets === "key" && !important) return [];

  let titles;
  if (runs >= 50) titles = ["HUGE WICKET! {name} falls for {runs} 😱", "{name} is GONE for {runs}! Massive blow 💥"];
  else if (runs >= 30) titles = ["BIG WICKET! {name} out for {runs} 💥", "Breakthrough! {name} departs for {runs} 🎯"];
  else if (runs === 0 && balls === 1) titles = ["GOLDEN DUCK! 🦆 {name} gone first ball"];
  else if (runs === 0) titles = ["DUCK! 🦆 {name} out for 0", "No luck today! {name} out for a duck 🦆"];
  else titles = WICKET_TITLES[batter.how.kind] || WICKET_TITLES.out;

  const how = batter.how.text ? `${batter.how.text} ` : "";
  return [event("wicket", eventKey, fill(pick(titles, eventKey), { name: batter.name, runs }),
    `${batter.name} ${how}${runs}(${balls}) · ${line}`, { type: "wicket" })];
}

function milestoneEvents(base, snap) {
  const key = snap.battingKey;
  if (!key) return [];
  const team = snap.teams[snap.batting];
  const score = obj(snap.scores[key]);
  const line = `${team.short} ${formatScore(score)}${chaseText(snap)}`;
  const events = [];

  for (const [pid, st] of Object.entries(snap.stats)) {
    const before = base.players[pid];
    const info = snap.players[pid];
    if (!before || !st || typeof st !== "object" || !info || !info.name) continue;

    // Batter: the highest landmark crossed since the last look.
    if (info.side === snap.batting) {
      const runs = int(st.runs);
      const balls = int(st.balls);
      const mark = [200, 150, 100, 50].find((t) => before.r < t && runs >= t);
      if (mark) {
        const k = `bat${mark}_${pid}_${key}`;
        let titles;
        if (mark === 50 && snap.rules.fastFifty && balls && balls <= snap.rules.fastFifty) {
          titles = ["{name} SMASHES a {balls}-ball fifty 🔥", "What a knock! {balls}-ball FIFTY for {name} 🔥"];
        } else if (mark === 50) {
          titles = ["FIFTY! {name} brings up 50 🏏", "Half-century for {name}! Raise the bat 🏏"];
        } else if (mark === 100 && snap.rules.fastHundred && balls && balls <= snap.rules.fastHundred) {
          titles = ["{name} hits a blistering {balls}-ball HUNDRED 💯"];
        } else if (mark === 100) {
          titles = ["CENTURY! 💯 Take a bow, {name}", "{name} reaches a magnificent HUNDRED 💯"];
        } else if (mark === 150) {
          titles = ["{name} marches past 150 🚀"];
        } else {
          titles = ["DOUBLE HUNDRED! {name} reaches 200 👑"];
        }
        events.push(event("milestone", k, fill(pick(titles, k), { name: info.name, balls }),
          [`${info.name} ${runs}(${balls})`, boundaries(st), line].filter(Boolean).join(" · "),
          { type: "score_update", rank: mark }));
      }
    }

    // Bowler: a 4 or 5 wicket haul.
    if (info.side === snap.bowling) {
      const wickets = int(st.wickets);
      const haul = [...snap.rules.hauls].reverse().find((t) => before.w < t && wickets >= t);
      if (haul) {
        const k = `haul${haul}_${pid}_${key}`;
        const titles = haul >= 5
          ? ["FIVE-FOR! {name} runs through {team} 🔥", "{name} grabs FIVE! What a spell 🔥"]
          : haul === 4
            ? ["{name} takes FOUR! {team} in trouble 🔥"]
            : ["{name} strikes THREE times! 🔥"];
        const overs = int(st.ballsBowled) ? `${int(st.overs)}.${int(st.ballsBowled)}` : `${int(st.overs)}`;
        events.push(event("milestone", k, fill(pick(titles, k), { name: info.name, team: team.name }),
          `${info.name} ${wickets}/${int(st.runsConceded)} (${overs} ov) · ${line}`,
          { type: "score_update", rank: 60 + haul }));
      }
    }
  }

  // Team totals.
  const runsNow = int(score.runs);
  const total = [...snap.rules.teamTotals].reverse().find((t) => int(base.runs[key]) < t && runsNow >= t);
  if (total) {
    const k = `team${total}_${key}`;
    events.push(event("milestone", k,
      fill(pick(["{total} UP! {team} going BIG 🚀", "{team} cross {total}! Fireworks 🎆"], k), { total, team: team.name }),
      line, { type: "score_update", rank: 40 }));
  }
  return events.sort((a, b) => b.rank - a.rank);
}

function inningsBreakEvents(base, snap) {
  if (snap.kind === "test") {
    if (snap.innings <= base.innings || !snap.batting) return [];
    const k = `break_${snap.innings}`;
    return [event("innings_break", k, `Innings break ⏸️ ${snap.teams[snap.batting].name} to bat`,
      scoreLine(snap), { type: "score_update" })];
  }

  // Limited overs: the first innings is over when the chase starts, or as soon
  // as the side batting first is bowled out or runs out of overs.
  const limit = { t20: 120, t10: 60, odi: 300 }[snap.kind];
  let first = "";
  let target = 0;
  if (snap.innings >= 2 && base.innings < 2 && snap.bowling) {
    first = snap.bowling;
    target = int(obj(snap.target).runs) || int(obj(snap.scores[first]).runs) + 1;
  } else if (snap.innings === 1 && snap.batting) {
    const now = obj(snap.scores[snap.batting]);
    const was = { w: int(base.wkts[snap.batting]), b: int(base.balls[snap.batting]) };
    const ended = (int(now.wickets) >= 10 && was.w < 10) || (ballsOf(now) >= limit && was.b < limit);
    if (ended) {
      first = snap.batting;
      target = int(now.runs) + 1;
    }
  }
  if (!first) return [];
  const chasing = first === "teamA" ? "teamB" : "teamA";
  const k = "break_2";
  return [event("innings_break", k,
    fill(pick(["{team} need {target} to win 🎯", "Target set! {team} need {target} 🎯"], k),
      { team: snap.teams[chasing].name, target }),
    `${snap.teams[first].name} finish on ${formatScore(snap.scores[first])}. Who wins this? Follow the chase live.`,
    { type: "score_update" })];
}

function chaseEvents(snap, sent) {
  const t = snap.target;
  if (!t || snap.kind === "test" || snap.innings < 2 || !snap.battingKey) return [];
  const need = int(t.runsNeeded);
  const left = int(t.ballsRemaining);
  const score = obj(snap.scores[snap.battingKey]);
  const wicketsLeft = 10 - int(score.wickets);
  if (need <= 0 || left <= 0 || wicketsLeft <= 0) return [];
  const team = snap.teams[snap.batting];
  const tag = "chase";

  if (left <= 6 && need <= 24) {
    const k = "chase_last";
    return [event("chase", k,
      fill(pick(["LAST OVER DRAMA! {need} needed off {left} 😱", "{need} off {left}! Who holds their nerve? 😱"], k), { need, left }),
      `${team.name} ${formatScore(score)} · ${wicketsLeft} wicket${wicketsLeft === 1 ? "" : "s"} left`,
      { type: "score_update", tag })];
  }

  const rate = (need * 6) / left;
  const [low, high] = snap.rules.rate;
  if (!sent.chase_last && left <= snap.rules.thrillerBalls && rate >= low && rate <= high && wicketsLeft >= 2) {
    const k = "chase_thriller";
    return [event("chase", k,
      fill(pick(["GAME ON! {short} need {need} off {left} 🔥", "This is getting TENSE 😬 {need} needed off {left}"], k),
        { short: team.short, need, left }),
      `${team.name} ${formatScore(score)} · ${wicketsLeft} wickets in hand · Required rate ${rate.toFixed(2)}`,
      { type: "score_update", tag })];
  }
  return [];
}

function powerplayEvents(base, snap) {
  const overs = snap.rules.powerplayOvers;
  const key = snap.battingKey;
  if (!overs || !key) return [];
  const score = obj(snap.scores[key]);
  if (!(int(base.balls[key]) < overs * 6 && ballsOf(score) >= overs * 6)) return [];
  const team = snap.teams[snap.batting];
  return [event("powerplay", `pp_${key}`, `POWERPLAY DONE ⚡ ${team.short} ${int(score.runs)}/${int(score.wickets)}`,
    `${team.name} after ${overs} overs: ${formatScore(score)}${chaseText(snap)}`, { type: "score_update" })];
}

/**
 * Alerts for a score update.
 * Returns { events, base, reason } where `base` is the snapshot to remember.
 */
function scoreEvents(state, snap, settings) {
  const s = obj(state);
  const base = s.base;
  const next = baseFrom(snap, base);
  if (!base) return { events: [], base: next, reason: "baseline" };
  if (!snap.status.includes("live")) return { events: [], base: next, reason: "not live" };

  const was = sum(Object.values(obj(base.balls)));
  const now = totalBalls(snap);
  if (now < was || now - was > MAX_STEP_BALLS || snap.innings < int(base.innings)) {
    // An undo, another match in the slot, or a bulk catch-up: start over here.
    next.falls = {};
    return { events: [], base: next, reason: "resync" };
  }

  const sent = obj(s.sent);
  const b = { ...base, balls: obj(base.balls), runs: obj(base.runs), wkts: obj(base.wkts), players: obj(base.players), falls: obj(base.falls) };
  const events = [];
  if (settings.inningsBreak) events.push(...inningsBreakEvents(b, snap));
  events.push(...wicketEvents(b, next, snap, settings)); // always run: keeps the fall log
  if (settings.milestones) events.push(...milestoneEvents(b, snap));
  if (settings.chase) events.push(...chaseEvents(snap, sent));
  if (settings.powerplay) events.push(...powerplayEvents(b, snap));

  const fresh = events.filter((e) => !sent[e.key]);
  return { events: fresh.slice(0, MAX_PER_UPDATE), base: next, reason: fresh.length ? "events" : "quiet" };
}

// ── match document events: toss, super over, stumps, result ─────────────────

/** Cheap check before any reads: did a field these alerts use change? */
function docChangeMatters(before, after) {
  const b = obj(before);
  const a = obj(after);
  return obj(b.meta).status !== obj(a.meta).status ||
    obj(b.toss).wonBy !== obj(a.toss).wonBy ||
    obj(b.meta).superOver !== obj(a.meta).superOver;
}

/** matchDate ('YYYY-MM-DD', IST) is today or yesterday. Blank counts as recent. */
function isRecent(matchDate, now = new Date()) {
  if (!matchDate) return true;
  const ist = new Date(now.getTime() + 5.5 * 3600 * 1000);
  const today = ist.toISOString().slice(0, 10);
  const yesterday = new Date(ist.getTime() - 86400 * 1000).toISOString().slice(0, 10);
  const tomorrow = new Date(ist.getTime() + 86400 * 1000).toISOString().slice(0, 10);
  return [yesterday, today, tomorrow].includes(matchDate);
}

function parseResult(text) {
  const t = String(text || "");
  if (/abandon|no result|cancel/i.test(t)) return { kind: "no_result" };
  if (/\btied?\b/i.test(t) && !/won/i.test(t)) return { kind: "tie" };
  const won = t.match(/^(.+?)\s+won\b.*?\bby\s+(?:an\s+)?(innings|\d+)\s*(runs?|wkts?|wickets?)?/i);
  if (!won) return { kind: /won/i.test(t) ? "won" : "other", winner: "" };
  const unit = (won[3] || "").toLowerCase();
  return {
    kind: "won",
    winner: won[1].trim(),
    margin: won[2] === "innings" ? 0 : int(won[2]),
    unit: won[2] === "innings" ? "innings" : unit.startsWith("run") ? "runs" : "wickets",
  };
}

function docEvents(before, after, state, settings, ctx = {}) {
  const bm = obj(obj(before).meta);
  const am = obj(obj(after).meta);
  const s = obj(state);
  const teams = obj(obj(after).teams);
  const name = (side) => obj(teams[side]).name || side;
  const line = ctx.scoreLine ? ` · ${ctx.scoreLine}` : "";
  const events = [];
  const done = (status) => String(status || "").includes("complete");

  const tossBefore = obj(obj(before).toss).wonBy || "";
  const toss = obj(obj(after).toss);
  if (settings.toss && toss.wonBy && !tossBefore && ["teamA", "teamB"].includes(toss.wonBy) &&
      !ctx.ballsBowled && !done(am.status) && ctx.isRecent !== false) {
    const winner = name(toss.wonBy);
    const loser = name(toss.wonBy === "teamA" ? "teamB" : "teamA");
    const bat = toss.decision === "bat";
    events.push(event("toss", "toss",
      fill(pick(bat
        ? ["TOSS: {winner} will BAT first 🪙", "{winner} win the toss and choose to bat 🪙"]
        : ["TOSS: {winner} will BOWL first 🪙", "{winner} win the toss, {loser} to bat first 🪙"], `toss_${winner}`),
      { winner, loser }),
      `${am.title || `${name("teamA")} vs ${name("teamB")}`} · Every ball live on CricView`,
      { type: "score_update" }));
  }

  if (!s.seenLive) return events; // never alert on a match nobody watched live here

  if (settings.result && am.superOver === true && bm.superOver !== true) {
    events.push(event("super_over", "super_over", "SUPER OVER! 🤯 Scores are level",
      `${name("teamA")} and ${name("teamB")} can't be separated. One over each to decide it.`,
      { type: "score_update" }));
  }

  if (settings.result && am.status === "stumps" && bm.status !== "stumps") {
    const day = int(am.day) || 1;
    events.push(event("stumps", `stumps_d${day}`, `STUMPS on Day ${day} 🌙`,
      `${am.statusText || am.title || ""}${line}`.replace(/^ · /, ""), { type: "score_update" }));
  }

  if (settings.result && done(am.status) && !done(bm.status)) {
    const text = am.resultText || am.statusText || "";
    const r = parseResult(text);
    let titles;
    if (r.kind === "no_result") titles = ["Match abandoned 🌧️"];
    else if (r.kind === "tie") titles = ["IT'S A TIE! 🤯 What a game"];
    else if (r.kind === "won" && r.winner) {
      const close = r.unit === "runs" ? r.margin <= 5 : r.unit === "wickets" && r.margin <= 2;
      const big = r.unit === "innings" || (r.unit === "runs" && r.margin >= 100) || (r.unit === "wickets" && r.margin >= 9);
      if (close) titles = ["WHAT A FINISH! {winner} win it 🤯", "{winner} win a THRILLER! 🤯"];
      else if (big) titles = ["{winner} CRUSH the opposition! 🏆", "Dominant win for {winner} 🏆"];
      else titles = ["{WINNER} WIN! 🏆", "Victory for {winner}! 🏆"];
    } else titles = ["Match over 🏁"];
    const winner = r.winner || "";
    events.push(event("result", "result",
      fill(pick(titles, `result_${text}`), { winner, WINNER: winner.toUpperCase() }),
      `${text}${line}`.replace(/^ · /, ""), { type: "match_result" }));
  }
  return events;
}

// ── cap and queue ────────────────────────────────────────────────────────────

function applyCap(events, state, settings, day) {
  const s = obj(state);
  const sent = obj(s.sent);
  const counts = { ...obj(s.counts) };
  const slot = `d${day || 1}`;
  let used = int(counts[slot]);
  const send = [];
  for (const e of events) {
    if (sent[e.key] || send.some((x) => x.key === e.key)) continue;
    if (!UNCAPPED.has(e.kind)) {
      if (used >= settings.maxPerMatch) continue;
      used += 1;
    }
    send.push(e);
  }
  counts[slot] = used;
  return { send, counts };
}

function queuePayload(e, key) {
  return {
    title: e.title,
    body: e.body,
    imageUrl: null,
    type: e.type || "score_update",
    alert: e.kind,
    alertKey: e.key,
    matchKey: key,
    topic: "match_updates",
    source: "match_alerts",
    ...(e.tag ? { tag: `${key}_${e.tag}`.slice(0, 60) } : {}),
  };
}

module.exports = {
  DEFAULT_SETTINGS,
  MAX_STEP_BALLS,
  normaliseSettings,
  matchKey,
  shortName,
  formatScore,
  describeDismissal,
  parseResult,
  buildSnapshot,
  baseFrom,
  totalBalls,
  scoreLine,
  scoreEvents,
  docChangeMatters,
  docEvents,
  isRecent,
  applyCap,
  queuePayload,
};
