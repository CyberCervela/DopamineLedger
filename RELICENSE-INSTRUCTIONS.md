# Relicensing instruction set — DopamineLedger

**For:** Claude Code, executing in the `DopamineLedger` repo root.
**Goal:** Move from the current self-written CC BY-NC paraphrase to a clean,
**source-available** posture: code under **PolyForm Noncommercial 1.0.0**, prose
docs under **CC BY-NC 4.0**, commercial use available on request, and the
copyright consolidated so the project can be relicensed later (commercial deals
or a future flip to full open source).

Do exactly what is written here. Do not improvise license wording. Do not merge
the two licenses into one file.

---

## 0. Read this constraint first (it sets expectations, no action needed)

GitHub's license badge is produced by the `licensee` gem, which only recognizes
licenses listed on choosealicense.com — all of which are OSI/FSF open-source
licenses. **No noncommercial license exists in that set.** Therefore, after this
change, the repo sidebar will still show a generic **"View license"**, not a
named badge. That is expected and unavoidable for any NC license. The win here
is correctness and machine-readability (a real single license + SPDX ID), not a
pretty badge. Do not try to "fix" the badge by editing the license text — that
only breaks detection further.

---

## 1. Replace `/LICENSE` with PolyForm Noncommercial 1.0.0 (verbatim)

**File:** `LICENSE` (repo root — overwrite the existing CC BY-NC paraphrase entirely)

Write the file with **exactly** the content in the fenced block below. The first
two lines (`<!-- SPDX... -->` and the `Required Notice:` block) are intentional
and must be preserved — the `Required Notice:` line is a PolyForm mechanism that
forces downstream copies to carry the copyright + commercial-contact pointer.

Do not reflow, reword, or "tidy" the license body. It must remain byte-for-byte
the canonical PolyForm text (sourced from
<https://polyformproject.org/licenses/noncommercial/1.0.0>).

```text
<!-- SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0 -->

Required Notice: Copyright 2026 Cyber Cervela.
Commercial licensing available — contact cibercervela@pm.me

# PolyForm Noncommercial License 1.0.0

<https://polyformproject.org/licenses/noncommercial/1.0.0>

## Acceptance

In order to get any license under these terms, you must agree
to them as both strict obligations and conditions to all
your licenses.

## Copyright License

The licensor grants you a copyright license for the
software to do everything you might do with the software
that would otherwise infringe the licensor's copyright
in it for any permitted purpose. However, you may
only distribute the software according to Distribution License and make changes or new works
based on the software according to Changes and New Works License.

## Distribution License

The licensor grants you an additional copyright license
to distribute copies of the software. Your license
to distribute covers distributing the software with
changes and new works permitted by Changes and New Works License.

## Notices

You must ensure that anyone who gets a copy of any part of
the software from you also gets a copy of these terms or the
URL for them above, as well as copies of any plain-text lines
beginning with `Required Notice:` that the licensor provided
with the software. For example:
> Required Notice: Copyright Yoyodyne, Inc. (http://example.com)

## Changes and New Works License

The licensor grants you an additional copyright license to
make changes and new works based on the software for any
permitted purpose.

## Patent License

The licensor grants you a patent license for the software that
covers patent claims the licensor can license, or becomes able
to license, that you would infringe by using the software.

## Noncommercial Purposes

Any noncommercial purpose is a permitted purpose.

## Personal Uses

Personal use for research, experiment, and testing for
the benefit of public knowledge, personal study, private
entertainment, hobby projects, amateur pursuits, or religious
observance, without any anticipated commercial application,
is use for a permitted purpose.

## Noncommercial Organizations

Use by any charitable organization, educational institution,
public research organization, public safety or health
organization, environmental protection organization,
or government institution is use for a permitted purpose
regardless of the source of funding or obligations resulting
from the funding.

## Fair Use

You may have "fair use" rights for the software under the
law. These terms do not limit them.

## No Other Rights

These terms do not allow you to sublicense or transfer any of
your licenses to anyone else, or prevent the licensor from
granting licenses to anyone else. These terms do not imply
any other licenses.

## Patent Defense

If you make any written claim that the software infringes or
contributes to infringement of any patent, your patent license
for the software granted under these terms ends immediately. If
your company makes such a claim, your patent license ends
immediately for work on behalf of your company.

## Violations

The first time you are notified in writing that you have
violated any of these terms, or done anything with the software
not covered by your licenses, your licenses can nonetheless
continue if you come into full compliance with these terms,
and take practical steps to correct past violations, within
32 days of receiving notice. Otherwise, all your licenses
end immediately.

## No Liability

***As far as the law allows, the software comes as is, without
any warranty or condition, and the licensor will not be liable
to you for any damages arising out of these terms or the use
or nature of the software, under any kind of legal claim.***

## Definitions

The **licensor** is the individual or entity offering these
terms, and the **software** is the software the licensor makes
available under these terms.

**You** refers to the individual or entity agreeing to these
terms.

**Your company** is any legal entity, sole proprietorship,
or other kind of organization that you work for, plus all
organizations that have control over, are under the control of,
or are under common control with that organization. **Control** means ownership of substantially all the assets of an entity,
or the power to direct its management and policies by vote,
contract, or otherwise. Control can be direct or indirect.

**Your licenses** are all the licenses granted to you for the
software under these terms.

**Use** means anything you do with the software requiring one
of your licenses.
```

---

## 2. Add `/LICENSE-DOCS` for the prose docs (CC BY-NC 4.0)

The Markdown docs (`PHILOSOPHY.md`, `DECISIONS.md`, `JOURNAL.md`, `BACKLOG.md`,
`FEATURES.md`, `README.md`, `optimization.md`) are prose, not code. CC is the
correct tool for prose; keep them under CC BY-NC 4.0. Do **not** paraphrase the
deed — reference the canonical legalcode by URL (this is the CC-recommended way
to apply the license).

**File:** `LICENSE-DOCS` (new, repo root)

```text
<!-- SPDX-License-Identifier: CC-BY-NC-4.0 -->

Documentation and prose content in this repository (all .md files, including
PHILOSOPHY.md, DECISIONS.md, JOURNAL.md, BACKLOG.md, FEATURES.md, README.md,
and optimization.md) are licensed under the
Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0).

Copyright 2026 Cyber Cervela.

You are free to share and adapt this material for noncommercial purposes, with
attribution. Full legal text: https://creativecommons.org/licenses/by-nc/4.0/legalcode

Source code is licensed separately — see the LICENSE file (PolyForm
Noncommercial 1.0.0).
```

---

## 3. Update `/README.md` — add a License section

Append the following section to `README.md` (after the existing description). If
a License section already exists, replace it with this one. Plain-language by
design — it states the source-available posture explicitly so no one mistakes it
for open source.

```markdown
## License

DopamineLedger is **source-available, not open source.** You can read, run,
modify, and share it for **noncommercial** purposes. Commercial use is not
granted by the public license.

- **Source code** — [PolyForm Noncommercial 1.0.0](LICENSE)
  (SPDX: `PolyForm-Noncommercial-1.0.0`)
- **Documentation / prose** (all `.md` files) — [CC BY-NC 4.0](LICENSE-DOCS)

**Want to use this commercially?** The author retains full copyright and is
happy to discuss a commercial license. Reach out: **cibercervela@pm.me**

Note: this project may move to a fully open-source license in the future. To
keep that option open, external contributions are accepted only under the terms
in [CONTRIBUTING.md](CONTRIBUTING.md).
```

---

## 4. Add `/CONTRIBUTING.md` — the relicensing safeguard (important)

**Why this matters:** the stated goals are (a) sell commercial licenses on
request and (b) possibly flip to full open source later. **Both require that the
author owns or controls the copyright in 100% of the code.** The moment an
outside contribution is merged without a rights grant, that contributor co-owns
their lines and can block any future relicensing. A DCO (Developer Certificate
of Origin) is **not sufficient** — it only attests origin; it does not grant the
author the right to relicense. A lightweight **CLA** (Contributor License
Agreement) is what preserves the optionality.

No action is needed against existing code (the author wrote all of it). This
only governs *future external* contributions.

**File:** `CONTRIBUTING.md` (new, repo root)

```markdown
# Contributing

Thanks for your interest in DopamineLedger.

## License of contributions

This project is source-available under the PolyForm Noncommercial 1.0.0 license,
and the author may offer it under separate commercial licenses and may, in the
future, release it under an open-source license.

To make that possible, by submitting a contribution (pull request, patch, or
otherwise) you agree that:

1. You are the original author of the contribution, or otherwise have the right
   to submit it.
2. You grant the project's author (Cyber Cervela) a perpetual, worldwide,
   non-exclusive, royalty-free, irrevocable license to use, reproduce, modify,
   distribute, and **relicense** your contribution under any terms, including
   commercial and open-source licenses.

You retain copyright in your contribution; this is a license grant, not an
assignment.

If you are not comfortable with this, please open an issue to discuss before
contributing.

## Before the first external PR is merged

Set up automated CLA tracking (e.g. the **CLA Assistant** GitHub App,
https://github.com/cla-assistant/cla-assistant) so each external contributor
records agreement on their first PR. Until that is in place, do not merge
external contributions.
```

---

## 5. (Optional) Add SPDX headers to source files

PolyForm doesn't require per-file headers, but they make machine tooling
unambiguous. If you choose to do this, add this as the **first line** of each
`.swift` file (and `.py`/`.sh` scripts), using the correct comment syntax:

- Swift / Python (`#` or `//`): `// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0`
- Shell / Python: `# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0`

This is optional and high-effort across an existing tree — skip it if you'd
rather not touch every file. The root `LICENSE` is what legally governs.

---

## 6. Commit

Single focused commit. Suggested message:

```
Relicense: source-available (PolyForm Noncommercial 1.0.0 for code, CC BY-NC 4.0 for docs)

- LICENSE: replace self-written CC BY-NC paraphrase with canonical PolyForm
  Noncommercial 1.0.0 (+ SPDX id, Required Notice with commercial contact)
- LICENSE-DOCS: prose/docs under CC BY-NC 4.0 (canonical reference, not paraphrase)
- README: explicit source-available statement + commercial-licensing contact
- CONTRIBUTING: CLA-style grant to preserve relicensing optionality
```

---

## 7. Verification checklist (do these after pushing)

1. **File is named exactly `LICENSE`** (no extension) at repo root. `licensee`
   keys off this name. ✅ if present.
2. **Sidebar shows "View license"** (generic), and clicking it renders the
   PolyForm text. This is the *expected* result — a named badge is not possible
   for an NC license. Do **not** treat the generic label as a failure.
3. **`gh api repos/CyberCervela/DopamineLedger/license`** (or the GitHub
   "Detected license" via the API) — confirm it does not now misreport a
   *wrong* recognized license (e.g. it should not say "MIT"). "Other" / `NOASSERTION`
   is the correct, honest outcome.
4. **No warranty-clause splice.** Confirm the old MIT-style
   "THE SOFTWARE IS PROVIDED 'AS IS'…" block from the previous file is gone —
   PolyForm has its own "No Liability" clause and the two must not coexist.
5. **README renders** the License section with working relative links to
   `LICENSE` and `LICENSE-DOCS`.

---

## What this does and does not protect (so expectations are correct)

- **Protects:** someone copying the repo's Swift and shipping/selling it. The NC
  term forbids that without a commercial license from you.
- **Does NOT protect:** someone reading the philosophy, reimplementing the
  gatekeeper independently, and shipping it commercially. That is the *idea*,
  not the code's *expression* — copyright doesn't reach it, and the patent route
  was already ruled out. The gatekeeper behavior is observable in the shipped
  app, so independent reimplementation is the realistic competitive threat and
  this license does nothing against it. That's an accepted limitation, not a bug
  in the plan.
- **Relicensing reminder:** copies already public under the old CC BY-NC remain
  available under those terms to anyone who already obtained them. The new
  license binds copies distributed from now on. At 0 forks this is immaterial,
  which is why doing it before promoting the repo is the right sequencing.
