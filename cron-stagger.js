#!/usr/bin/env node

/**
 * cron-stagger.js — Generates staggered cron schedules for LangClaw agents
 *
 * This script creates cron job definitions with variable timing.
 * It uses a deterministic date-hash to pick which time slot fires each day,
 * so the same day always gets the same time, but different days vary.
 *
 * Usage:
 *   node cron-stagger.js setup          # Print all cron creation commands
 *   node cron-stagger.js check          # Show which slots fire today
 *   node cron-stagger.js trigger <slot> # Evaluate trigger for a slot (returns fire: true/false)
 */

const SLOT_WINDOWS = {
  morning:   { slots: ["6:45", "7:00", "7:15"],       tz: "Europe/Berlin" },
  midday:    { slots: ["11:30", "12:00", "12:30", "13:00"], tz: "Europe/Berlin" },
  afternoon: { slots: ["17:30", "18:00", "18:30"],    tz: "Europe/Berlin" },
  evening:   { slots: ["19:45", "20:00", "20:15"],    tz: "Europe/Berlin" },
};

const MORNING_LANGUAGES = ["Romanian", "German"]; // alternates by day

function dateHash(date) {
  const str = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash + str.charCodeAt(i)) | 0;
  }
  return Math.abs(hash);
}

function pickSlot(window, date) {
  const hash = dateHash(date);
  return window.slots[hash % window.slots.length];
}

function timeToMinuteOfDay(timeStr) {
  const [h, m] = timeStr.split(":").map(Number);
  return h * 60 + m;
}

function minuteOfDayToDate(minuteOfDay, tz) {
  const now = new Date();
  const [year, month, day] = now.toLocaleDateString("en-CA", { timeZone: tz }).split("-").map(Number);
  const h = Math.floor(minuteOfDay / 60);
  const m = minuteOfDay % 60;
  return new Date(year, month - 1, day, h, m, 0, 0);
}

function checkToday() {
  const now = new Date();
  console.log("=== LangClaw Cron Stagger — Today's Schedule ===\n");
  console.log(`Date: ${now.toLocaleDateString("en-CA", { timeZone: "Europe/Berlin" })}`);
  console.log(`Day hash: ${dateHash(now)}\n`);

  for (const [name, window] of Object.entries(SLOT_WINDOWS)) {
    const slot = pickSlot(window, now);
    const firingDate = minuteOfDayToDate(timeToMinuteOfDay(slot), window.tz);
    const isPast = now > firingDate;
    const langIdx = dateHash(now) % MORNING_LANGUAGES.length;
    const lang = name === "morning" ? MORNING_LANGUAGES[langIdx] : "(both agents)";
    console.log(`  ${name.padEnd(12)} → ${slot} CET/CEST  ${isPast ? "(passed)" : "(upcoming)"}  ${lang}`);
  }
}

function generateSetup() {
  const now = new Date();
  console.log("=== LangClaw Cron Setup Commands ===\n");
  console.log("# Run these commands after OpenClaw is installed and configured.\n");

  for (const [name, window] of Object.entries(SLOT_WINDOWS)) {
    for (let i = 0; i < window.slots.length; i++) {
      const [h, m] = window.slots[i].split(":");
      const cronExpr = `${m} ${h} * * *`;
      const langIdx = i % MORNING_LANGUAGES.length;
      const lang = MORNING_LANGUAGES[langIdx];

      console.log(`# --- ${name} slot ${i + 1}: ${window.slots[i]} (${lang}) ---`);
      console.log(`openclaw cron create "${cronExpr}"`
        + ` --name "LangClaw ${name} ${window.slots[i]}"`
        + ` --tz "${window.tz}"`
        + ` --agent ${lang.toLowerCase() === "romanian" ? "romanian" : "german"}`
        + ` --session isolated`
        + ` --message "HEARTBEAT_CHECK: Read HEARTBEAT.md and engagement.json. Decide whether to send a proactive message based on engagement patterns. If consecutiveIgnoredProactive >= 3, reply HEARTBEAT_OK."`
        + ` --announce`
        + ` --channel discord`);
      console.log();
    }
  }

  console.log("# Note: The trigger script (cron-stagger.js) handles which slot fires each day.");
  console.log("# Each slot's cron job fires daily, but the trigger script inside the agent's");
  console.log("# HEARTBEAT.md logic decides whether to actually send the message.");
  console.log("# Alternatively, use a single cron per window with a trigger script:");
  console.log();
  console.log("# === SIMPLER APPROACH: One cron per window with trigger ===");
  console.log("# For each window, create ONE cron job that fires at the earliest slot.");
  console.log("# Add a trigger script that checks if today is the right day.");
  console.log("# The agent's HEARTBEAT.md handles the engagement logic.");
}

function evaluateTrigger(slotName) {
  const window = SLOT_WINDOWS[slotName];
  if (!window) {
    console.error(`Unknown slot: ${slotName}. Use: ${Object.keys(SLOT_WINDOWS).join(", ")}`);
    process.exit(1);
  }
  const now = new Date();
  const todaySlot = pickSlot(window, now);
  const todayMinute = timeToMinuteOfDay(todaySlot);
  const nowMinute = now.getHours() * 60 + now.getMinutes();
  const isClose = Math.abs(nowMinute - todayMinute) <= 15;

  const result = {
    fire: isClose,
    date: now.toLocaleDateString("en-CA", { timeZone: "Europe/Berlin" }),
    slot: todaySlot,
    nowMinute,
    todayMinute,
    message: isClose
      ? `Firing ${slotName} at ${todaySlot} — slot matches today`
      : `Skipping — current time is not close to today's slot (${todaySlot})`,
  };

  console.log(JSON.stringify(result, null, 2));
}

// CLI
const [, , command, arg] = process.argv;
switch (command) {
  case "check":
    checkToday();
    break;
  case "setup":
    generateSetup();
    break;
  case "trigger":
    evaluateTrigger(arg);
    break;
  default:
    console.log("Usage: node cron-stagger.js <check|setup|trigger <slot>>");
    console.log("  check                  Show which slots fire today");
    console.log("  setup                  Print cron creation commands");
    console.log("  trigger <slot>         Evaluate trigger for a slot (morning|midday|afternoon|evening)");
}
