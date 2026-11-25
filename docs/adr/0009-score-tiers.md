# Score tiers and accent folding

The ranking order is in `docs/design.md` "Matching and ranking". `Match.lua` keeps it with numbers:

- The tiers are `PREFIX` 3000, `INITIALS` 2000 and `FUZZY` 1000. Each tier beats every score of the tier below it, so the adjustments inside a tier must stay under 1000.
- Within a tier, a shorter name scores higher: `scoreNormalized` subtracts the name's length.
- `ns.boost` (history) gives at most 500, under one tier. History lifts a hit inside its tier and never above a better match type. `tests/match_test.lua` checks this.
- Accent folding covers Latin-1 letters only: UTF-8 characters with lead byte `0xC3`. `ACCENTS` maps the second byte minus `0x7F` to a plain letter. Every other non-ASCII character counts as punctuation, so it separates words.
