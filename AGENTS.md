# Recipes

Server setup recipes. One folder per role (e.g. `home-server/`).

## Structure

```
apply-secrets.sh          # Repo-wide: envsubst on *.tpl files from a secrets.env
<recipe>/
  secrets.env.example     # Lists required secrets (not checked in when filled)
  setup.sh                # Installs packages, creates dirs, starts services
  <stack>/
    docker-compose.yml    # Uses ${VAR} interpolation from .env
    .env                  # Non-secret config (ports, timezone, UIDs). Checked into git.
    **/*.tpl              # Secret templates processed by apply-secrets.sh
```

## Conventions

- **`.env`** files contain non-secret, per-stack config. Checked into git.
- **`secrets.env`** contains credentials/tokens. Never committed. Create from `secrets.env.example`.
- **`*.tpl`** files use `${VAR}` syntax. `apply-secrets.sh` replaces only variables defined in `secrets.env`, outputs to the same path minus `.tpl`.
- **`setup.sh`** is idempotent where possible. Interactive steps (passwords, auth) are at the end.

## Adding a recipe

1. Create a folder: `mkdir my-server`
2. Add `secrets.env.example` listing required secrets
3. Add stack subdirectories with `docker-compose.yml` + `.env`
4. Add `*.tpl` files for anything that needs secrets injected
5. Add `setup.sh` to orchestrate installation
