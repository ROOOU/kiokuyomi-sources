# KiokuYomi Sources

This is a public, opt-in discovery and catalog mirror for declarative KiokuYomi
rule packages. It is maintained by the KiokuYomi developer; it is **not** an
independent third-party service. KiokuYomi does not bundle these sites, endorse
this repository in the app, or require anyone to use it.

The repository contains catalog metadata only. Each item points to a signed,
encrypted `.kyyrule` package hosted by the existing distribution service. A
newer collection may also include an optional `bundle` descriptor for one
HTTPS `.kyybundle` from that same service; it contains only URL, byte count,
and SHA-256 metadata. No comic content, source implementation, JavaScript,
Lua, Swift, executable plugin, account credential, Cookie, bypass token, or
private key is stored here.

## Add the catalog yourself

In KiokuYomi, choose the manual rule-collection import option and paste one of
the following addresses. Importing is a user-initiated action; review the
catalog and package permissions before accepting it.

- Primary (GitHub Pages, after Pages is enabled):
  `https://rooou.github.io/kiokuyomi-sources/all.json`
- Fallback (GitHub raw):
  `https://raw.githubusercontent.com/ROOOU/kiokuyomi-sources/main/all.json`

`sources.json` is a compatibility mirror of the same collection. The app
downloads each package over HTTPS and verifies the official package metadata
and signature; this GitHub mirror does not replace that verification.

## Repository boundary

- Only public catalog metadata is mirrored: ID, display name, content rating,
  HTTPS package URL, package size, and SHA-256.
- Rule packages remain on the stable distribution service; this repository
  deliberately does not duplicate the package files.
- Do not submit source code, executable plugins, credentials, keys, cookies,
  tokens, CAPTCHA/bypass material, or environment variables.
- Do not submit site-specific rules here. The catalog is generated from the
  official public collection, so pull requests that manually alter rule items
  will not be accepted.

## Updates and removal requests

The scheduled workflow fetches the two public catalog endpoints, validates
their schema and safety constraints, and commits only a real catalog change.
For copyright, trademark, privacy, or removal requests, open a private report
through the repository's security advisory/contact channel, or contact the
maintainer via the KiokuYomi project. Include the affected catalog ID and a
way to verify your authority. Requests do not require sharing account
credentials or copyrighted files.

## Development

Run `scripts/sync-catalog.sh` to download, validate, and update the two JSON
files. Run `scripts/sync-catalog.sh --check` to validate only the checked-in
files. The validator accepts the optional top-level `bundle` descriptor while
requiring its HTTPS `.kyybundle` URL, 1–32 MiB byte count, and SHA-256. It
rejects unexpected sensitive field names, duplicate IDs, non-HTTPS package
URLs, malformed hashes, schema/count mismatches, and a divergence between the
two mirrors.

This repository is an optional catalog mirror for KiokuYomi. It does not host
or serve comic content.
