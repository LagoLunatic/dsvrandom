
### About

DSVania Randomizer is a randomizer for the three Castlevania games for the Nintendo DS: Dawn of Sorrow, Portrait of Ruin, and Order of Ecclesia. It's only compatible with the North American versions.  

Download the latest release: https://github.com/LagoLunatic/dsvrandom/releases  

Source code: https://github.com/LagoLunatic/dsvrandom  
Report issues here: https://github.com/LagoLunatic/dsvrandom/issues  

### What does it randomize?

DSVRandom has options to randomize:  
Items/Skills: Randomizes items and skills you find lying on the ground.  
Enemy Locations: Randomizes which non-boss enemies appear where.  
Enemy Drops: Randomizes the items, souls, and glyphs dropped by non-boss enemies, as well as their drop chances.  
Boss Souls: Randomizes the souls dropped by bosses as well as Wallman's glyph (DoS/OoE only).  
Equipment Stats: Randomizes weapon and armor stats.  
Weapon Behavior: Randomizes how weapons behave.  
Consumable Behavior: Randomizes what consumables do and how powerful they are.  
Skill Stats/Behavior: Randomizes skill stats and how skills behave.  
Shop Items: Randomizes what items are for sale in the shop and item prices.  
Wooden Chest Items: Randomizes the pool of items for wooden chests in each area (OoE only).  
Villagers: Randomizes where villagers are located (OoE only).  
Weapon Synthesis: Randomizes which items Yoko can synthesize (DoS only).  
Enemy Stats: Randomizes enemy stats, weaknesses, and resistances.  
Enemy Animation Speed: Randomizes the speed at which each enemy's animations play at, which affects their attack speed.  
Portraits: Randomizes where portraits are located (PoR only).  
Red Soul Walls: Randomizes which bullet souls are needed to open red walls (DoS only).  
Maps: Randomly generates entirely new maps and connects rooms to match the map.  
Starting Room: Randomizes which room you start in.  
Room Connections (Not map-friendly): Randomizes which rooms within an area connect to each other. (The map is not useful with this option, so finding where to go can be extremely difficult.)  
Area Connections (Not map-friendly): Randomizes which areas connect to each other.  
Background Music: Randomizes what songs play in what areas.  
Cutscene Dialogue: Generates random dialogue for all cutscenes.  
Player Sprites: Randomizes the graphics of player characters.  
Skill Sprites: Randomizes the graphics used by each skill (this can sometimes crash when used on real hardware).  

As well as several other options that change how the game is played:  
Scavenger Mode: Common enemies never drop items, souls, or glyphs. You have to rely on pickups you find placed in the world.  
Unlock Boss Doors (DoS only): You don't need magic seals to open boss doors.  
Short Mode (PoR only): Removes 4 random portrait areas from the game. Unlocking Brauner requires beating the bosses of the 4 portraits that remain (not counting Nest of Evil).  
Open World Map (OoE only): Make all areas except Dracula's Castle accessible from the start.  
Allow Requiring Glitches to Win: If checked, certain glitches may be necessary to beat the game.  
Bonus Starting Items: Starts you out with 3 random extra items and 3 random extra skills.  

There are also some buggy, experimental randomization options:  
Players: Randomizes player movement stats.  
Boss Locations: Randomizes which bosses appear where.  
World Map Exits: Randomizes the order areas are unlocked on the world map (OoE only, and the Open World Map option must be disabled).  
Enemy Sprites: Randomizes the graphics of non-boss enemies.  
Boss Sprites: Randomizes the graphics of bosses.  

Every seed should be completable as long as you don't use the experimental options.  
If you think you've found a seed that's unwinnable, first check the spoiler log (located in the same folder as the randomized ROM) to make sure you haven't missed something.  
If you haven't missed anything then you can report the bug here: https://github.com/LagoLunatic/dsvrandom/issues  
When making a bug report be sure to include the seed, randomizer version number, and all the options you checked. The easiest way to do that is to simply copy paste the relevant entry from the spoiler log, which lists all of those.  

### Requirements

The path where DSVRandom is located must only have ASCII characters in it - the program will not launch if there are any unicode characters in it.  

Install Visual C++ Redistributable for Visual Studio 2015: https://www.microsoft.com/en-us/download/details.aspx?id=48145  

### FAQ

Q: Do I need to farm enemies to progress?  

A: No, progression items and skills won't drop from common enemies. They'll be laying around somewhere.  
All bosses (except Dario) in DoS and Wallman in OoE can also drop progression skills.  

Q: Do I need to damage boost or jumpkick off enemies to progress?  

A: No, progressing won't require anything involving common enemies. You won't need to jump on spikes either.  

Q: I can't find something I need to progress!  

A: You might have forgotten a breakable wall. Progression items and skills can be hidden inside breakable walls.  
If you check the "Reveal breakable walls" option in the Game Tweaks tab, all breakable walls will always blink as if you had Peeping Eye/Eye for Decay on.  
You can also check the spoiler log located in the same folder as the randomized ROM. This lists the area that each progression item got placed in.  

Q: I fell into a pit and can't get back out without jump upgrades!  

A: Check your inventory if you're using any of the room/map randomization options or the portrait randomizer option. You have a magical ticket that doesn't get consumed when used, so you can use that to return to your starting room any time you get trapped like this.  
But if you're not using any of those options you won't have an infinitely usable magical ticket, in which case you may want to report this as a bug.  

Q: I can't make the jump in the room after Flying Armor.  

A: You can make the jump without any souls by doing a backdash jump off the very edge: http://i.imgur.com/ZXSHMcw.gif  

Q: I have double jump, but I can't progress in Minera Prison Island without Magnes.  

A: Do a jumpkick off the breakable wall next to the Magnes point: http://i.imgur.com/y0TXcE0.gif  
Note that you must angle the jumpkick straight down. The hitbox on Shanoa's foot is too small to hit the wall when doing a diagonal jumpkick.  

Q: I have Puppet Master, but can't find a way out of Wizardry Lab.  

A: You can activate the moving platform in the long room at right side of Wizardry Lab, then walk to the end of the room and use Puppet Master to get on top of the platform: https://i.imgur.com/l6NuZPY.gif  

Q: Why can I charge spells in midair sometimes?  

A: One of the things the Skill Behavior randomization option does is randomly allowing skills to be used in midair that normally only work on the ground. This can happen regardless of whether Jonathan or Charlotte gets the spell.  

Q: In vanilla DoS, getting ability souls out of order (like Doppelganger before Balore) gives multiple abilities for the price of one. But this doesn't seem to work in the randomizer?  

A: This is a bug in the vanilla game that the randomizer fixes.  

Q: I'm using some experimental options, and I think I'm stuck.  

A: The experimental options are incomplete and it's rare for the game to be beatable if you use them.  

Q: There are a few candles with glitchy, corrupted-looking graphics.  

A: This is a known bug that happens in DoS sometimes.  

Q: I'm playing Portrait of Ruin randomized on my flash card, and getting a lot of crashes.  

A: This is a bug with PoR that occurs only on certain flash cards, such as R4 cards. It happens in vanilla PoR too, so it's unrelated to the randomizer. I recommend playing on emulator if you get this issue on your card.  

Q: There's a randomly placed enemy that keeps knocking me back through a door as soon as I walk through so I can't progress.  

A: Enemies knock you back depending on what direction you're facing, not the direction they hit you from. So when you're walking through the door and don't have control yet hold the D-pad in the direction away from the enemy. This way you will face away from the enemy the instant you gain control and be knocked towards the enemy instead of back into the door.  

### Running from source

If you want to run the latest development (unstable) version of DSVRandom from source, follow these instructions:  

* First you must download DSVEdit's source code and follow the instructions in its readme to get DSVEdit running from source: https://github.com/LagoLunatic/DSVEdit
* Then download DSVRandom's source code and put the dsvrandom folder inside the DSVEdit folder.
* Run the `build_ui` batch file located in the dsvrandom folder to compile DSVRandom's UI files. (Not to be confused with the `build_ui` file in the DSVEdit folder - that one only compiles DSVEdit's UI files.)
* Finally run `ruby dsvrandom/dsvrandom.rb` to launch DSVRandom.
* Note that later on when updating to a future version of DSVRandom, you should also update DSVEdit at the same time.
