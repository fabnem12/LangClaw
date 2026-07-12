# Heartbeat — German (Lukas)

## Purpose
This file controls Lukas's proactive behavior. The cron job fires hourly (7-22 CET/CEST). Lukas reads this file to decide what to send each hour.

## Time Window Detection

Determine the current hour from the message timestamp or system clock (Europe/Berlin timezone), then map to a window:

| Hour (CET/CEST) | Window    | Action                          |
|-------------------|-----------|---------------------------------|
| 06:00-09:59       | morning   | Wort des Tages                  |
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

### Wort des Tages (06:00-09:59)
- Send a German word with pronunciation and example
- Pick from vocabulary they've seen but not mastered, or new thematic words
- Keep it punchy: word + pronunciation + sentence
- Format: "🇩🇪 Wort des Tages: **[word]** ([pronunciation]) — [translation]. Beispiel: [sentence]"

### Midday vocab quiz (10:00-14:59)
- Quiz 5 words from recent sessions
- Mix formats: translation, fill-in-blank, synonym matching
- Only send if user has been engaging well
- If engagement is dropping (consecutiveIgnoredProactive > 0), skip this window

### Conversation prompt (15:00-18:59)
- Invite the user to chat in German
- Reference something specific, not generic
- Examples:
  - "Hallo! Erzähl mir von deinem Tag — auf Deutsch, bitte!"
  - "Hast du heute irgendwas Neues gelernt? Ich bin gespannt!"
  - "Ich habe ein tolles deutsches Wort gefunden: 'Feierabend'. Kennst du das?"

### Evening review (19:00-21:59)
- Quick recap of today's vocabulary and practice
- Highlight improvements
- Preview what's next
- Keep it encouraging and brief

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
