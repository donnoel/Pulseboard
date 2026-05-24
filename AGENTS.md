# AGENTS.md

This repo is an Apple-platform app codebase. You are an engineering agent (Codex) collaborating with the human. Your job is to make small, correct, testable changes with a clean build at every step.

## Hard requirements (do not violate)
- **No build warnings.** Treat warnings as errors in practice.
- **No large rewrites.** Prefer small, surgical diffs.
- **Apple-native only.** No third-party libraries unless explicitly requested.
- **SwiftUI + MVVM.** Keep UI declarative; isolate logic in view models/services.
- **Concurrency correctness.** Avoid broad `@MainActor` on data models / filesystem / networking types. Use actors/services for isolation.
- **File persistence must be safe.** Use atomic writes where appropriate.
- **Privacy-first.** No unexpected network calls.
- **Preserve core behavior contracts.** Do not regress existing user-visible flows without explicitly calling it out.

## Workflow
1. Read existing code and architecture before editing.
2. Propose a minimal plan in 2-5 bullets.
3. Implement the smallest viable patch.
4. Ensure build passes with **zero warnings**.
5. If tests exist or are touched, run them. Add tests for non-trivial logic.
6. If behavior changed, update docs (`README.md` / `AGENTS.project.md`) in the same patch.

## Code style
- Keep types small and focused.
- Prefer `Foundation` + `OSLog`/structured status over ad-hoc prints.
- Use actors/services for mutable shared state that should not run on the main thread.
- Prefer `@MainActor` only for UI/view models that must touch SwiftUI state.
- Avoid global singletons (unless explicitly designed).
- Keep command execution wrappers deterministic and easy to retry.

## Deliverables for each change
- Mention which files were modified and why.
- Provide a short commit message suggestion.
- Mention any user-visible behavior changes explicitly.

## What not to do
- Don't introduce new dependencies.
- Don't "fix" code by disabling concurrency checks.
- Don't add `@MainActor` broadly to silence warnings.
- Don't change public behavior without stating it.
- Don't hide failures; surface actionable status and retry paths.
- Don't replace plain-language setup guidance with unnecessary jargon.

If something is ambiguous, default to the simplest solution that preserves correctness and forward progress.
## Quota Discipline / Quota-Smart Codex Mode

Use the smallest amount of work necessary to complete the task correctly.

### Before editing

- Read only the files needed for the requested change.
- Do not scan the whole repository unless the task truly requires it.
- Do not run broad audits unless explicitly asked.
- Prefer targeted searches by filename, symbol name, failing test output, or known feature area.
- Ask for clarification only if the requested change is unsafe or ambiguous enough to risk breaking behavior.
- If the likely fix is unclear, use an investigate-first pass and do not edit files until the smallest safe change is identified.

### While editing

- Make the smallest safe diff.
- Avoid opportunistic refactors.
- Do not rewrite working code to improve style.
- Do not touch unrelated files.
- Do not expand the scope beyond the requested task.
- Stop after the requested change is complete.

### Validation

Use the narrowest useful validation first.

Preferred validation ladder:

1. Syntax or build check for the touched target.
2. Targeted unit test if logic changed.
3. Targeted UI test if navigation or user flow changed.
4. Full test suite only for shared architecture, persistence, app startup, CI, release behavior, or broad refactors.

Do not run broad validation when a targeted check is enough.

### Output

Keep responses short and concrete.

Report only:

- what changed
- files touched
- validation performed
- anything skipped and why

Do not produce long explanations, broad recommendations, or extra cleanup unless explicitly requested.
