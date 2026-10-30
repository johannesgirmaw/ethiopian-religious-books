# Telegram auth bot (ops)

Free Bot API login / phone link / password-reset OTP / notifications.

## BotFather

1. Create a bot with [@BotFather](https://t.me/BotFather) (separate from the public support group).
2. Copy the token and username.
3. Do **not** put the token in the Flutter app or git.

## Production `.env.prod` (server only)

```
TELEGRAM_AUTH_BOT_TOKEN=<from BotFather>
TELEGRAM_AUTH_BOT_USERNAME=<bot_username_without_@>
TELEGRAM_AUTH_WEBHOOK_URL=https://api.felegemetsahft.com/v1/auth/telegram/webhook
TELEGRAM_AUTH_WEBHOOK_SECRET=<long random string>
TELEGRAM_AUTH_REQUIRE_WEBHOOK_SECRET=true
```

`docker-compose.prod.yml` sets `TELEGRAM_AUTH_REGISTER_WEBHOOK_ON_START=1` and `CACHE_URL` for the API service.

## Register webhook manually

```bash
cd /opt/felegemetsahft/prod
docker compose -f docker-compose.prod.yml exec api \
  python manage.py register_telegram_webhook
```

Return-to-app after Confirm my phone:

- The Flutter client sends `return_url` on initiate (`http://localhost:…/#/auth/telegram` locally, production app URL in release).
- The bot button uses a **public HTTPS** bounce: `…/v1/auth/telegram/return?session=…` (derived from `TELEGRAM_AUTH_WEBHOOK_URL`), which 302s to that `return_url` — Telegram rejects raw `localhost` button links.
- Fallback when no client URL: `TELEGRAM_AUTH_APP_RETURN_BASE=https://app.felegemetsahft.com/#/auth/telegram`

## Verify

1. `POST /v1/auth/telegram/initiate` (`purpose=login`, phone optional) → `bot_link`.
2. Open the link in Telegram → Confirm my phone (no OTP).
3. App polls `GET /v1/auth/telegram/session/<id>` then `POST /v1/auth/telegram/claim` → JWT or `needs_email`.
4. Linked users receive in-app notifications also as Telegram DMs.

## Nginx

Ensure `api.felegemetsahft.com` proxies `/v1/auth/telegram/webhook` to the API (same as other `/v1/` routes). No special path needed.
