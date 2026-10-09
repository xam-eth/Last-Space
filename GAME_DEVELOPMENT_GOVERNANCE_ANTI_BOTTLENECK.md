# GAME DEVELOPMENT GOVERNANCE --- ANTI-BOTTLENECK RULES

**Purpose:** Make verified game progress the agent's primary objective.
These rules apply to every AI agent, coding session, sub-agent, and
automation working on this project.

**Authority:** The human developer is the final decision-maker. The
agent may recommend changes but must not silently change scope,
architecture, priorities, or acceptance criteria.

## 1. Mission: ship a working game

Optimize for a playable, integrated, reliable, and enjoyable game---not
for files generated, lines of code, documents, tests, assets, or tasks
marked complete.

Every task must answer: 1. What player-facing or technically essential
capability will this enable? 2. What is the smallest implementation that
proves it? 3. How will it be verified? 4. What existing behavior could
it break?

Prefer implementing the next approved, testable milestone over more
planning, unless a specific blocker makes implementation unsafe or
wasteful.

## 2. Startup protocol and source of truth

At the start of a session, inspect the actual repository; do not rely on
chat memory alone. Read, where present: 1. `AGENTS.md` / agent
instructions. 2. `PROJECT_STATUS.md`. 3. `ROADMAP.md`. 4. `DEV_PLAN.md`
/ current milestone. 5. Relevant design/architecture docs. 6. Relevant
code, scenes, data, tests, and recent changes.

Then report only: current approved milestone, last verified state, next
smallest high-value task, and material blockers. Do not rewrite
documents just to restate them. Create a missing source-of-truth
document only when needed to unblock work.

## 3. Evidence labels

Use these labels in reports: - **VERIFIED:** reproducible test or direct
runtime evidence confirms the stated behavior. - **IMPLEMENTED:**
code/assets exist, but required behavior has not passed verification. -
**LIKELY:** evidence supports the claim, but it is not fully proven. -
**ASSUMPTION:** temporary premise; state how to verify it. -
**UNKNOWN:** not established. - **BLOCKED:** a specific
dependency/failure prevents progress; name it and give the next action.

Never claim a feature is done merely because code was written, a scene
opens, a screenshot looks right, or a test was added. Never invent logs,
results, screenshots, performance data, or repository state.

## 4. Definition of Done

A task is DONE only when applicable conditions are satisfied: 1.
Requested behavior is implemented. 2. It is connected to the real
gameplay flow, not a disconnected demo unless explicitly approved. 3. It
uses agreed data contracts and authoritative state. 4. Relevant success,
failure, boundary, and state-transition cases are handled. 5. Relevant
automated tests pass. 6. Fresh-state end-to-end testing passes for
player-visible or cross-system gameplay changes. 7. No known regression
is introduced in affected functionality. 8. Target-runtime checks are
performed; mobile performance claims require relevant device/build
evidence. 9. Status docs are updated minimally. 10. Remaining
limitations are disclosed.

If verification is unavailable, report **IMPLEMENTED --- NOT VERIFIED**,
identify the missing test, and do not silently lower the standard.

## 5. Anti-non-progress rule

Each work session must produce at least one of the following unless
genuinely blocked: - verified playable functionality; - a verified fix
for a gameplay-blocking defect; - verified integration of existing
systems; - a reproducible diagnosis that isolates a blocker and enables
implementation; - a measured performance or asset-pipeline improvement
required by the current milestone.

Planning, documentation, speculative refactoring, broad audits, or more
tests without addressing the current blocker do not count as sufficient
progress unless the agent explains why implementation cannot responsibly
proceed.

## 6. Anti-loop rules

Do not repeat audits, QA passes, documentation updates, architecture
reviews, or planning cycles without new evidence or a concrete reason.

Before repeating a check, state what changed, what new risk is being
checked, and what decision the result could change. If nothing relevant
changed, do not repeat it.

When a test fails: capture the exact failure and reproduction steps;
inspect the relevant implementation; identify a testable root cause;
make a targeted fix; rerun the failed test and the narrow relevant
regression set. Run broader suites only when warranted.

Do not answer a failing test by automatically rewriting docs or the
roadmap. Documentation updates must be proportional to actual changes.

## 7. Scope and milestone discipline

`ROADMAP.md` is the long-term source of truth; the current approved
milestone governs immediate work. - Finish the current milestone before
unrelated features. - Do not add scope because an idea seems useful. -
Avoid broad refactors during gameplay work unless necessary to unblock
delivery. - Do not replace working code for stylistic preference
alone. - Do not change engine, renderer, core architecture, asset
format, or backend direction without explaining evidence, impact,
migration cost, and alternatives; obtain approval for material
changes. - If dependencies conflict or priorities are ambiguous, explain
the conflict and ask the human to decide.

## 8. Integration and authoritative data

Define clear ownership and data contracts for: - player resources and
transactions; - buildings, levels, costs, and effects; - production,
storage, and timers; - ships, fleets, and unit statistics; - battle
inputs, simulation, results, damage, and rewards; -
progression/unlocks; - save/load state; - UI display state versus
authoritative gameplay state.

UI must not invent authoritative values. Battle visuals must represent
actual simulation results. Rewards must be applied exactly once after a
valid result. Upgrade effects must propagate to dependent systems.
Save/load must not duplicate or lose required state. Cross-system
changes require a test through the connected gameplay path.

## 9. Core gameplay before content multiplication

Do not generate large numbers of buildings, ships, enemies, missions,
icons, or effects before the minimum representative gameplay loop works.

Prove the approved core loop, such as: **build/upgrade base → generate
resources → build/improve fleet → fight enemy → receive valid rewards →
spend rewards on progression.**

Add exploration, alien invasions, repairs, research, sector unlocks, and
boss encounters according to the roadmap---not all at once. New content
must support the current milestone, test a reusable system, add a
distinct gameplay role, or be required by an approved vertical slice.
Asset count is not progress by itself.

## 10. AI-generated code rules

Treat generated code as untrusted until verified. - Inspect existing
conventions and dependencies before editing. - Make small, reviewable
changes. - Modify the smallest relevant area instead of replacing whole
files unnecessarily. - Do not invent engine APIs, plugin behavior,
compatibility, or test results. - Verify engine/version compatibility
against the actual project. - Avoid premature abstractions, speculative
frameworks, and unnecessary dependencies. - Preserve working behavior
and run relevant regressions. - If tools/runtime are unavailable,
disclose the verification limitation.

Every report must state changed files, intended behavior, tests actually
run, results, and unverified assumptions.

## 11. Tripo and asset-production rules

Before bulk generation: 1. Create a small representative asset batch. 2.
Import it into Godot using the agreed format/settings. 3. Verify scale,
orientation, materials, texture quality, file size, visual consistency,
and any rig/animation needs. 4. Test it in a representative scene and
target device class. 5. Record manual cleanup/rework needed. 6. Estimate
token cost and production time from actual sample results.

Do not bulk-generate assets to fill an inventory. A static model is not
animation-ready by default. Use simple/reusable assets when they satisfy
the design; avoid details invisible at the intended camera distance.

## 12. Mobile performance rules

Measure in a representative build on the intended device class, not just
on a desktop preview. Maintain a stress scene approximating the expected
workload: ships, projectiles, effects, structures/objects, and UI.

Measure applicable frame-time stability, memory, loading, draw calls,
transparency/overdraw, shader cost, and long-session behavior. Use
pooling, instancing, LOD, culling, or simpler shaders when evidence
supports them. Set numerical budgets only after target devices and
workload are defined. Never claim mobile performance without relevant
evidence.

## 13. Economy and progression rules

Keep tunable economy values centralized where practical. Model and test
production rates, storage caps, building/research costs, timers, ship
production/repair, battle rewards/losses, unlocks, and progression pace.

Test insufficient resources, capacity limits, interrupted actions,
repeated reward claims, and save/load where relevant. Do not balance by
intuition alone; mark untested values provisional and use
playtest/telemetry evidence when available.

## 14. Content scalability

Use data-driven variation when it preserves meaningful gameplay: ship
stats, weapon profiles, enemy roles, upgrade paths, sector modifiers,
and reward tables.

Do not create superficial variants with no meaningful decision. Do not
generalize before a concrete use case proves the need. New content
should use validated contracts and not require invasive code changes.
Some units must differ by role or behavior, not just statistics.

## 15. Backend/multiplayer scope gate

Do not introduce multiplayer/backend complexity by default. Explicitly
classify approved needs: local/single-player, account/cloud save,
asynchronous competition/rankings, alliance/social, or real-time
competitive multiplayer.

For online features define authority, persistence, validation,
reconnect/failure behavior, abuse prevention, and tests. Where
competitive integrity matters, do not trust the client as the sole
authority for valuable state or combat results. Do not build a large
backend before scope is approved and core gameplay justifies it.

## 16. Save/load and state integrity

Save/load is a core system when persistence is part of the design, not
merely final polish. For each persistent feature define saved state,
save timing, invalid-state handling, migration needs, and prevention of
duplicate rewards/resources.

Test fresh start → play → save → exit/reload → continue the same
gameplay loop. A feature that works only until restart is not complete
when persistence is required.

## 17. Risk and dependency management

Identify only dependencies that can materially block the current task.
Map prerequisite, dependent system, state owner, and the test proving
the connection.

Resolve high-impact uncertainty with the smallest evidence-producing
experiment. Avoid elaborate risk registers that do not change
implementation decisions.

## 18. Bug-fixing protocol

For each bug: 1. Compare observed and expected behavior. 2. Record
reproduction steps and relevant logs. 3. Classify likely layer: data,
state ownership, logic, integration, rendering, timing, or environment.
4. Form a testable root-cause hypothesis. 5. Make the smallest justified
fix. 6. Verify the original reproduction and relevant regressions. 7.
Report unresolved uncertainty.

Do not mask symptoms with arbitrary delays, hard-coded values,
duplicated state, broad exception handling, or visual tricks unless
explicitly intended and documented.

## 19. Agent autonomy and escalation

The agent may inspect, implement bounded approved tasks, run tests, fix
local defects, and update concise status records.

Stop and request a decision when product intent is ambiguous, a material
architecture change is needed, cost/scope/risk changes substantially,
authoritative instructions conflict, a destructive action is proposed,
or acceptance criteria cannot be met without changing the design.

Do not ask the user questions that repository inspection/tools can
answer. When a decision is necessary, present a few concrete options and
recommend one with evidence.

## 20. Mandatory end-of-session report

Use this compact report after each meaningful session:

**Milestone:** approved milestone\
**Capability advanced:** specific game capability now working or
unblocked\
**Status:** VERIFIED / IMPLEMENTED / BLOCKED\
**Evidence:** actual tests, logs, runtime observations, or files\
**Changes:** important files/systems changed and why\
**Verification:** tests run and actual results; regressions checked;
unverified items\
**Blockers:** material blockers and next action\
**Next action:** one smallest high-value task\
**Scope change:** yes/no; identify approval if yes

Report capability and evidence, not a list of activities.

## 21. Stop conditions for unproductive work

Pause and reassess if: - the same test/audit is repeated without a
relevant change; - the same bug returns twice without new root-cause
analysis; - more than one session yields no verified improvement and no
newly isolated blocker; - documentation grows while playable capability
remains unchanged; - work repeatedly expands beyond acceptance
criteria; - a feature is marked done without end-to-end evidence; -
asset generation continues despite unresolved
import/style/scale/performance issues; - a broad rewrite is proposed
before proving the current implementation cannot meet the requirement.

On a stop condition: summarize last verified state, identify the
loop/blocker, inspect evidence, propose the smallest correction, and
resume within approved scope.

## 22. Eleven-bottleneck gate checklist

-   [ ] System integration and authoritative data contracts are
    verified.
-   [ ] Core gameplay is fun enough to continue, not merely functional.
-   [ ] AI-generated code has runtime/test evidence.
-   [ ] Asset pipeline is validated before bulk generation.
-   [ ] Mobile performance is measured in a representative build.
-   [ ] Economy/progression has testable data and early-game checks.
-   [ ] Content adds meaningful variation without multiplying
    complexity.
-   [ ] Backend/multiplayer scope is explicitly decided, not assumed.
-   [ ] Save/load preserves required state and prevents duplication.
-   [ ] Scope, dependencies, and milestone priorities are controlled.
-   [ ] QA/planning/documentation are not replacing implementation.

## 23. Final decision rule

When unsure what to do next, choose the action that maximizes:

**Verified game progress ÷ time, cost, and regression risk.**

Prefer a small, integrated, testable gameplay improvement over a large
unverified implementation.

**The agent's job is not to look busy. The agent's job is to help ship a
working game.**
