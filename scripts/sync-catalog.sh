#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_BASE_URL="${UPSTREAM_BASE_URL:-https://sources.kiokuyomi.com}"
MODE="${1:-sync}"

if [[ "$MODE" != "sync" && "$MODE" != "--check" ]]; then
  echo "Usage: $0 [--check]" >&2
  exit 64
fi

validate_all_collection() {
  local file="$1"
  local label="$2"

  jq -e '
    def fail($message): error($message);
    def scalar_paths: paths(scalars);
    def forbidden_key:
      test("(^|[_-])(token|cookie|authorization|password|secret|access[_-]?key)([_-]|$)|private.*(key|secret)|aes.*(key|secret)|^(privateKey|private_key|aesKey|aes_key)$"; "i");
    if type != "object" then fail("root must be an object") else . end
    | if ([keys[]] - ["kind", "schemaVersion", "name", "catalogSequence", "releaseId", "count", "rules"] | length) == 0 then . else fail("unexpected top-level field") end
    | if .kind == "kiokuyomiRuleCollection" then . else fail("unexpected kind") end
    | if (.schemaVersion | type) == "number" then . else fail("schemaVersion must be numeric") end
    | if (.name | type) == "string" and (.name | length) > 0 then . else fail("name is required") end
    | if (.releaseId | type) == "string" and (.releaseId | length) > 0 then . else fail("releaseId is required") end
    | if (.catalogSequence | type) == "number" and .catalogSequence >= 0 then . else fail("catalogSequence is invalid") end
    | if (.count | type) == "number" and .count >= 0 then . else fail("count is invalid") end
    | if (.rules | type) == "array" and (.rules | length) == .count then . else fail("count does not match rules") end
    | if ([.rules[] | ([keys[]] - ["id", "name", "url", "packageBytes", "packageSha256", "contentRating"] | length == 0)] | all) then . else fail("unexpected rule field") end
    | if ([.rules[].id] | all(type == "string" and length > 0)) then . else fail("invalid rule id") end
    | if ([.rules[].id] | unique | length) == (.rules | length) then . else fail("duplicate rule id") end
    | if ([.rules[] | (.name | type == "string" and length > 0)] | all) then . else fail("invalid rule name") end
    | if ([.rules[] | (.url | type == "string" and test("^https://[^[:space:]]+\\.kyyrule$"))] | all) then . else fail("package URL must be HTTPS .kyyrule") end
    | if ([.rules[] | (.packageBytes | type == "number" and . > 0)] | all) then . else fail("invalid packageBytes") end
    | if ([.rules[] | (.packageSha256 | type == "string" and test("^[a-f0-9]{64}$"))] | all) then . else fail("invalid packageSha256") end
    | if ([.rules[] | (.contentRating as $rating | ["safe", "teen", "mature", "adult"] | index($rating) != null)] | all) then . else fail("invalid contentRating") end
    | if ([scalar_paths | select(.[-1] | type == "string" and forbidden_key)] | length) == 0 then . else fail("forbidden sensitive field name") end
  ' "$file" >/dev/null || {
    echo "Invalid $label catalog: $file" >&2
    exit 1
  }
}

validate_sources_collection() {
  local file="$1"
  jq -e '
    def fail($message): error($message);
    def scalar_paths: paths(scalars);
    def forbidden_key:
      test("private.*(key|secret)|aes.*(key|secret)|(auth|access|api|bearer)?.*token|.*cookie|authorization|password|secret"; "i");
    if type != "object" then fail("root must be an object") else . end
    | if ([keys[]] - ["schemaVersion", "count", "sources"] | length) == 0 then . else fail("unexpected top-level field") end
    | if (.schemaVersion | type) == "number" then . else fail("schemaVersion must be numeric") end
    | if (.count | type) == "number" and .count >= 0 then . else fail("count is invalid") end
    | if (.sources | type) == "array" and (.sources | length) == .count then . else fail("count does not match sources") end
    | if ([.sources[] | ([keys[]] - ["id", "name", "version", "description", "iconUrl", "languages", "baseUrl", "hostname", "sourceType", "contentKinds", "contentRating", "stability", "origin", "publicationTier", "requiresBrowserSession", "priority", "packageUrl", "stableRuleUrl", "packageBytes", "packageSha256", "releaseId", "catalogSequence", "encryptionKeyId", "signingKeyId"] | length == 0)] | all) then . else fail("unexpected source field") end
    | if ([.sources[].id] | all(type == "string" and length > 0)) then . else fail("invalid source id") end
    | if ([.sources[].id] | unique | length) == (.sources | length) then . else fail("duplicate source id") end
    | if ([.sources[] | (.name | type == "string" and length > 0)] | all) then . else fail("invalid source name") end
    | if ([.sources[] | (.packageUrl | type == "string" and test("^https://[^[:space:]]+\\.kyyrule$"))] | all) then . else fail("packageUrl must be HTTPS .kyyrule") end
    | if ([.sources[] | (.stableRuleUrl | type == "string" and test("^https://[^[:space:]]+$"))] | all) then . else fail("stableRuleUrl must be HTTPS") end
    | if ([.sources[] | (.packageBytes | type == "number" and . > 0)] | all) then . else fail("invalid packageBytes") end
    | if ([.sources[] | (.packageSha256 | type == "string" and test("^[a-f0-9]{64}$"))] | all) then . else fail("invalid packageSha256") end
    | if ([.sources[] | (.contentRating as $rating | ["safe", "teen", "mature", "adult"] | index($rating) != null)] | all) then . else fail("invalid contentRating") end
    | if ([.sources[] | (.requiresBrowserSession | type == "boolean")] | all) then . else fail("invalid requiresBrowserSession") end
    | if ([scalar_paths | select(.[-1] | type == "string" and forbidden_key)] | length) == 0 then . else fail("forbidden sensitive field name") end
  ' "$file" >/dev/null || {
    echo "Invalid sources catalog: $file" >&2
    exit 1
  }
}

validate_pair() {
  validate_all_collection "$1" "all"
  validate_sources_collection "$2"
  jq -e --slurpfile all "$1" --slurpfile sources "$2" '
    ($all[0]) as $allCatalog | ($sources[0]) as $sourceCatalog |
    if $allCatalog.count != $sourceCatalog.count then error("catalog counts diverge")
    elif ($allCatalog.rules | map(.id) | sort) != ($sourceCatalog.sources | map(.id) | sort) then error("catalog IDs diverge")
    elif ($allCatalog.rules | map({key: .id, value: .url}) | from_entries) as $allURLs
      | ($sourceCatalog.sources | all(.[]; $allURLs[.id] == .packageUrl)) then true
    else error("package URLs diverge") end
  ' -n >/dev/null || {
    echo "all.json and sources.json have inconsistent public metadata" >&2
    exit 1
  }
}

if [[ "$MODE" == "--check" ]]; then
  validate_pair "$ROOT_DIR/all.json" "$ROOT_DIR/sources.json"
  echo "Validated checked-in catalog ($(jq -r '.count' "$ROOT_DIR/all.json") rules)."
  exit 0
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kiokuyomi-catalog.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

for file in all.json sources.json; do
  curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 \
    --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 60 \
    "$UPSTREAM_BASE_URL/$file" -o "$TEMP_DIR/$file"
done

validate_pair "$TEMP_DIR/all.json" "$TEMP_DIR/sources.json"

for file in all.json sources.json; do
  if ! cmp -s "$TEMP_DIR/$file" "$ROOT_DIR/$file" 2>/dev/null; then
    cp "$TEMP_DIR/$file" "$ROOT_DIR/$file"
    echo "Updated $file"
  fi
done

echo "Synchronized validated catalog ($(jq -r '.count' "$TEMP_DIR/all.json") rules)."
