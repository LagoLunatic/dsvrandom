
DSVRandom (DSVania Randomizer) is a randomizer for the three Castlevania games for the Nintendo DS: Dawn of Sorrow, Portrait of Ruin, and Order of Ecclesia. Currently it's only compatible with the North American versions.

Source code: https://github.com/LagoLunatic/dsvrandom
Report issues here: https://github.com/LagoLunatic/dsvrandom/issues

### Features

DSVRandom has options to randomize:
Items/Skills: Randomizes items and skills you find lying on the ground.
Enemy Locations: Randomizes which non-boss enemies appear where.
Enemy Drops: Randomizes the items, souls, and glyphs dropped by non-boss enemies, as well as their drop chances.
Boss Souls: Randomizes the souls dropped by bosses as well as Wallman's glyph (DoS/OoE only).

There are also some buggy, experimental options:
Players: Randomizes player graphics and movement stats.
Boss Locations: Randomizes which bosses appear where.
Area Connections: Randomizes which areas connect to each other.
Room Connections: Randomizes which rooms within an area connect to each other.
Starting Room: Randomizes which room you start in.
Enemy AI: Shuffles the AI of non-boss enemies.
Item Stats: Randomizes item stats and how weapons behave.
Skill Stats: Randomizes skill stats and how skills behave.
Enemy Stats: Randomizes enemy stats.
Weapon Synthesis: Randomizes which items Yoko can synthesize (DoS only).
Shop Items: Randomizes what items are for sale in the shop.
Wooden Chest Items: Randomizes the pool of items for wooden chests in each area (OoE only).

Every seed should be completable as long as you don't use the experimental options, though there may be bugs in the randomizer that make some seeds unwinnable.

### Requirements

The path where DSVRandom is located must only have ASCII characters in it - the program will not launch if there are any unicode characters in it.

Install Visual C++ Redistributable for Visual Studio 2015: https://www.microsoft.com/en-us/download/details.aspx?id=48145

### FAQ

Q: Do I need to farm enemies to progress?

A: No, progression items and skills won't drop from common enemies. They'll be laying around somewhere.
Bosses in DoS and Wallman in OoE can also drop progression skills.

Q: I can't find something I need to progress!

A: You might have forgotten a breakable wall. Progression items and skills can be hidden inside breakable walls.
You can check the spoiler log located in /logs/spoiler_log.txt. This lists the area that each progression item got placed in.

Q: I can't make the jump in the room after Flying Armor.

A: You can make the jump without any souls by doing a backdash jump off the very edge: http://i.imgur.com/ZXSHMcw.gif

Q: I have double jump, but I can't progress in Minera Prison Island without Magnes.

A: Do a jumpkick off the breakable wall next to the Magnes point: http://i.imgur.com/y0TXcE0.gif
Note that you must angle the jumpkick straight down. The hitbox on Shanoa's foot is too small to hit the wall when doing a diagonal jumpkick.

Q: I found Konami Man/Twin Bee/Vic Viper in Portrait of Ruin, but I didn't get a stat boost.

A: Save and reload the game for it to take effect.
