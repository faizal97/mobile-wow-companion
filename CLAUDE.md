# WoW Warband Companion

## Cloudflare Worker — CRITICAL

**NEVER run `npx wrangler deploy` from the project root.** There is a `wrangler.jsonc` at root for static web hosting (`mobile-wow-companion` worker) and a separate `worker/wrangler.toml` for the auth proxy (`wow-companion-auth` worker). Running wrangler from the wrong directory will deploy the wrong thing and can wipe Worker secrets (BNET_CLIENT_ID, BNET_CLIENT_SECRET).

**To deploy the auth/news Worker:**
```bash
cd worker && npx wrangler deploy --config wrangler.toml
```

**To clear KV cache keys:**
```bash
cd worker && npx wrangler kv key delete "KEY_NAME" --namespace-id=9a579130311a464dbff60b223c19fd64 --remote --config wrangler.toml
```

**After any Worker deploy, verify secrets are still set:**
```bash
cd worker && npx wrangler secret list --config wrangler.toml
```

If secrets are missing, re-set them:
```bash
npx wrangler secret put BNET_CLIENT_ID --config wrangler.toml
npx wrangler secret put BNET_CLIENT_SECRET --config wrangler.toml
```

## Local Development

Always use `./run_dev.sh` to run the app locally — it loads secrets from `.env` and passes `--dart-define` flags. Running `flutter run` directly will result in empty config values and broken auth.

## Stack

- Flutter/Dart, Provider for state management
- Rajdhani + Inter fonts, dark theme with WoW class-colored accents
- Cloudflare Worker at `wow-companion-auth.fayz.workers.dev` for auth proxy, commodity prices, Wago DB2 proxy, and news aggregation
