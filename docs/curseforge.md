<!--
CurseForge project page. Paste the summary into the "Summary" field, and everything under
"Description" into the description editor with the markup type set to Markdown.
Keep it in step with README.md.
-->

# Summary

Press Shift+Space and type to open any panel, cast a spell, change a setting or run an addon command. For WoW Forever.

# Description

**Lookup** is a search box for WoW Forever. Press **Shift+Space**, type a few letters and press **Enter**. Lookup opens the panel, casts the spell, changes the setting or runs the command, and the box closes.

You no longer need to remember which tab a setting is on, which micro button opens Legacy, or how an addon spells its slash command.

## What you can search

- **Panels and tabs**: Character, Skills, Statistics, Reputation, Currency, Spellbook, Talents, Professions, Legacy (Reward Track, Challenges, Tree), Quest Log, Collections, Calendar and more
- **Settings**: on/off settings change in place, and the row shows the new state. Other settings open at their page
- **Spells**: Enter casts the spell. Shift+Enter opens the spellbook on its tab
- **Zones, cities, dungeons and raids**: open the map there
- **Quests in your log**: open the quest
- **Mounts, pets and toys**: open Collections on them
- **Macros**: open the macro window on the macro
- **Bag items**: open your bags with the item highlighted
- **Currencies, reputations and Legacy Challenges**: open the right tab, or the challenge itself
- **Slash commands** from the game and from your other addons, with the addon's name beside each one
- **Addon launchers**: the buttons other addons put on your minimap or data broker bar
- **Friends and guild members**: start a whisper
- **Key bindings**: find a binding and open Key Bindings

Lookup remembers what you pick, so the things you use most come first. An empty box shows your recent picks.

## Commands

Type **/** to list only slash commands. Select one and press **Space** to add text after it. For example, type `/auctionator`, press Space, type `post` and press Enter to run `/auctionator post`. Next time, Lookup suggests the text you used before.

## Calculator

Type a sum such as `1250*3` or `(40+12)/4`. The first row shows the answer.

## Keys

- **Shift+Space**: open or close the box. Change the key in Key Bindings, under Lookup. `/lookup` also opens it.
- **Up / Down**: select a row
- **Enter**: run the selected row
- **Shift+Enter**: run the row and keep the box open. On rows with a second action, such as spells, it runs that action. The bottom line of the box always shows what each key does.
- **Ctrl+Backspace**: delete a word
- **Esc**: close
- Drag a spell, item or macro row to your action bars.

## Good to know

- **Out of combat only.** The box closes when combat starts. In combat, Blizzard does not let addons open panels or cast spells from a search box.
- **Light.** Lookup has no data files. It reads what it needs from the game when you open the box.
- **No taint.** Panels open through Blizzard's own key bindings and secure buttons, the same way your keys and micro menu open them. Lookup does not run panel code itself, so it leaves your action bars working in combat.
- `/lookup reset` makes Lookup forget your picks and command history.

## Feedback

Found a bug or have an idea? Open an issue on [GitHub](https://github.com/Mathih13/lookup/issues). The source is there too, under the MIT licence.
