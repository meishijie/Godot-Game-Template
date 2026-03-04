---
name: godot-template-regression-qa
description: Run a focused manual regression checklist for this Godot template after code changes. Use before commit when changes touch menus, loading, pause flow, level flow, settings, or persistent state.
---

# Godot Template Regression QA

## Overview

Validate critical player flow and state persistence before finishing work.

## Use This Checklist

Open and follow:

- `references/manual-qa-checklist.md`

Record pass/fail notes in your response grouped by:

- startup and scene flow
- gameplay/pause flow
- save/config persistence
- platform-sensitive behavior (web vs native)

## Execution Rules

- Run highest-risk items first based on changed files.
- If a check fails, include:
  - exact step
  - expected behavior
  - actual behavior
  - likely impacted file(s)
- If you cannot run Godot in this environment, report unverified checks explicitly.

