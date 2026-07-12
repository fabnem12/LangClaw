#!/usr/bin/env node

/**
 * cron-stagger.js — Cron setup for LangClaw agents
 *
 * Generates one cron job per language that runs hourly (7-22 CET/CEST).
 * The agent reads HEARTBEAT.md and checks the current hour to decide
 * whether and what to send.
 *
 * Usage:
 *   node cron-stagger.js setup   # Print cron creation commands
 *   node cron-stagger.js check   # Show current time and active window
 */

const TZ = "Europe/Berlin";

const AGENTS = [
  { id: "romanian", name: "Ana" },
  { id: "german",   name: "Lukas" },
];

function getCurrentWindow() {
  const now = new Date();
  const hour = parseInt(now.toLocaleString("en-GB", { timeZone: TZ, hour: "numeric", hour12: false }));

  if (hour >= 6 && hour < 10) return "morning";
  if (hour >= 10 && hour < 15) return "midday";
  if (hour >= 15 && hour < 19) return "afternoon";
  if (hour >= 19 && hour < 22) return "evening";
  return "night";
}

function checkNow() {
  const now = new Date();
  const window = getCurrentWindow();
  const dateStr = now.toLocaleDateString("en-CA", { timeZone: TZ });
  const timeStr = now.toLocaleTimeString("en-GB", { timeZone: TZ, hour: "2-digit", minute: "2-digit" });

  console.log("=== LangClaw Cron Check ===\n");
  console.log(`  Date:     ${dateStr}`);
  console.log(`  Time:     ${timeStr} ${TZ}`);
  console.log(`  Window:   ${window}`);
  console.log();

  if (window === "night") {
    console.log("  No proactive messages during night window (22:00-06:00).");
  } else {
    console.log(`  Active window: ${window}`);
    console.log("  Agent will check HEARTBEAT.md and engagement.json to decide.");
  }
}

function generateSetup() {
  console.log("=== LangClaw Cron Setup Commands ===\n");
  console.log("# Run these commands after OpenClaw is installed and configured.\n");
  console.log("# Each agent gets ONE cron job running hourly from 7-22.");
  console.log("# The agent reads HEARTBEAT.md to decide what to send each hour.\n");

  for (const agent of AGENTS) {
    console.log(`# --- ${agent.name} (${agent.id}) ---`);
    console.log(`openclaw cron create "0 7-22 * * *"`);
    console.log(`  --name "LangClaw ${agent.name} hourly"`);
    console.log(`  --tz "${TZ}"`);
    console.log(`  --agent ${agent.id}`);
    console.log(`  --session isolated`);
    console.log(`  --message "HEARTBEAT_CHECK: Read HEARTBEAT.md. Determine the current hour and map it to a time window. Check progress/engagement.json for engagement state. Follow the rules in HEARTBEAT.md to decide whether to send a proactive message. If you should not send, reply HEARTBEAT_OK."`);
    console.log(`  --announce`);
    console.log(`  --to "discord:CHANNEL_ID_FOR_${agent.id.toUpperCase()}"`);
    console.log();
  }

  console.log("# After creating, replace CHANNEL_ID_FOR_ROMANIAN and CHANNEL_ID_FOR_GERMAN");
  console.log("# with your actual Discord channel IDs from .env");
  console.log();
  console.log("# To adjust the schedule, modify the cron expression above.");
  console.log("# Current: every hour from 7:00 to 22:00 (inclusive) in Europe/Berlin.");
}

// CLI
const [, , command] = process.argv;
switch (command) {
  case "check":
    checkNow();
    break;
  case "setup":
    generateSetup();
    break;
  default:
    console.log("Usage: node cron-stagger.js <check|setup>");
    console.log("  check   Show current time and active window");
    console.log("  setup   Print cron creation commands");
}
