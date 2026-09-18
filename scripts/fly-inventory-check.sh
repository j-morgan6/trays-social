#!/usr/bin/env bash
# Diff the real Fly.io account against docs/infra/fly-inventory.md.
#
# Exists because two $42/mo Managed Postgres clusters accumulated unnoticed for
# months — the monthly invoice was the only place they were recorded. Run this
# monthly, or after any infra change.
#
#   ./scripts/fly-inventory-check.sh
#
# Exits non-zero if reality contains something this project does not expect.

set -uo pipefail

FLY=${FLY:-fly}
fail=0

EXPECTED_APPS="trays-social trays-social-db trays-social-review trays-social-review-pg"
# Managed Postgres is being retired. Any cluster at all is a finding until the
# two known ones are destroyed; after that, any cluster is an unexpected $42/mo.
EXPECTED_MPG=""

note() { printf '  %s\n' "$*"; }
head() { printf '\n== %s ==\n' "$*"; }

head "Apps"
actual_apps=$($FLY apps list 2>/dev/null | awk 'NR>1 && $1 !~ /^[-=]/ {print $1}' | grep -v '^NAME$' | sort)
for a in $actual_apps; do
  case " $EXPECTED_APPS " in
    *" $a "*) note "ok        $a" ;;
    *)        note "UNEXPECTED $a  <-- not in docs/infra/fly-inventory.md"; fail=1 ;;
  esac
done
for e in $EXPECTED_APPS; do
  grep -qx "$e" <<<"$actual_apps" || { note "MISSING   $e  <-- expected but not found"; fail=1; }
done

head "Managed Postgres clusters (\$42.16/mo each)"
mpg=$($FLY mpg list -o personal 2>/dev/null | awk 'NR>1 && $1 !~ /^[-=]/ {print $1}' | grep -v '^ID$' || true)
if [ -z "$mpg" ]; then
  note "none — good"
else
  for c in $mpg; do note "BILLING   $c  <-- \$42.16/mo, confirm it is still needed"; fail=1; done
  note ""
  note "NOTE: the ATTACHED APPS column is unreliable on this account."
  note "Verify with: fly ssh console -a <app> -C 'printenv DATABASE_URL'"
fi

head "Which database each app actually uses"
for app in trays-social trays-social-review; do
  url=$($FLY ssh console -a "$app" -C 'printenv DATABASE_URL' 2>/dev/null \
        | tr -d '\r' | grep '^postgres' | sed -E 's#://[^@]*@#://REDACTED@#')
  note "${app}: ${url:-<could not read — is the machine running?>}"
done

head "Volumes"
for app in $EXPECTED_APPS; do
  $FLY volumes list -a "$app" 2>/dev/null \
    | awk -v a="$app" 'NR>1 && $1 ~ /^vol_/ {print "  " a ": " $5 " " $7}'
done

printf '\n'
if [ "$fail" -ne 0 ]; then
  echo "FINDINGS ABOVE — reconcile them, then update docs/infra/fly-inventory.md"
else
  echo "Inventory matches docs/infra/fly-inventory.md"
fi
exit $fail
