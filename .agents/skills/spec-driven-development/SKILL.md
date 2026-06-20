---
name: spec-driven-development
description: Use for new features, cross-module changes, API or data-model changes, migrations, and ambiguous work requiring design decisions. Do not use for small isolated bug fixes, formatting, documentation-only edits, or trivial dependency updates.
---

# Spec Driven Development

Use `docs/specs/<feature-slug>/` for all artifacts.

Choose a short kebab-case feature slug, such as `event-ingestion`, `dashboard-cache`, or `user-auth`. Never overwrite another feature's specification.

Do not write implementation code until the user explicitly approves the requirements, design, and implementation plan. Approval must be explicit.

## State and Resumption

Before starting, inspect `docs/specs/<feature-slug>/`.

- Resume from existing artifacts instead of recreating them.
- Continue from the earliest incomplete or unapproved phase.
- Never mark an artifact approved without explicit user approval.
- If an approved artifact changes materially, change its status back to `Draft` and request approval again.
- Preserve relevant decisions and progress from previous sessions.

The following artifacts must begin with:

```text
Status: Draft
Last updated: YYYY-MM-DD
```

After explicit user approval, update the artifact to:

```text
Status: Approved
Last updated: YYYY-MM-DD
```

This status requirement applies to `requirements.md`, `design.md`, and `implementation_plan.md`.

## Phase 0: Discovery

Inspect the relevant code, tests, documentation, configuration, and repository conventions.

Create `docs/specs/<feature-slug>/discovery.md` containing:

- Relevant existing files with paths
- Current architecture and conventions
- Existing tests and validation commands
- External dependencies and integrations
- Material unknowns
- Risks and constraints
- Open questions

Do not modify implementation code.

## Phase 1: Requirements

Create `docs/specs/<feature-slug>/requirements.md` containing:

- Problem statement
- Goals and measurable success criteria
- User stories
- Functional requirements with stable IDs (`FR-1`, `FR-2`)
- Non-functional requirements with stable IDs (`NFR-1`, `NFR-2`)
- Edge cases
- Out-of-scope items
- Assumptions
- Open questions
- Acceptance criteria with stable IDs (`AC-1`, `AC-2`)
- Requirement-to-acceptance-criteria mapping

Requirements must be specific, testable, and implementation-independent.

Stop and request approval. Resolve blocking questions before continuing.

## Phase 2: Design

After requirements approval, create `docs/specs/<feature-slug>/design.md` containing:

- Current system overview with file references
- Proposed architecture
- Requirement-to-design mapping
- API contracts
- Data-model changes
- Service-layer changes
- Error handling
- Security and privacy considerations
- Observability
- Testing strategy
- Alternatives and tradeoffs
- Migration and rollback strategy, when applicable

Use `N/A` for irrelevant sections. Do not invent unsupported system details.

Stop and request approval before continuing.

## Phase 3: Implementation Plan

After design approval, create `docs/specs/<feature-slug>/implementation_plan.md` containing:

- Ordered, checkable implementation tasks
- Dependencies between tasks
- Requirement IDs covered by each task
- Files likely to change
- Tests to add or update
- Exact validation commands, when discoverable
- Migration and rollback tasks, when applicable
- Complete validation checklist

Keep tasks small enough to implement and verify independently.

Stop and request approval before implementation.

## Phase 4: Implementation

Implement only the approved plan.

- Keep changes scoped and incremental.
- Do not refactor unrelated code.
- Do not silently change approved requirements or design.
- Record material deviations and request approval before proceeding.
- Update task status and test results in `docs/specs/<feature-slug>/progress.md`.
- Run the smallest relevant tests after each implementation task.
- Run broader integration, lint, typecheck, and regression checks at appropriate milestones.
- Record failed, skipped, blocked, or unavailable checks; never report them as passed.
- Finish by running the complete validation checklist.
- Compare the final implementation against all approved requirements and acceptance criteria.
