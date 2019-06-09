### About DSVRandom-RV

RV is a work-in-progress randomizer for Order of Ecclesia, focused on providing multiple options for how to randomize glyph/item locations in OoE. It's a revision of a DSVania randomizer created by LagoLunatic. The logic is rewritten, allowing the player to choose more options for how they want to randomize items, but the two biggest changes from the original randomizer are:

1. Dracula's Castle is unlocked on the world map immediately, without having to fight Albus. You still need items to get anywhere in it, though.
2. Logic is customizable so that you could have glyphs and items randomized in separate pools - the Magnes glyph would not appear where equipment was in the vanilla game, for example.

The intent of RV is to create more variety in the ways that the player can approach a given seed, and also in the process decrease the average length of a seed while increasing the likelihood of challenging boss fights. It was ultimately created to satisfy my own wishes for how I want to play seeds, but I think the end result should be something closer to the difficulty curve of the original game.

Source code will be here: https://github.com/appleforyou/dsvrandom-rv however currently incomplete. For the time being I've repackaged LagoLunatic's 1.3.0 release with my new files.
Releases: https://github.com/appleforyou/dsvrandom-rv/releases

### About the original version

DSVania Randomizer is a randomizer (made by LagoLunatic) for the three Castlevania games for the Nintendo DS. If you want to read more about it, check out the github link below.

Source code: https://github.com/LagoLunatic/dsvrandom

The original code is still in RV, so you can use it for any of the 3 games if you uncheck the "Use RV Options" checkbox.

### I need more details.

There's a more in-depth rundown of the base randomizer in the github link above, but this version does have some differences. It's still very much incomplete, so you should be aware that some options in the base randomizer are not compatible with RV. Those options are:

* Map randomizer
* Villager randomizer
* Glyph behavior/element randomizer (sorta works, but has some issues)

I fully intend to restore the map randomizer functionality, but it's a big project with the way that I want to do it, so getting the item placement logic working was the first priority. The other two are easier to fix, but definitely lower priority.

Okay, so what exactly does RV do for you? The options are limited in the initial release, but they're enough for a starting point:

* Dracula's Castle can be unlocked
* Item/Glyph locations can be randomized in separate pools
* The player can select a difficulty level for item placement, representing what kind of challenges they are comfortable with. More options will likely be added later, but currently there's three: Vanilla, Creative, and Do Your Worst. The difficulty levels are explained further in the options tab, but as an example, Vanilla doesn't place progression at Training Hall, Creative does, and Do Your Worst can place progression at Training Hall even if your only progression items are Redire/Magnes.
* You can choose whether or not you want to do Cubus/Morbus puzzles for progression. This could just be player preference, and more choices like this will probably be added, but this one was important because those puzzles are a no-go if you're using glyph element/behavior randomization.
* Albus, Barlowe, and Jiang Shi can have progression glyphs on the spells they cast. They will still drop somewhere else in the world, so you won't fail to complete the game if you don't absorb them. This is intended to be paired with the unlocked castle, so that there is more reward to investing time in these bosses when they don't unlock the castle anymore.

I've also changed the default options in the randomizer to a difficulty level which I feel is probably more in line with OoE's vanilla difficulty. Consider that a heads-up if you want to change those options.

These should be enough options to start you off. My hope is that you feel more decisions of how to proceed in the game while you play - more variance like, "Should I check all the items in this area, or only the glyphs?" or, "Should I push ahead into the castle, or should I look around for more gear first?" The goal of RV is to create more decisions like that, so maybe it will work for you.

### Only OoE?

Rewriting the logic for one game has been a nontrivial amount of effort, so I don't see myself doing it for the other DSVanias. I don't think my knowledge of those games is as strong as for OoE, so I'm not sure I could trust myself to balance it the way I'd want, either. If someone else wants to make the item/location/logic databases, then maybe. That's honestly most of the work.

That said, I've kept the base randomizer code mostly intact, so it should still work for the other two DSvanias, but I've done very little testing on that so I can't guarantee it. Once map randomization functionality is restored I will have less interest in keeping support for the base version updated, but we'll see what happens.
