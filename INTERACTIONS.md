# Station guide

Look at equipment within approximately 3.5 metres and press **E**.
Equipment panels release the cursor and block movement; resource simulation
continues. Story transmissions, the title screen and pause menu freeze resources.

## Room layout

- **North wall — life support:** separate H₂/O₂ tanks, fuel cell, transfer pipe,
  conditioning block and northwest water tank.
- **West wall — supplies:** Food Supplies cabinet, main stowage, crew lockers
  and supply crates.
- **South wall — operations:** central consoles with all system tabs; a separate
  astrometry workstation opens only the radar screen.
- **East side — habitation:** berth, Pearl the cat and the Earth comms terminal.

The gold **CURRENT TASK** marker identifies the next objective's equipment.
Press **Tab/O** to expand the objective checklist. Its first two milestones
require both conditions described, and completed milestones stay complete.

## Equipment

| Equipment | Local actions |
| --- | --- |
| H₂/O₂ tanks | Inspect gas reserves, protect fuel-cell oxygen allocation, toggle CO₂ scrubber |
| Fuel cell | Start/stop, choose 25/50/100% output, inspect energy and conversion costs |
| Water tank | Inspect shared water, toggle electrolysis |
| Food cabinet | Prepare meals/drinks, eat prepared portions, drink potable water |
| Lunar greenhouse | Plant, toggle lights/misting, harvest, eat fresh produce, recover condensate |
| Storage/lockers/crates | Take, store, inspect or use items |
| Astrometry workstation | Align dish, transmit observations, inspect logs/results |
| Central operations consoles | All system tabs, comms, mission restart |
| Earth comms terminal | Resume a conversation or read recent transmissions |
| Pearl | Optional companion dialogue |

Local panels expose only their system. On smaller windows they expand to use
the available screen; on larger windows most equipment uses a right-side panel.
**How does this work?** expands an optional explanation of the current system.

## Supplies and survival

Food starts with 6 dehydrated meals, 4 ready-to-eat pouches and 4 drink packets.
Preparing a meal uses 0.30 kg water; a drink uses 0.25 kg. Opening a ready pouch
needs no added water. These are game values. Preparation adds a ready portion;
eating/drinking consumes it.

**H** consumes fresh produce first, then prepared food, then food in the suit pack.
**J** uses a prepared drink, then a packed drink, then 0.25 kg of tank water.
Emergency power cells and chemical oxygen generators are available in storage.
Oxygen generators replenish gas; they do not remove CO₂.

Warnings trigger when crossing low-resource thresholds. Recover before a vital
reaches zero. Scrubbers that stopped at depleted power must be switched back on.
The ending/failure debrief explains the result and offers replay or exploration.

## Radar and story

Stabilize water/power and inspect/consume supplies before transmitting.
The target line gives the required timestamp, azimuth, elevation and confidence.
Type values or use the fine-adjustment controls; **Assist** calibrates the next
lock if desired. Every accepted packet costs 1 EU and advances the story.

Dismiss a transmission with **Esc**, recover resources, then press **C** to
resume that exact conversation. The return-rocket choice costs 20 EU, checked
when selected. A committed decision cannot be replayed to change the ending.

The radar artwork and numbers are fictional. The game demonstrates successive
observations and resource trade-offs rather than calculating a real orbit.

**Science → NASA catalogue** is a separate historical reference browser. Its real
2010 close-approach records load offline; the Refresh button optionally fetches
updates from NASA using a locally configured key. Source status and retrieval
dates are always shown. Browsing never alters the story's observations or choices.

## Growing fresh food

The west-wall grow rack is between the Food Supplies cabinet and water-storage
area. Plant one seed/nutrient kit, enable lights and misting, and keep water and
power available. A full crop takes 180 active seconds (accelerated gameplay time).
Harvest once for two fresh portions. The H shortcut can consume fresh produce.

The collector holds 90% of processed water as condensate, not yet in the potable
tank. **Recover condensate** spends power to return as much as the tank can hold.
Insufficient water/power or a full collector stops growth; recover resources and
restart it. Crop progress is retained when switched off. Supply Crate Alpha
contains extra seed kits and hot sauce.

## Session behavior

**Esc** closes an equipment panel; with no panel open it opens the pause menu.
Settings persist locally; mission progress does not persist after quitting.
Restart begins a fresh run. After an ending, **Explore Station** freezes resource
drain while retaining the final outcome.

Cabinet models do not physically animate. Water conditioning and food preparation
are immediate abstractions. Heat, solar generation, waste recovery and radiation
shielding remain outside this release's simulation.
