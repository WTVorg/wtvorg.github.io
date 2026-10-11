# Brew Guardians

A Roblox game where you brew capture flasks in your cauldron, wear wild
guardians down in chases, feed them their favorite ingredient, and throw.
Then you sweat through the shakes. Caught guardians live on your plot, earn
coins, and can be fused in the pot into giant mutated forms.

## Open it

**Quickest:** open `BrewGuardians.rbxlx` in Roblox Studio and press Play. The
map, guardians and UI are all built by script, so no assets need uploading.

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
| Brew | Cauldron on your plot | 3 ingredients + 1 vial → a flask. Quality = sum of tiers (+ cauldron bonus): Clay x1, Glass x1.5, Crystal x2.2, Starlight x3.5 |
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
src/server/
  WorldBuilder.luau         hub, paths, zones, hazards, ingredient nodes, shop stall
  GuardianService.luau      spawning, chase AI, attacks, hazards, resistance
  GuardianModels.luau       placeholder bodies / your custom models
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

## Placeholder content to replace

- Sounds use built-in `rbxasset://` engine sounds. Swap them in `Config.Sounds`.
- Guardian bodies, trees, rocks and crystals are simple parts.
