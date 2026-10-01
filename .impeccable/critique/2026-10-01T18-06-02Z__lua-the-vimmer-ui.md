---
target: make The Vimmer look better or more fun
total_score: 24
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 4
target_identity: "file:/mnt/storage/apps/the_vimmer/lua/the-vimmer/ui"
timestamp: 2026-10-01T18-06-02Z
slug: lua-the-vimmer-ui
---
Method: dual-agent (A: /root/design_review · B: /root/evidence_review)

The Vimmer has a strong terminal dungeon identity. Improve navigation, readable missions, and rewarding feedback before adding more effects.

Design specificity: real Neovim editing as dungeon combat is distinctive. Existing bosses, replays, daily mutators, power-ups, sparkles and XP count-ups already support that world.

Strengths: authentic editing and teaching loop; coherent dungeon vocabulary and shared theme primitives; replay motivation through personal bests, bosses and drills.

Provisional Nielsen review (0–4; source and native geometry evidence, not usability testing):
| Heuristic | Score | Main issue |
|---|---:|---|
| Status visibility | 3 | Mission can fall below HUD viewport |
| Familiar language | 3 | Budget/multiplier terminology needs context |
| Control and freedom | 1 | Delayed results controls; inconsistent escapes |
| Consistency | 3 | Shared primitives, incomplete icon fallback |
| Error prevention | 2 | Early missions require untaught prerequisites |
| Recognition over recall | 2 | Goal and command buried below meters |
| Efficiency | 3 | Native editing, shortcuts and drills |
| Visual simplicity | 2 | Dense map and results metrics |
| Error recovery | 2 | Optimal sequence without specific coaching |
| Help | 3 | Teach cards and replay; limited in-play help |
| Total | 24/40 | Acceptable, provisional |

Priority issues:
1. P1 — Map navigation. Fresh map has 35 lines; at 80×24 runtime float shows 23. Add recommended next uncleared mission, group skills, retain Browse All, keep footer visible. A small dungeon route supports existing identity. Sources: lua/the-vimmer/ui/map.lua:141, lua/the-vimmer/ui/float.lua:102. Commands: adapt, layout, delight.
2. P1 — Play hierarchy. At 50×18 fixed 28-column HUD leaves editor 21 columns; 26-line sidebar in 15-line window hides mission. Put goal first, compress meters, use compact layout on narrow terminals. Sources: ui/play.lua:81, ui/common.lua:152. Commands: adapt, layout.
3. P1 — Reward and control. Results reveal every 80ms and install controls at end. Make skip/exit immediate, detail optional. +30 HP reward is consumed after resetting HP=100 then clamped to 100; replace with useful reserve healing or shield. Sources: ui/results.lua:205; game.lua:84,143. Commands: harden, delight.
4. P1 — Learning scaffolding. hjkl mission also requires r, absent from its motion explanation. Offer untimed practice, teach prerequisites, give one concrete recovery tip rather than foregrounding streak loss. Sources: lua/rooms/beginner/hjkl.lua:5; ui/death.lua:23. Commands: onboard, clarify.
5. P2 — Meaningful mastery and polish. Celebrate measured improvement, next-level XP, and optional mastery badges; fix actual cell-width padding, icon consistency, duplicate BOSS/PHASE labels, and offer reduced effects. Sources: ui/common.lua:126,365; ui/map.lua:153; ui/teach.lua:38; ui/transition.lua:5. Commands: polish, delight, harden.

Cognitive load: map has many peer choices; combat metrics displace goal; results require interpreting many statistics.
Emotional journey: clear briefing and real challenge lead to celebratory rewards, but defeat needs actionable coaching.
Persona flags: beginner — untaught prerequisite and timed practice; frequent player — delayed result controls; small-terminal/motion-sensitive user — hidden goal and no reduced-effects option.
Minor observations: XP bar fills at lifetime 1000 XP while level increments each 120 XP; ASCII icon mode still contains hardcoded emoji; title/border continuity and repeated boss labels need cleanup.
Questions to consider: could progression resemble a room route, and could victory celebrate one measured skill improvement?

Evidence: CLI detector exit 0 and [] (0 findings), unsuitable assurance for Lua terminal UI. Independent native headless Neovim v0.12.5 inspection at 120×40, 80×24, 50×18, 40×15; 102 focused existing tests passed. No actual screenshot/color/motion perception review; contrast findings conditional on host background. No application source changes.
