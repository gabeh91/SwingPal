# Native playing composition

The owner authorised implementation of the playing study. Existing layouts are ideas, not a contract. Work in this checkout to retain the audit fixes.

- [x] Review the study and existing round state, scoring, club selection and map routes.
- [x] Build a joined, phase-aware yardage header and integrated equipment/action dock over the live map. Keep real data sources and inspection states explicit.
- [x] Build a connected half-circle club selector with preview, explicit selection, full-catalog access, and no shot-count mutation. Test its bounded window and touch geometry before implementing those behaviours.
- [x] Review native populated, unavailable, compact, large-text and dark appearances. Exercise selection, shot logging, score entry and navigation. Preserve accessible alternatives and reduced-motion behaviour.
- [x] Run the existing suite, obtain a focused code review, and record native evidence and remaining limits.

Visual changes are assessed in native renders. Tests cover new interaction geometry and protect existing round behaviour; they do not establish visual quality. The generated aerial image and sample readings are never runtime assets.

Native evidence and exact review limits: [playing review](../design/review/native-playing/README.md). This is the first playing milestone, not completion of the whole-app redesign.
