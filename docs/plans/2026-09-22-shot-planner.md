# Shot planner revision

22 September 2026. User selected: a precise shot planner, with the course and aiming interaction leading and controls connected to the shot. This accepts the emphasis, not the finished visual treatment.

The preceding floating-panel revision was rejected as boxy, primitive and unintuitive. Shrinking the same panels did not solve the composition. The new approach gives geography ownership of its information: the green owns its centre/front/back readout, the planned landing point separates the two legs of the shot, and the selected club owns a carry reference centred on the shot origin. Hole navigation remains at the top edge. A continuous lower surface holds equipment choice and the distinct Log shot action.

Alternatives considered: a restrained rangefinder would prioritise glanceable green distances; an expressive equipment dial would retain a larger custom control. The selected planner uses the map as the interaction surface, retaining explicit selection and native navigation rather than introducing another decorative instrument.

Tasks:

- [x] Inspect original aiming, club, scoring and inspection state paths.
- [x] Replace panel composition with continuous edge surfaces and geographic readouts.
- [x] Replace oversized fan with a horizontally browsable club sequence and explicit preview/Use/Cancel.
- [x] Replace arbitrary green-centred rings with a selected-club carry reference, qualified by stored/estimated source.
- [x] Render compact resting, selecting, post-shot and unavailable states; inspect larger phone and large text.
- [x] Review selection/scoring boundaries and accessibility accommodations.
- [x] Run appropriate verification, document exact evidence, install preserving the saved round.

No new scoring or carry estimator is introduced. Existing state methods govern committing club selection and recording shots. The range circle is a reference distance, not a trajectory, dispersion model or construction of a landing prediction. No measured accuracy is implied. Missing GPS removes the live range circle; the map remains reference context for manual scoring.

Fades at the map edges are legibility treatments, not ornamental gradients. Reduce Transparency must remove fades and transparent annotation backgrounds; Reduce Motion removes selection movement. Native list alternatives remain for accessibility text sizes and VoiceOver. New fixtures remain DEBUG-only and do not persist sample shots.
