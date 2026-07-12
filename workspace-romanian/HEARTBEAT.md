# Heartbeat — Romanian (Ana)

## Purpose
This file controls Ana's proactive behavior. The cron job fires hourly (7-22 CET/CEST). Ana reads this file to decide what to send each hour.

## Time Window Detection

Determine the current hour from the message timestamp or system clock (Europe/Berlin timezone), then map to a window:

| Hour (CET/CEST) | Window    | Action                          |
|-------------------|-----------|---------------------------------|
| 06:00-09:59       | morning   | Word of the day                 |
| 10:00-14:59       | midday    | Vocab quiz (if engagement good) |
| 15:00-18:59       | afternoon | Conversation prompt             |
| 19:00-21:59       | evening   | Daily review                    |
| 22:00-05:59       | night     | Do nothing → HEARTBEAT_OK       |

## Rules

### Before sending anything
1. Read `progress/engagement.json`
2. If `consecutiveIgnoredProactive` >= 3, skip all proactive messages → reply HEARTBEAT_OK
3. If `sessionPatterns.avgLengthMin` < 3 for the last 7 days, reduce to morning-only (skip midday/afternoon/evening)
4. If engagement is high (>70% response rate), maintain full schedule

### Morning word (06:00-09:59)
- Send a Romanian word with a brief example sentence
- Reference something the user has struggled with, or introduce a new thematic word
- Keep it short: word + sentence + optional fun fact
- Format: "🇷🇴 Cuvântul zilei: **[word]** — [translation]. Exemplu: [sentence]"

### Midday vocab quiz (10:00-14:59)
- Quiz 5 words from recent sessions
- Use fill-in-the-blank or translation format
- Only send if user has been engaging well
- If engagement is dropping (consecutiveIgnoredProactive > 0), skip this window

### Conversation prompt (15:00-18:59)
- Invite the user to practice
- Reference a specific topic or something from their day
- Make it feel natural, not robotic
- Examples:
  - "Hey! Cum a fost ziua? Vrei să îmi povestești în română?"
  - "Am gândit la subiectul de ieri — ce părere ai despre [topic]?"

### Evening review (19:00-21:59)
- Quick recap of today's words and corrections
- Celebrate what went well
- Preview what's coming next session
- Keep it warm and brief

### Night (22:00-05:59)
- Never send proactive messages during this window
- Reply HEARTBEAT_OK

## Engagement Adaptation

- **High engagement** (70%+ response rate): send in all windows
- **Medium engagement** (40-70%): skip midday quiz, keep morning + afternoon + evening
- **Low engagement** (<40%): morning word only, skip everything else
- **Dropping engagement** (consecutiveIgnoredProactive > 0): back off proportionally
- **Streak active** (>3 days): you can be slightly more proactive
- **Streak broken**: be gentle, just the morning word until they re-engage
