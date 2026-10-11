# Brew Guardians

A Roblox game where you brew capture flasks in your cauldron, wear wild
guardians down in chases, feed them their favorite ingredient, and throw.
Then you sweat through the shakes. Caught guardians live on your plot, earn
coins, and can be fused in the pot into giant mutated forms.

## Open it

1. Open `BrewGuardians.rbxlx` in Roblox Studio (**File → Open from File**).
2. **Import the art pack (once).** **File → Import 3D**, pick
   `art/BrewGuardiansArt.fbx`, keep the default settings and click
   **Import**. Leave the model wherever it lands; the game finds it, fixes
   its orientation and scale, and tidies it away when you press Play.
3. **Import the sounds (once).** Open the **Asset Manager**, click
   **Bulk Import**, and select every file in `art/sounds/`. When they finish
   uploading, drag them from the Asset Manager into **SoundService** in the
   Explorer. The game picks them up by name (`BG_Throw`, `BG_Lock`, ...).
4. **File → Save**, then press **Play**.

Skipping steps 2 or 3 still works: the game falls back to its part-built
models and engine sounds (and reminds you in Studio).

Roblox only shows meshes and audio once they're uploaded to your account,
which is why those two steps can't be done for you inside the file.

**With Rojo (for editing the code in VS Code):**

```sh
rojo serve          # then click Connect in the Rojo Studio plugin
rojo build -o BrewGuardians.rbxlx   # rebuild the place file
```

To keep progress while testing in Studio, turn on
*Game Settings → Security → Enable Studio Access to API Services*.

## The loop

| Step | Where | What happens |
|---|---|---|
| Harvest | Glowing plants in the 3 zones | Ingredients, tier 1 to 4 |
| Brew | Cauldron on your plot, or the big public one in the hub | 3 ingredients + 1 vial → a flask. Quality = sum of tiers (+ cauldron bonus): Clay x1, Glass x1.5, Crystal x2.2, Starlight x3.5 |
| Weaken | In the zone | Dodge red telegraphs (−resistance), lure it into hazards (big −resistance + stun), throw a Weakening Draught (−resistance + slow) |
| Feed | Action bar → Feed | Its favorite ingredient doubles your odds and calms it. A wrong guess teaches you, and the Journal keeps track |
| Throw | Select a flask, tap the guardian (or press F) | 3 shakes, then it locks or bursts out. If it bursts out, it's furious: resistance back up, faster attacks |
| Earn | Your plot | Guardians make coins per second. Collect at the gold pad |
| Fuse | Cauldron → Fuse | Guardian + 3 ingredients → Giant / Mutant / Colossal (income x2.5 / x6 / x15) |

**Catch odds** (`src/shared/CatchMath.luau`):
`base rate × flask × (3 − 2 × resistance) / 3 × favorite × stunned/slowed × luck`.
Each of the 3 shakes passes with chance `p^(1/3)`, so the overall odds are
exactly `p` and a last-shake near miss happens about as often as it would in a
fair game. The overhead panel on each guardian shows your live odds for the
selected flask, which teaches players that weakening it pays off.

## Controls

- Click or tap a guardian: use the selected action-bar slot
- `1`–`8`: pick a slot, `F` (or R2): use it on the nearest guardian
- Prompts: Harvest, Brew, Collect, Shop

## Files

```
src/shared/Config.luau      every number: guardians, ingredients, flasks, zones, shop
src/shared/CatchMath.luau   odds + shake timing (shared so client and server agree)
src/shared/Remotes.luau     RemoteEvents
src/shared/Sounds.luau      sound slot -> imported BG_ sound or Config fallback
src/shared/ArtManifest.luau generated list of art pack assets
src/server/
  Art.luau                  finds the imported art pack and makes templates
  Environment.luau          lighting, sky, clouds, post-processing
  Landscape.luau            terrain, hills, mountains, volcano, lake, forests
  Build.luau                part helpers: ellipsoids, rings, horns, text signs
  Props.luau                cauldrons, fences, lanterns, trees, gates, stalls, plants
  WorldBuilder.luau         hub, paths, zones, hazards, ingredient nodes, shop stall
  GuardianService.luau      spawning, chase AI, attacks, hazards, resistance
  GuardianModels.luau       your model > art pack mesh > part-built fallback
  Actions.luau              throw, feed, brew, fuse, buy, release, Robux receipt
  Plots.luau                plots, display, income, collector
  PlayerData.luau           DataStore save/load with retries + BindToClose
  Harvest.luau              ingredient nodes
src/client/
  CaptureFX.luau            throw arc + the shake sequence
  Hud.luau / Menus.luau     HUD, action bar, Brew/Shop/Journal/Collection/Help
  Targeting.luau            tap-to-throw, hover highlight, overhead odds panel
```

## Add your own guardian

1. Add an entry to `Config.Guardians` and its id to `Config.GuardianOrder`
   (zone, rarity, base rate, favorite ingredient, behavior, attack numbers).
2. To use your own model, put a Model named after the id in
   `ServerStorage/GuardianModels`. Give it a PrimaryPart at the body's center,
   roughly `Size` studs tall. Without one, a placeholder body is built from parts.

Behaviors: `Skittish` (flees, slams when you corner it), `Charger`
(telegraphed dash, so lure it through hazards), `Caster` (orbs at your feet),
`Legendary` (cycles through all three).

## Monetization

`Config.Monetization.LuckBoostProductId` sells a timed luck boost when you set
it to a Developer Product id. Flasks are never sold for Robux. A purchase that
gives a random chance at a creature counts as a paid random item under Roblox
rules, which require you to disclose the odds.

## Art pack

Everything in `art/` is generated from code in `art/tools/` with Blender's
Python module, so it can be rebuilt or extended:

```sh
pip install bpy numpy soundfile scipy
python art/tools/creatures.py -- out/creatures        # 6 guardians
python art/tools/props.py -- out/props                # cauldron, trees, rocks, chest...
python art/tools/combine.py -- art/BrewGuardiansArt.fbx src/shared/ArtManifest.luau out/creatures out/props
python art/tools/sounds.py art/sounds                 # every sound effect + music loop
```

- Guardians are sculpted from fused, smoothed shapes with baked colour
  textures; glowing bits (flames, gems, lava) are separate `_Glow` meshes the
  game renders as Neon in each guardian's accent colour.
- The pack carries three marker meshes (`ArtOrigin`, `ArtForward`, `ArtUp`),
  so `src/server/Art.luau` can recover the importer's axes and units exactly.
- `art/previews/` has renders of every asset and the world.

To replace a guardian with your own model, put a Model named after it in
`ServerStorage/GuardianModels` (with a PrimaryPart); that wins over the pack.

## Sounds

`art/sounds/` holds synthesised effects (throw, shake, catch, break free,
brew, harvest, coins, UI click) and a music loop. Any Sound named
`BG_<Slot>` in SoundService overrides the matching slot in `Config.Sounds`,
so swapping one is just importing a new file with the same name.

## World

The ground is Roblox Terrain (swaying grass, snow, glacier ice, glowing
cracked lava, water) with hills, a mountain ring, a volcano behind Ember
Caldera, a lake, and forests between the areas (`src/server/Landscape.luau`).
Lighting uses Future lighting, atmosphere, clouds, bloom and colour grading
(`src/server/Environment.luau`). The play areas stay flat because guardians
walk on a flat plane.
