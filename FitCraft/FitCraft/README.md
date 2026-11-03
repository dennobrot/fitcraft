# FitCraft - Stay fit while you grind

WoW Classic Era addon (Interface 11509 / client 1.15.9). It turns game events into real-life exercise sets and keeps a lifetime log per character and across your whole account.

## Install
Copy the `FitCraft` folder to `World of Warcraft/_classic_era_/Interface/AddOns/` and restart the game (or `/reload`).

## How it works
1. Something happens in game, such as a quest turn-in, level up, death or flight.
2. A **raid-warning** announcement plays with sound, for example *"QUEST TURNED IN x3 - Time to move: 5 Push-ups x 3 sets"*.
3. A **checklist** pops up. Tick each exercise as you finish it, then click:
   - **All done!**: logs every exercise on the list.
   - **Log checked**: logs the ticked exercises. Unticked ones are saved as skipped.
   - **Skip**: logs the reminder as skipped.
   - **Later**: hides the reminder. Right-click the minimap button or type `/fit pending` to bring it back.

### Triggers (all customizable in the Setup tab)
| Event | Default |
|---|---|
| Quest turned in | 5 Push-ups + 5 KB Curls |
| Level up | 20 Squats + 20 KB Halos |
| Death | 20 Burpees |
| Flight path | Mobility until you land. A live timer runs during the flight, and the real flight time is logged. |
| Boss defeated | 2x10 Lunges |
| Great loot (choose min quality) | 15 Sit-ups for Epic+ |
| Rare mob killed *(off)* | 30 Jumping Jacks |
| Entered dungeon/raid *(off)* | 60s Plank |
| Hearthstone used *(off)* | 20 Jumping Jacks |
| New spell learned *(off)* | 3 Push-ups |

Each trigger can have any number of exercises, with any reps or seconds per set and any number of sets.
- **Stack**: if the same event fires again while its reminder is still open, the sets are added to that reminder. Three quests in a row become one popup with 3 sets.
- **Combat-safe**: events that happen during combat are queued and shown when combat ends. You can turn this off in Options.
- **Flight**: give a *seconds* exercise a value of 0 and it logs your actual flight time.

## Tabs
- **Setup**: turn triggers on or off and choose the exercises, reps and sets for each. Use *Test reminder* to preview one. Tests are never logged.
- **Exercises**: your exercise library. Add, rename or delete exercises, and set each one to count reps or seconds. Deleting an exercise that has data archives it instead, so your totals are kept.
- **History**: every set you did or skipped, for this character or all characters. You can also log extra work by hand here.
- **Totals**: account-wide lifetime, today and 7-day totals per exercise, plus your completion rate.
- **Characters**: lifetime stats for each character, including how many times each event fired.
- **Options**: pause (rest day), sound, raid-warning text, combat deferral, flight panel, chat echo, minimap button and maintenance tools.

## Minimap button and commands
- Left-click: open the window. Right-click: open pending sets. Shift+right-click: pause or resume. Drag: move the button.
- `/fit` `/fit pending` `/fit pause` `/fit minimap` `/fit test <quest|level|death|flight|boss|rare|loot|dungeon|hearth|spell>`

Data is stored account-wide in `WTF/Account/<ACCOUNT>/SavedVariables/FitCraft.lua`.

*Train within your limits. FitCraft reminds you to exercise. It is not a coach.*
