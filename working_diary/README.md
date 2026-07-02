# Working Diary

Chronological engineering log for the AutoBoat project — daily development and
field-test notes, decision history, audit trails, and troubleshooting records.
**Not** the canonical user documentation.

## Audience

Maintainer continuity (resuming after weekends / holidays / power outages),
supervisor and reviewer context (decisions captured with reasoning at the time
they were made), and future-self debugging or revisiting a choice months later.

## What's in here

- Daily development logs — what landed, what broke, what's blocked.
- Scoping plans for upcoming days / weeks.
- Field-test scaffolds and outcomes (Block A → Block F structure for test days).
- Audit trails (how decisions were verified, what alternatives were rejected).
- Troubleshooting records (symptom → root cause → fix → verification).

## What's NOT in here

Reference documentation. For polished docs go to:

- **[../README.md](../README.md)** — project overview, install, quick start.
- **[../USER_MANUAL.md](../USER_MANUAL.md)** — full usage manual.
- **[../Board.md](../Board.md)** — phase status, milestone timeline, technical debt.
- **[../wiki/](../wiki/)** — design rationale, architecture, troubleshooting, roadmap.

## File naming

`YYYY-MM-DD_<topic>.md` for single-day entries;
`YYYY-MM-DD_to_YYYY-MM-DD_<topic>.md` for multi-day scope plans. Files sort
chronologically because of the date prefix.

## Reading order

Each entry is self-contained — start with whichever date is relevant.
Cross-references between entries are explicit when they matter.

## Editing convention

Past entries are frozen: corrections happen in a new entry that points back to
the prior one. Only the current day's entry is open for free editing.

## Archiving

The diary spans the current internship workstream. Older entries may be
archived or summarized at end-of-internship or mid-review checkpoints; no
automatic rollover is in place.

---

Last updated: 02/07/2026
