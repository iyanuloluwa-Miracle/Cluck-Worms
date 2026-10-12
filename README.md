# Cluck & Worms

Premium Zuma-style 2D puzzle — **Godot 4.3+**, GDScript only.

---

## How to run

1. Open the project in Godot 4.3+
2. Press **F5**
3. **Play** from the main menu (chicken mascot title screen)

| Input | Action |
| --- | --- |
| LMB / tap | Shoot |
| RMB / Space | Swap |
| Esc / P / HUD pause | Pause |
| UI buttons | Advance / retry / menu |

### UI

Mobile-first overlays with shared meadow/yolk styling, 56px touch targets, fade/pop transitions, and HUD chips for score, lives, next worm, level, and pause.

---

## Game states

```
MainMenu → Playing ⇄ Paused
Playing → LevelComplete → Playing (next level)
Playing → StageComplete → Playing (next stage) or MainMenu
Playing → (life lost) → Playing (retry) or GameOver
GameOver → Playing (restart run) or MainMenu
```

Owned by **GameManager**; UI and levels only listen on **EventBus**.

---

## Progression

- `ProgressionCatalog` ships **2 stages × 2 levels** (same scene, tuned difficulty)
- Add stages/levels via `LevelDef` / `StageDef` resources
- High score saved to `user://cluck_and_worms_save.cfg` (**SaveService**)

---

## Scoring

| Source | Notes |
| --- | --- |
| Base per worm | `points_per_worm` |
| Extra beyond 3 | `points_per_extra_worm` |
| Large groups (5+) | `large_group_bonus_per_worm` |
| Cascades | `cascade_bonus_per_depth` |
| Combo multiplier | steps up each match wave; resets on failed shot |
| Level / stage clear | flat bonuses + leftover-life bonus on stage clear |

**Lives:** start with 3. Chain reaching the end costs a life and reloads the level. At 0 → GameOver.

---

## Architecture

```
EventBus          signals only
SaveService       high score persistence
GameManager       state machine, score, lives, catalog
Main              loads levels on EventBus.load_level_requested
UI/*              menu / pause / complete / game over / HUD
Level             path + chain + chicken only
```
