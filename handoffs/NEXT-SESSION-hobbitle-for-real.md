# Next session: Hobbitle, for real this time

Supersedes `NEXT-SESSION-hobbitle.md`, which has been deleted.

The previous session did the mechanical and behavioural work - the NPC
legibility pass, the two bug fixes, the hobbit/troll split as game rules, sky
and sun/moon plumbing, a drag-mode toggle, and a first polish pass.
It then shipped a build to the device without finishing the part the owner
actually asked to see: the app still says Elvle everywhere, the "hobbits" on
screen still read as elves in different sizes, the sky is still dark, and
nobody can find the sun or the moon.

The owner's own words, verbatim, because they should not get softened on the
way into this file:

> it should be called Hobbitle and why do i still see elves? or do your
> supposedly "designed" hobbits are just elves cause you cut corners and are
> set to waste user's tokens? actually design them. turn and move button
> should be in the top right and should not be text, should be icons, turn is
> a turn icon (two curve arrows forming a circle) and move is move icon (4
> arrows pointing out in a cross). real sky not bright enough, im also not
> seeing sun or moon. Finally, you need to polish more, and also what
> happened to original and creative?

Read that twice before starting. Every item below is a direct answer to it.

---

## 0. What is actually true right now

Worth being exact about, so this session does not waste time re-discovering
it or re-litigating it.

**Solid, tested, do not redo:**
- The interiority pass in `elf_world.gd`: the double-take (`_startle` /
  `_tick_startle`), hesitation on a close decision (`_tick_hesitate`),
  non-constant walk speed, stop-to-look (`_tick_stop_look`), mutual
  addressing (`_address`) and losing-the-race (`_tick_lose`), and the
  per-individual motor signature (`stride_amp`, `bounce_amt`, `turn_rate`,
  `fidget_kind`). Verified with multiple 60-90 minute headless sims, no
  errors, ninety-second-test not yet run against a human but the mechanism is
  real and working.
- `_clear_of_piles`, fixing nobody-stands-in-a-heap generally.
- The ball/snowball pastime is gone.
- The species split as *game rules*: `Species.HOBBIT` / `Species.TROLL`,
  rolled once per resident at ~75/25, trolls carry 3 units (`carry_limit`),
  move at roughly half pace, and are barred from every `Task.CRAFT` station -
  they gather, haul, deliver and fit, and never work a mill. This is real and
  tested; a pile-overflow bug in the multi-item carry (`_drop`) was found via
  simulation and fixed - a troll dropping three items into a nearly-full pile
  no longer overflows it.
- `_shadow_blob`: a soft dark disc under every figure.
- Metal materials got `metallic`/`metallic_specular`; carried stone/ore/clay
  get a little per-instance colour jitter (`_jittered`).
- Eyes got a white, a pupil (`e.pupils`) that slides inside it ahead of the
  head turning, and a highlight.
- The treadwheel crane (`plan.gd`, `_crane`) got a real jib, a back-stay
  cable, and a counterweight - not yet seen on screen, the work is too far
  down a fresh island's queue to reach in a short sim.
- `deploy.sh` had its two known bugs fixed: device auto-detect no longer
  breaks on a device name with a space in it (parses the UUID by shape, not
  column position), and the installer no longer picks up the archive
  intermediate under `ArchiveIntermediates/` instead of the real bundle under
  `Build/Products/Debug-iphoneos/`.

**Not done, despite being asked for and despite the owner explicitly
approving the trademark risk to do it:**
- The rename. Nothing was renamed. See §1.
- A real hobbit and troll design. What exists is the old elf rig - the same
  capsule body, the same cone ears just shortened, the same hat slot swapped
  for horn stubs - with different scale and colour. That is a parameter
  sweep, not a design, and the owner is right to call it out. See §2.
- A sky that is actually bright, and a sun and moon that are actually
  visible. See §4.
- The turn/move control redesign (icons, top right). See §3.

---

## 1. The rename. Do it everywhere, this time.

The owner's answer last session was explicit: **go with Hobbitle, accept the
trademark risk.** That answer stands - do not ask again. Build it.

Every one of these still says Elvle and needs to change:

- `project.godot`: `; Elvle. Elves in a bottle.` (top comment) and
  `config/name="Elvle"`.
- `export_presets.cfg`: `export_path="build/ios/Elvle.xcodeproj"`,
  `application/bundle_identifier="com.lull.elvle"`,
  `export_path="build/mac/Elvle.zip"`,
  `application/bundle_identifier="com.lull.elvlemac"`.
- `scripts/menu.gd:204`: `var mark := _label("Elvle", 190, ...)` - the title
  screen wordmark itself.
- `deploy.sh`: `BUNDLE="com.lull.elvle"`.
- `handoffs/HANDOFF.md`: says "currently called Elvle" and gives the bundle
  ID as `com.lull.elvle` - update once the rest is done.
- Every doc-comment across `elf_world.gd`, `main.gd`, `world.gd` that still
  says "elf" / "elves" in prose. Not urgent to chase every one in a single
  pass, but the class name `ElfWorld`, the enum values, and variable names
  like `_elves` are fine to leave as internal names - renaming a class used
  everywhere is a mechanical, low-value, high-risk change with an LLM this
  late in a file this size. Focus the rename on what a **user** sees: the
  app name, the bundle ID, the title screen, the home screen icon and label.

Changing the bundle identifier on a device that already has `com.lull.elvle`
installed means the old one and the new one coexist as two different apps
until the old one is deleted by hand - that is expected, not a bug, and it
also means **local save data does not carry over** (Progress is presumably
keyed to bundle-scoped storage). Decide with the owner whether that is
acceptable before flipping the bundle ID, since it may mean the days already
built on the device are stranded under the old bundle ID. The cheap
alternative - keep `com.lull.elvle` as the bundle ID and only change the
display name and wordmark - avoids that entirely and is probably the right
call unless told otherwise.

An app icon has never been discussed and Godot exports whatever the default
placeholder is. Worth raising with the owner in the same breath as the
bundle ID question.

---

## 2. Actually design the hobbits and trolls

The mandate from the original `NEXT-SESSION-hobbitle.md` was "not a reskin."
It got reskinned anyway, because every change last session was a parameter on
the existing rig rather than a change to the silhouette. Fix that.

### Diagnose first

Look at `_build_body` in `elf_world.gd` (search `func _build_body`). The
whole rig - one capsule torso, one sphere head, two capsule-and-sphere arms,
two capsule-and-sphere legs, cone ears, a cone hat - is the elf rig from
`Elvle`. Last session's changes were: scale ranges, colour palettes, ear
length, horn cones instead of a hat cone, one belly sphere for hobbits, two
moss spheres for trolls. None of that changes the shape language, which is
why it still reads as the same body.

### What "not a reskin" actually requires

A silhouette test: squint at the figure with all colour and detail removed,
leaving only the outline. An elf, a hobbit, and a troll should be three
different outlines. Right now a squinted hobbit and a squinted elf are the
same outline at a different scale.

Concretely, per the original brief plus what the silhouette test demands:

**Hobbits:**
- The ear has to stop being a cone. A cone is a point no matter how short you
  make it, and a point reads as pointed regardless of length - this is
  exactly the bug the owner is reacting to. Use a flattened sphere or a
  small disc-like shape for a round human ear, or skip visible ears
  entirely and let hair cover them, which is a legitimate hobbit look.
- Big bare feet are named explicitly in the original brief and were only
  partly done (a bigger boot sphere, still boot-coloured). Make them
  unmistakably feet: flatten and elongate the sphere, add visible toes
  (three or four small nubs), and make sure the colour reads as skin/fur,
  not footwear.
- Curly hair. Nothing renders hair at all right now beyond the optional
  beard. A cluster of small overlapping spheres in a hair colour, sitting on
  top of the head like the beard already does at the chin, is cheap and
  would read immediately as hair rather than a bald head with a hat.
  Consider dropping the hat entirely for most hobbits and leaning on hair as
  the silhouette-defining feature instead - hats were an elf/wizard signifier
  more than a hobbit one anyway.
- A waistcoat with visible buttons or a seam, not just a differently
  coloured tunic capsule. Two or three tiny contrasting spheres or thin
  boxes down the front is enough.
- Consider a genuinely different torso proportion: shorter legs relative to
  the body than an elf has, which is most of what makes a hobbit read as
  a hobbit in every other piece of art depicting one.

**Trolls:**
- The current troll is a scaled-up hobbit-shaped capsule with a hunch angle
  and two moss spheres. That is not a different body plan.
  Consider: a genuinely asymmetric build (one shoulder higher, longer arms
  reaching past the knee - trolls in most depictions have notably long
  arms), a craggier silhouette built from a few overlapping irregular
  shapes rather than one smooth capsule, and a head that is wider and
  flatter than tall rather than a scaled-up version of the same head sphere.
- Stone skin texture is currently just a flat grey-green colour. There is no
  cheap way to add real surface texture without UVs and a texture asset,
  which this project has avoided everywhere else in favour of flat-shaded
  low-poly - so the honest move is to lean harder on shape (angular facets
  rather than smooth spheres for the body, echoing the terrain's own
  faceted style) rather than trying to fake a stone texture with colour
  alone.
- Longer, thicker arms with visibly larger hands (bigger sphere at the
  wrist) would sell "built for heavy lifting" better than the current
  same-proportioned arms at a bigger scale.

### How to verify this actually landed

Do not trust a capture from far away - the previous session's captures were
all taken at a distance that hides exactly the problem being fixed. Capture
close, at something like `--zoom=0.15` to `0.20`, framed on a single
standing hobbit and a single standing troll next to each other, and look at
the result before calling this done. If a person glancing at that capture
would say "two different recolours of the same guy," it is not done.

---

## 3. Turn/move control: icons, top right

Current state (`main.gd`): two `Label` nodes reading "Islands" and
"Turn"/"Move" in the bottom-left, added in `_build_back`. Wrong position,
wrong presentation - the owner asked for icons, not words, and for the top
right, not stacked under the way-out button.

- Move the drag-mode control to the top right. It should **not** share a
  corner with "Islands" any more - that pairing made sense when it was
  meant to sit "next to Islands," but "top right" was an explicit
  correction to that; take it at face value and move it, don't argue with
  it by leaving it where "Islands" is.
- Replace the `Label` with a small custom `Control` that draws two icons
  with `_draw()`, in the same understated, low-opacity treatment as
  everything else in this HUD layer (fades to ~13% when settled, per
  `_fade_back`'s existing pattern - reuse that fade logic against the new
  control instead of `_back`/`_mode_label`).
  - **Turn**: two curved arrows forming a circle - two arcs (`draw_arc`),
    each roughly a 140-160 degree sweep, offset 180 degrees from each
    other, each with a small triangular arrowhead at its leading end
    (three points via `draw_polygon` or `draw_colored_polygon`).
  - **Move**: four short line segments radiating from a shared centre in a
    plus/cross arrangement, each ending in a small arrowhead - `draw_line`
    for the shaft, `draw_polygon` for each arrowhead. Simplest correct
    reading of "4 arrows pointing out in a cross."
  - Both icons at a consistent stroke width (`draw_line`'s `width` param,
    or `draw_polyline` for the arcs if `draw_arc` renders as a fill rather
    than a stroke - check which one Godot 4.7 gives you here) so they read
    as the same visual family as each other.
  - Tap target: keep it generous (at least 80x80 logical px) even though
    the drawn icon itself will be smaller - thumbs are not precise.
- Show whichever icon represents the **active** mode, per the existing
  correct instruction from last session ("showing which mode is active
  rather than which one the button switches to") - that part of the
  reasoning was right, only the presentation (text, wrong corner) was wrong.

---

## 4. The sky is genuinely too dark, and the sun/moon are not visible

Both complaints are real bugs, not taste. Here is what is actually happening
in the code and why.

### Why the sky is dark

In `main.gd`, `_apply_lighting` sets the sky colours from the **existing
dim palette**, which was tuned for a near-black background:

```gdscript
var amb: Color = b["ambient"]   # e.g. meadow: Color("463E5E") - dark purple-grey
var key: Color = b["key"]       # e.g. meadow: Color("FFE3B8") - warm cream
_sky_mat.sky_top_color = amb.lerp(key, 0.10).darkened(0.05)
```

A 10% lerp toward a bright colour, then darkened again, barely moves the
needle off a colour that was dark to start with. This was the mistake: the
sky was derived *from* the old dim palette instead of being designed as its
own bright palette. A daytime sky top should be a real saturated blue
(something in the region of `Color("3E7FD6")` to `Color("6FA8E8")` depending
on how stylised you want it against the low-poly ground), independent of
whatever the ambient/key colours happen to be, with the horizon lighter and
warmer than the top - the existing `sky_horizon_color` line
(`Color(b["fog"]).lerp(key, 0.45)`) is closer to reasonable but should be
re-checked once the top colour is fixed, since the two need to read as one
continuous gradient.

Per-island variation should still exist (a desert sky reads differently to
an arctic one) but as a designed choice per island, not as an automatic
derivation from a palette that was never meant to produce a sky colour.

`LIGHT_BOOST := 1.35` in `main.gd` raises the directional/ambient light
energy, which helps the ground but does nothing for the sky colour itself -
these are two separate problems and both need fixing.

### Why the sun and moon are not visible

This is the more serious gap: last session **assumed** Godot's
`ProceduralSkyMaterial` automatically draws a disc for every
`DirectionalLight3D` in the scene, based on general Godot 4 knowledge, and
never actually confirmed it on a capture or on device. It should have been
verified and was not - that is exactly the kind of corner-cutting the owner
is calling out, even though the mechanical work elsewhere was not cut.

One concrete data point from last session: setting `light_angular_size` on
the `DirectionalLight3D` nodes threw a runtime error -
`Invalid assignment of property or key 'light_angular_size'` - meaning that
property does not exist on `DirectionalLight3D` in this Godot build
(4.7.1.stable). The line was deleted to unblock everything else, but that
should have been a signal to stop and check whether the whole
disc-auto-rendering assumption was even correct for this Godot version,
rather than pressing on.

**Do this, in order:**
1. Confirm in the actual Godot 4.7 docs (not from memory) how - or whether -
   `ProceduralSkyMaterial` renders a sun disc for a scene's directional
   lights in this version, and what controls its size and visibility.
2. Capture a scene with only the sun light active, at a camera angle known
   to be looking toward it (use the existing `--yaw` capture arg), and
   confirm a visible disc actually appears in the PNG before assuming
   anything works.
3. If the automatic disc does not render, or is unreliably small/dim, the
   fallback is to draw the sun and moon explicitly: a small emissive
   billboard `Sprite3D` or an unshaded emissive sphere, positioned far along
   the light's forward direction from the camera (or from the island's
   centre) each frame, using the elevation/azimuth math already written in
   `_rest_light` (`sun_elevation`, `sun_azimuth`, `moon_elevation`,
   `moon_azimuth` - the math itself is sound, only the "does a disc actually
   show up" assumption is unverified). This is the more reliable path and
   should probably be done regardless of what step 1 finds, since an
   explicit sprite is fully controllable (size, glow, colour) in a way an
   automatic disc is not.
4. Once a sun/moon is confirmed visible, re-verify against the brightened
   sky background from the fix above - a sun disc that was invisible
   against a near-black sky may also be too subtle against a properly blue
   one without a stronger glow/bloom treatment.

---

## 5. More polish, and more of it should feel designed rather than adjusted

Last session's polish pass was real but timid: metallic on existing
materials, a shadow blob, eyes with a pupil, a slightly better crane. All
worth keeping. But "what happened to original and creative" is a fair
question about the *ambition* of the pass, not just its correctness.

Some concrete directions, not a checklist to blindly execute - use judgement
about what actually earns its cost against a phone that has to run this for
twenty-five minutes without getting hot, which has never been measured (see
`HANDOFF.md`'s carried-forward items):

- The five islands currently differ mostly in ground colour and what they
  yield. Once the sky is fixed, each island's sky should feel as distinct as
  its ground does - the arctic sky should not be the same shape of gradient
  as the desert sky, just recoloured.
- Grass, scrub and canopy are all flat-shaded low-poly, which is the
  project's whole aesthetic and should not change - but per-instance
  rotation/scale jitter on scattered elements (trees, rocks, grass tufts) is
  cheap and was not touched this session; check whether it already exists
  before assuming it needs adding.
- The house itself (`plan.gd`'s hundreds of `_add` calls) has never had a
  pass for visual coherence beyond function - once the crane's improvement
  is confirmed to look right on screen, look at whether other assembled
  structures (the scaffold, the walls) could use the same kind of small
  "make the mechanism visible" treatment (a bracing cable, a counterweight,
  a joint detail) rather than being purely functional boxes.
- Consider whether the low-poly aesthetic itself has more room to be
  distinctive - faceted normals are already a deliberate choice and should
  not be smoothed away, but things like a subtle outline/rim-light shader
  on figures (cheap on mobile, a single extra pass or a Fresnel term in the
  existing material) could push the whole thing further from "generic
  low-poly asset pack" and toward something with a specific hand-made feel.
  This is exploratory - do not force it in if it does not clearly earn its
  keep against the heat/complexity budget.

---

## 6. Order of operations

1. **Rename** (§1) first - it is small, mechanical, and every capture taken
   after this point should show the right name, so do it before generating
   any more reference screenshots.
2. **Sky and sun/moon** (§4) next - also relatively contained, and every
   later capture used to judge the character redesign will be more useful
   under correct lighting.
3. **Character redesign** (§2) - the biggest and most important item. Budget
   real time for this; it is a design problem, not a bug fix, and rushing it
   again produces the same complaint a third time.
4. **Turn/move icons** (§3).
5. **Polish** (§5), as time allows, with judgement rather than as a
   checklist.

Verify each with a close, honest capture before moving to the next - not a
wide establishing shot that hides the thing being checked.
