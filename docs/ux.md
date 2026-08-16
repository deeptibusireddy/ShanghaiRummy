# Shanghai Rummy — UX & Interaction Design

> Owner: @deeptibusireddy · Updated: 2026-08-10 · Style: contemporary family game night

This doc is the source of truth for how the game *feels*. The SpriteKit scene
in M2b implements what's specified here. Any UX change should update this
file first, then the scene.

## Design principles

1. **Cards first.** Cards, melds, and the current turn dominate the visual
   hierarchy. Table texture and chrome stay quiet.
2. **One-tap where possible, drag where it matters.** Draw / discard are
   taps. Meld staging is drag & drop so the physical act of building a
   meld matches the mental one.
3. **Independent-contract clarity.** Each seat displays that player's
   current level and running score. You always know where you stand
   relative to the others.
4. **Keep the table live.** Core play never opens a blocking modal. Contract
   cards move through an inline private tray while the public table remains
   visible.
5. **Landscape only on iPhone and iPad.** Portrait cramped six players onto
   too little horizontal space; landscape gives every seat room.

## Screen orientation & size

- **Orientation:** Landscape only (locked).
- **Aspect ratio targets:** Adaptive from the iPhone 15 family
  (852×393 pt in landscape) through full-size iPad layouts
  (1194×834 pt and larger).
- **Device support:** The universal target runs natively on iPhone and iPad.
  iPad uses its full canvas instead of iPhone compatibility-mode zoom.
- **Safe areas:** The full-bleed table may extend behind the camera/Dynamic
  Island and home indicator, but seats, player names, the local HUD, hand, and
  controls use the device's live landscape safe-area insets. Edge seating is
  clamped symmetrically so either landscape orientation remains readable.

## Table zones

Every hand renders the following zones. All coordinates are logical
percentages of the game surface so they scale to any device.

```
┌────────────────────────────────────────────────────────────────┐
│  ┌──────┐   TOP SEAT (opponent, if 3+ players)   ┌──────┐      │
│  │Melds │   Name · Level · Score                 │Melds │      │
│  └──────┘                                        └──────┘      │
│                                                                │
│  LEFT SEAT             ┌──────┐  ┌──────┐            RIGHT SEAT│
│  Name · Lvl · Sc       │Stock │  │Discard│      Name · Lvl · Sc│
│  ┌────┐                └──────┘  └──────┘             ┌────┐   │
│  │Meld│                                               │Meld│   │
│  └────┘                                               └────┘   │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │        YOUR MELDS (once you've gone down)                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌────────────────── YOUR HAND (fanned) ────────────────────┐  │
│  │  ♠5  ♠6  ♠7  ♥Q  ♦K  🃏  ♣2  ...                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                            YOU · Lvl · Sc · Contract           │
└────────────────────────────────────────────────────────────────┘
```

### Zone breakdown

| Zone              | What it holds                                        |
|-------------------|------------------------------------------------------|
| **Center piles**  | Stock (face-down) + Discard (face-up top card)       |
| **Your hand**     | Bottom strip, cards fanned & sorted, drag source     |
| **Your info**     | Below hand: name, current level, cumulative score, contract for your level |
| **Your melds**    | Just above your hand, horizontal row (empty until you go down) |
| **Opponent seats**| Left / right / top edges — avatar, name, cards, and level |
| **Opponent meld strip** | Adjacent to each opponent's name & level     |
| **Turn banner**   | Top strip with active player's name, cards in hand, level, and contract |
| **Context action**| Bottom right only when a real action such as Save Meld or Go Down is available |
| **Utility controls** | Top right: Score, Rank, and Suit |

## Seat layouts by player count

Your seat is always at the bottom. Opponents fill the other edges.

### 2 players

```
        TOP: opponent
       Melds - Info
         [pile pile]
       Your melds
       Your hand
       YOU: Info
```

### 3 players

```
          TOP: opp #2
    LEFT: opp #1     (piles)
          Your melds
          Your hand
          YOU
```

### 4 players

```
          TOP: opp #2
LEFT: opp #1   piles   RIGHT: opp #3
          Your melds
          Your hand
          YOU
```

### 5 players

```
   TOP-LEFT: opp #2      TOP-RIGHT: opp #3
LEFT: opp #1   piles          RIGHT: opp #4
          Your melds
          Your hand
          YOU
```

### 6 players

```
   TOP-LEFT: opp #2  TOP: opp #3  TOP-RIGHT: opp #4
LEFT: opp #1    piles              RIGHT: opp #5
          Your melds
          Your hand
          YOU
```

For 5 & 6 players, the top-corner seats move outward so their melds stay in
pile-free outer bands. A sixth player's center-top melds split into readable
left and right wings beside that seat. This is the constraint that ruled out
portrait mode.

On iPhone, the hand cards render slightly smaller than their full logical size
to reserve a dedicated tableau lane. Meld cards use larger, more exposed faces
and stronger container outlines so ranks and suits remain readable. Crowded
side-seat melds wrap into two rows with a 34% card-scale floor; only card
overlap tightens on especially narrow screens, while at least 25% of each card
remains exposed. Five/six-player and compact-width layouts use smaller,
avatar-first opponent pills to reserve that space. All opponent layouts preserve
a protected corridor around the shared piles. The discard drop zone follows the
visible pile instead of extending into the tableau; if padded targets ever
touch, the nearest visual target wins and an exact tie favors the meld.

### Player status hierarchy

- The top banner is the single glanceable active-turn summary: active name,
  hand count, level/contract, and current guidance.
- Seat pills are the spatial roster. They always retain name, hand count, and
  level; amber border, avatar, and halo styling identify the active player
  without replacing useful details with another turn label.
- The bottom-left local HUD remains the persistent personal reference for name,
  score, level, and contract.
- The bottom-right area is reserved for real enabled actions. Passive prompts
  and duplicated "[name]'s turn" boxes are omitted because guidance already
  lives in the top banner.
- Purchase and hand-summary overlays remain transient and role-specific.
- **Score**, beside Rank and Suit, opens a dismissible live standings card with
  player name, current level, and cumulative score, ordered lowest score first.
  It is display-only and remains available during purchase decisions.

## Interaction spec

### Drawing (start of your turn)

- A blocking, role-specific purchase overlay pauses table interaction.
- The turn player sees **Your Draw** and explicitly chooses **Take [card]** or
  **Pass**. Passing still starts the clockwise buyer offers.
- A non-turn player whose offer is active sees **Buy Opportunity**. Everyone
  else sees **Waiting for [name]**.
- These choices appear in a compact, high-contrast center panel confined to the
  protected stock and discard corridor. It uses larger text and controls without
  dimming or covering any player's melds, including
  the left and right tableau lanes in four-player games. The full table remains
  visible. The local player can still reorder their hand, use Rank/Suit, or
  inspect Score while waiting; draw, discard, staging, and meld actions remain
  locked.
- Taking the discard moves it to the turn player's hand. Passing starts the
  sequential buyer offers; when those end, the stock draw is automatic.
- Phase transitions to "meld or discard" automatically after resolution.

### Meld staging (after draw, before discard)

Two modes:

1. **Add to an existing meld** — after going down on an earlier turn, tap
   a compatible hand card for automatic placement or drag it to a specific
   glowing meld. A successful drop commits immediately unless a wild fits both
   sequence ends; then a blocking low-end/high-end picker asks for its position.
   If only one sequence end is legal, placement remains automatic.
2. **Build a new contract meld** — tap cards or drag them into the persistent
   **staging tray**. Save each valid set/run as a draft chip, then tap
   **Go Down** when the full contract is ready. If a sequence has multiple
   legal wild placements, saving opens a picker showing what each wild
   represents.

**Staging tray properties:**
- Visible only to you (hot-seat: only the current player).
- Saved draft cards leave the hand fan and appear as tappable chips; tapping
  a chip returns that meld to the hand.
- Tap a staged card to return it to the hand.
- The wild-placement picker labels each wild with the natural card it
  represents before the sequence is added to the draft.

Invalid layoff targets don't glow; dropping on one returns the card to hand
with warning feedback.

**Wild redemption** (post-go-down):
- Tap any wild card in any sequence on the table → picker highlights
  which of *your* hand cards satisfy the exact-positional-replacement.
- Tap one to swap. Redeemed wild returns to your hand and can be
  restaged this same turn; table melds have no wild-count limit.

### Discarding

- Drag a card from your hand onto the discard pile → snap.
- Or: tap-select a card + tap discard button.
- One card only. Confirm the turn ends after any confirmation modals
  (e.g., "You have unconfirmed staged cards — abandon?").
- On confirm: card lands on discard, auto-advance triggers pass-and-play
  interstitial.

### Buying (out of turn only)

- After the turn player passes, the blocking overlay moves clockwise to one
  eligible player at a time.
- The offered player sees **Buy Opportunity** and chooses **Buy [card] + 1**
  or **Pass**. Their offer
  automatically passes after 20 seconds.
- Players who have gone down and players who have used all 3 buys are skipped.
- A buyer receives the discard and current top stock card. The turn player
  then receives the next stock card.
- If nobody buys, the turn player receives the current top stock card.
- Waiting players see who is deciding. Their local hand remains available for
  reordering and Rank/Suit sorting, while pile and turn-action input stays
  blocked for the entire purchase round.

### Go Down

- Only enabled when your staged cards match your current level's
  contract exactly (right kinds, right sizes, all valid).
- Tap → melds animate from staging to your melds row.
- `laidDownThisTurn` engaged — Add-to-meld and Redeem-wild are
  disabled the rest of this turn (grayed-out buttons + tooltip).
- Auto-transition to discard phase.

### Going out

- Detected automatically: after discard, if your hand is empty AND
  you've gone down → hand ends.
- **Hand-over overlay** slides up center: title, per-player level
  bumps, per-player round score, cumulative totals. **Next hand**
  button starts the new deal.

### Game over

- First player past level 10 → full-screen celebration overlay.
- Fireworks/haptic (M4).
- Buttons: **View final scores** and **Back to menu**.

## Visual style

**Twilight family game night:**

| Element              | Treatment                                              |
|----------------------|--------------------------------------------------------|
| Table / bg           | Full-bleed twilight navy/plum with soft ambient light  |
| Cards                | Large warm-ivory faces, crisp corner indices, restrained shadow |
| Card back            | Deep plum with amber linework and a simple star mark   |
| Joker / wild 2       | Amber side band and unmistakable wild marker           |
| Meld target          | Dark translucent group; mint outline when playable     |
| Staging tray         | Indigo glass-like panel kept inline above the hand     |
| Turn ribbon          | Bright amber outline, active player's hand count, level, and contract |
| Buttons              | One contextual amber primary action; quiet secondary chips |
| Sensitive states     | Coral warning, mint confirmation, plus motion/haptics  |
| Typography           | Rounded system typography throughout                   |

## Animation & feedback

- Card draw: 250 ms ease-out from pile to hand slot.
- Newly added hand cards: lifted slightly with a pulsing amber outline and
  **NEW** badge. Both cards from an out-of-turn purchase remain highlighted
  until the buyer's official draw. That draw replaces the purchase highlights,
  and all remaining **NEW** highlighting clears when the player discards.
- Card discard: 200 ms ease-in to pile top.
- Meld commit: 350 ms with mild spring (staged cards slide into row).
- Wild redemption: cross-fade + subtle scale bump.
- Illegal action: horizontal shake 6 px, 3 cycles, 250 ms total; error toast.
- Purchase panel: stays compact over the center piles and fades between
  decision owners while table input remains blocked.
- Active turn: the current player's seat uses a bright pulsing amber halo,
  amber avatar/name treatment. The local seat always retains its own level and
  contract description, including while another player has the turn.

Haptics (M4):
- Draw: `.light`
- Discard: `.rigid`
- Go Down / Go Out: `.success`
- Illegal: `.warning`

## Accessibility notes

- All card sprites carry an `accessibilityLabel` derived from `Card.description`
  (e.g., "Seven of Hearts", "Joker", "Two of Clubs, dead").
- Meld rows are accessible groups (single label reads the whole meld).
- The staging tray is a container with hint "Drag cards here to build your
  contract."
- Big-text mode: the hand strip switches from fan to grid; card rank/suit
  text grows to 24 pt.
- VoiceOver rotor: "Piles", "My hand", "My melds", "Opponents' melds".

## Local bot tables vs online

- Local bot table: your seat stays anchored at the bottom and every bot action,
  including draw and buy decisions, runs automatically.
- Online: scene stays anchored to *you* (your seat always bottom); opponent
  hands stay hidden, and the turn banner shows whose turn or buy decision is
  active.
- The home screen exposes one primary **Create Table** action. Legacy Hot-Seat
  and Quick Pair choices are not shown.
- **Create Table** opens one roster for 2–6 seats. The local player is fixed;
  the roster starts with only You, and every added seat can switch between
  Human and Bot or be removed. Start stays disabled until at least one seat is
  added, and bot-only tables start locally without Game Center.
- Every device exposes an explicit Game Center sign-in action. If an
  unauthenticated player selects human seats, the start action launches sign-in
  and resumes that same table request afterward; hosting is not restricted to
  the original developer account.
- Mixed tables reserve their bot seats and open Apple's matchmaker only for the
  exact selected human count. A noninteractive notice over Apple's screen keeps
  the reserved bot count visible.
- Bot identities are shared with every device, but only the authoritative host
  runs their decisions. Humans cannot submit normal turn actions for bots.
- Bot draw and buy decisions resolve automatically; a human is never asked to
  accept or pass on a bot's behalf.
- When clockwise dealer rotation assigns the next deal to a bot, any human may
  tap **Deal Next Hand** after reviewing the scorecard; the host validates and
  performs that one delegated bot action.

## Open UX questions (park here)

- **Sort hand automatically?** Yes by default; user can override to
  freeform manual order via long-press.
- **Show total wilds allowed in a meld?** Only while building the initial
  contract; table extensions are unrestricted.
- **Hint mode for kids?** Not v1. Consider in M4.
- **Show a 'possible contract' hint?** Not v1 — probably a paid feature.

## Cross-references

- Rules: `docs/rules.md`
- Player-facing rules explainer: `docs/how-to-play.md`
- Project plan: `plan.md` (session folder)
