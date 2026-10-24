# Hightail — example design

A side-scrolling escape runner for iPhone. You do not finish by surviving an endless loop, and you do not finish by dying. Every stretch is one more block you put behind you. The game ends once, when you clear the last gate and the road in front of you is empty.

Failure is a delay. Three hits restart the stretch you are on. Cleared stretches stay open. There is no bad ending.

## Fantasy

You are already out of the building. What is left is eight stretches of road between you and a bridge nobody is guarding. The city gets louder, then the last stretch goes quiet, then there is a green gate. Crossing it is the credits.

## The minute of play

The runner holds a fixed spot on the left third of a landscape screen and moves forward on their own. The road comes at them.

- **Jump** (top half). Tap and let go for a short hop. Hold for a long jump. Tap again in the air for a second jump. Letting go while you are still rising cuts the arc.
- **Roll** (bottom half). Hold to tuck and speed up. The tuck eases in and out. If you roll off a gap, gravity keeps you falling until you land. Let go and you stand back up only after you are on the ground.
- **Animals** stay on all fours and bound. Jump on a back for 100. A fast roll through one pays 350. Running into one upright costs a heart.

A hit breaks that obstacle, costs one of three chances, and gives a short invulnerable beat so a cluster cannot stunlock you. At zero chances the stretch resets. The exit does not move.

## Why it gets harder

Difficulty is a stack, not a speed multiplier hiding the same level.

Each stretch introduces at most one new read, then later stretches combine them and shorten the gap between decisions. Every stretch, including the last, ends with a clean sprint of about two and a half seconds into the gate. The quiet is the reward inside the level. The last quiet is the ending.

| Stretch | Name | New read | Speed | Road | Spacing | Pairs |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Alley | Crate. Jump it. | 300 | Short runway, about 27s | Wide | No |
| 2 | Dock | Rail. Roll, do not jump. | 345 | Longer | Tighter | No |
| 3 | Yard | Stack. Taller and wider, jump earlier. | 390 | Longer | Tighter | No |
| 4 | Overpass | Gap. Stay in the air across missing ground. | 440 | Longer | Tighter | No |
| 5 | Sweep | Enemy. Roll through him and he drops. | 490 | Longer | Tighter | No |
| 6 | Scaffold | Same set, now in pairs: jump, then roll. | 545 | Longer | Tighter | Yes |
| 7 | Highway | No new shape. Less road between mistakes. | 600 | Longer | Tight | Yes |
| 8 | Bridge | All of it, then the longest quiet, then the gate. | 650 | Longest, about 35s | Tightest | Yes |

Exact curves live in `Hightail/Game/LevelCatalog.swift`. Change a row there and the scene follows. Do not bury numbers in the spawner.

Reaction time stays honest because obstacles enter from the right edge. At stretch 1 you see a crate for about two seconds. At stretch 8 you still get about a second, and a pair sits on screen together so the second obstacle is not a surprise pop-in.

Jump height clears a stack with room. It does not clear a rail. Gap widths stay under half a second of air time at that stretch's speed, so a committed jump works and a late tap falls in.

## Controls

Landscape only. No buttons on the road. The screen is split in half, and holding is different from a tap.

- Top half: jump. Release early to cut it. Hold to stay light on the way up. A second tap in the air spends the extra jump.
- Bottom half: roll. Hold to keep the tuck and to run fast. That fast roll is the high score.
- Labels on the glass do not catch taps.

Stretch 1 only asks for a jump. The roll is taught when the first rail shows up. Knocking a guy down is taught on stretch 5, the first time one is in the lane.

## Session shape

1. Map. Eight stretches. Locked ones show their name and what they will teach, but do not start.
2. Run. Hearts, stretch name, a bar that fills toward the gate.
3. Stretch clear. One line of what you left behind. Continue, or back to the map.
4. Caught. "The stretch resets. The exit doesn't." Retry.
5. After stretch 8 only: the escaped screen. No next level. Run the night again if you want; the map stays unlocked.

Unlocks are stored on device. Nothing is an account.

## What the screen is doing

Night road, not a cartoon city. Ink sky, asphalt, sodium lamps, ivory runner, one escape-green light that exists only at the gate. Parallax is three speeds: buildings, lamps, ground. Hits shake the road, not the HUD. The gate is a column of green you can see before you reach it, so the goal reads before the collision does.

No score attack. Forward is the only score. A tally would argue with the ending.

## Project shape

```
Hightail/
  HightailApp.swift          window, dark, landscape app
  Game/LevelCatalog.swift   the eight stretches and the spawn rules
  Game/GameScene.swift      run, jump, roll, collide, gate
  UI/RootView.swift         map, HUD, clear, caught, escaped
```

SpriteKit owns the second-to-second. SwiftUI owns the sentences. Neither one reaches into the other's numbers.

## What this example leaves out

Sound, a real runner sheet, dust, and a second lane. Add those after the eight stretches feel fair. A new obstacle belongs in the catalog's kind list and in one stretch's introduction row before it shows up in a pair.

## Fairness checks already in the scene

- You cannot jump a rail. You can always roll it.
- A roll that touches an enemy knocks him down and does not cost a heart. Upright contact does.
- A stack is taller than a crate and still under the jump apex.
- Gaps are narrower than the air time at that stretch's speed.
- The last 2.4 seconds of every stretch are empty on purpose.
- One hit cannot chain into a second hit for just over a second.
- The obstacle you hit is gone. The stretch continues until the hearts run out.
