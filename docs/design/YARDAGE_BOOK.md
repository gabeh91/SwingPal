# SwingPal — The yardage book

28 September 2026 · Supersedes the "Course in hand" and shot-planner directions in [UI_DIRECTION.md](UI_DIRECTION.md) as the whole-app visual identity. The shot-planner interaction model (map-led planning, preview/Use/Cancel club choice, separate Log shot) is kept and restyled.

## Thesis

SwingPal feels like **a caddie's yardage book**: every hole is drawn to scale from the course geometry, turned so the tee is at the bottom and the green at the top, and annotated in pencil beside the thing each number measures. Golfers need to know where they are, what lies between them and the green, and what to hit. **Signature behaviour: the hole page.** You thumb through the book on Home, plan on the same page during play, and the scorecard keeps what you wrote.

### Governing qualities

| Quality | What it looks like | What it rules out |
| --- | --- | --- |
| **Drawn to scale** | Holes projected from real polygons, rotated tee→green, true-radius distance arcs, a 50 m / 50 yd scale bar | Symbolic course art, invented pins, decorative gauges |
| **Annotated** | Figures sit next to what they measure: green readings on the green, carry on the club, marks on the card | Stat-card grids, bento dashboards, eyebrow→headline→subtitle blocks |
| **Pocketable** | One column, condensed figures, the committed action under the thumb, nothing looping | Ambient animation, glass stacks, gradient blobs |

## Directions considered

1. **Yardage book (chosen).** An illustrated atlas plus a precision instrument. Hole pages, a thumb index, pencil annotations. Strong everywhere: Home, setup, play and history share one object.
2. **Scorecard ledger.** The round as a physical card that fills in; Home is the card grid. Excellent for scoring and review, but weak at explaining a shot or a course. *Kept as the supporting idea:* scorecard notation and the out/in card.
3. **Rangefinder.** A dark HUD with big numbers and a reticle. Clear outdoors, generic off the course. *Its numerals inform the live readout.*

## Art-direction sheet

- **Paper and ink.** Light "day book": paper `#F2EFE6`, leaf `#FBFAF5`, ink `#17261F`, pencil `#596159` (5.6:1 on paper), rule `#D8D2C2`, stamp `#1E3B2F`. Dark "night book": paper `#101714`, leaf `#18211D`, ink `#ECE7DA`, pencil `#A4AAA0` (7.6:1), stamp `#CFE3C4`. These live in the existing `Course*` colour assets, so every screen inherits them.
- **Flag.** `#D4462A` / `#FF7452`, reserved for the target, the player's position, the pin pennant and scores under par. Never used for text-only emphasis.
- **Terrain inks** (drawings only): fairway with mown stripes, green with contour rings, stippled sand, hatched water, a solid tee block. Defined in `Book` in `DesignSystem/YardageBook.swift`.
- **Type.** SF Pro Condensed for the book's voice (folio numerals, headings, figures); SF Pro for reading; expanded small capitals for pencil notes. All sizes derive from text styles and scale with Dynamic Type, apart from the fixed folio numerals and tiny map labels.
- **Depth.** Three layers only: paper (ground), leaf (the page or a floating control, with a hairline edge), and the stamp (the one committed action). No glass. Floating map controls are paper chips.
- **Shape.** Hairline rules instead of cards; 14–18 pt continuous corners for leaves and stamps; circles and squares carry score meaning.

## Signature sequences

1. **Thumb through the book (Home).** *Resting:* the selected course's current hole fills a leaf, and pages stack beneath it. *Trigger:* drag or tap the thumb index, or swipe the page horizontally. *Moves:* the folio numeral counts to the new hole and the drawing cross-fades. *Stays put:* the page frame, the course title and the action. *Interruption:* follows the finger; releasing leaves the current stop. *Accessible:* the index is an adjustable element, and there's a stepper at accessibility text sizes. *Why:* you learn the course before you reach the first tee.
2. **Plan the shot on the page (live).** *Resting:* aerial or drawn page; the target ring sits where the club in hand lands (on the pin if it reaches), a short arc marks that club's carry across the line, the pill above the ring says what's left and the club for it ("To green 121 m · 7i"), and bunkers and water in play carry their reach/carry figures. The green tag gives centre, front, back and plays-like; wind sits beside the course name as an arrow relative to the line. *Trigger:* hold and drag the ring; tap the club to preview others (the ring moves to each club's carry). *Stays put:* header, green tag, dock. *Commit:* **Use** keeps the club and its plan, **Cancel** puts the plan back on the club in hand; nothing is logged until **Log shot**. *Accessible:* the existing scalable instrument and list flow at large text sizes and with VoiceOver; hazard tags have spoken labels.
3. **Write it on the card (score → review).** *Trigger:* tap *Card* or finish a hole. Choose by golf name (Eagle…Triple) or count strokes. The mark the score will earn is shown before commit. *Commit:* "Write it on the card" confirms through the existing state method. *Return:* the review is a real out/in scorecard in the same notation, and every cell opens the correction form. *Accessible:* counters are adjustable, and cells announce "5, bogey".

## Motion and gesture contract

- Press feedback: 120 ms snappy scale/opacity. Selection: 160–200 ms snappy. No clock-driven loops anywhere in the new work.
- **Thumb index.** *Begin:* touch anywhere in the index strip; the selected tab widens. *Update:* vertical only; row = hole; a selection tick at each stop. *Settle:* at the touched row. *Commit:* none (inspection only; never changes a score or the starting hole). *Cancel:* lifting keeps the last stop. *Alternative:* adjustable action, tap a number, stepper at AX sizes.
- **Page swipe.** Horizontal travel over 44 pt that is clearly horizontal (1.4× vertical) turns one page. Vertical scroll is untouched.
- Reduce Motion removes animated page and number transitions. Reduce Transparency keeps map-edge legibility with opaque paper.

## The mark, icon and launch

- **The mark is a hole drawn as an S.** A tee block at the tail; a fairway that swells through the landing zones and pinches at the approach (the thick–thin rhythm of a typeset S); a contoured green with the flag at the head; yardage rings radiating from the pin. One geometry, defined twice from the same numbers: `HoleMark` in `SwingPalLaunchLogo.swift` (drawn live with `Canvas`) and `Tools/brand/render_brand.py` (renders the PNG assets).
- **Icon.** Stamp-green ground `#1E3B2F`, fairway and green in the day-book terrain inks, the flag in `#D4462A`. Single-size 1024 px set with Light, Dark (night-book ground `#0F1714`) and Tinted (greyscale) appearances. The watch icon is the light icon, which reads within the circular mask.
- **Launch.** `LaunchScreen.storyboard` is the book's cover: `CourseGround` paper and the page-coloured mark (`LaunchMark`, day and night) centred at 200 pt, nothing else.
- **Splash.** `LaunchSplashView` starts on that exact frame and plays the hole once: the ball leaves the tee, runs the S with its line pencilled in behind it and drops at the pin while "SwingPal / Your yardage book" is set beneath, then the page lifts away (≈1.3 s, no loop, touches pass through). Reduce Motion drops the ball and shortens the hold. Review with `SWINGPAL_DESIGN_REVIEW=splash` (6× slower, tap to replay) or `=brand`.
- **In app.** `SwingPalMarkTile` (the icon on its tile) heads the sign-in screen.

## Where things live

- `DesignSystem/YardageBook.swift`: the `Book` tokens and type, `HolePageDrawing` / `HoleProjection` (geometry projection and rendering), `ScoreMark`, `ThumbIndex`, `BookCounter`, `BookStampButtonStyle`, rules and notes.
- Home: `HomeView` (book, thumb index, scorecard stubs, round record). Setup: `RoundSetupView` (course contents strip and thumbnails). Live: `FreshLiveRoundScreen` (header, dock, club sequence, drawn map mode with arcs, hole score sheet). Review: `RoundReviewView`. Stats: `StatsView` (stroke line, book tabs). Social: `SocialView` (clubhouse board). Profile: `ProfileView` (carry ladder).

## Evidence and limits

Native renders on iPhone 17 Pro, iOS Simulator 26.3.1, SwingPal Design Audit device, in light and dark: Home (active round, thumb-index scrub, scorecard stubs), setup (course list and selected course), live (aerial and drawn, club preview), hole score, scorecard (populated and empty), Stats, Social (empty) and Profile (guest). The fixtures are DEBUG-only (`SWINGPAL_DESIGN_REVIEW`, plus `DesignReviewScenario.override`, which must stay `nil` in commits).

Not yet verified: spoken VoiceOver, Dynamic Type AX5 renders of the new screens, iPad/landscape, physical haptics, outdoor contrast, all course geometries, Watch on hardware, and the populated Social board (no shared rounds in the fixture). The drawn page covers everything beyond a 45 m margin around the hole with paper and fills the page with plain rough, so only the hole's own geometry (fairway, green, bunkers, water, tee) is drawn; trees are not in the course data, so they are not drawn. Green distances on the page are written as figures with ticks at the edge of play rather than arcs (MapKit would not layer the arcs above the page fill). Hazard figures are reach/carry from the ball to the hazard's nearest/farthest mapped vertex; neighbouring hazards on one side are merged into one complex.
