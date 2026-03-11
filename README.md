# **NARF**

### **Quad Sequential MIDI Source for Monome Norns**


NARF is a high-density, 4-channel MIDI sequencer inspired by the Buchla 251e. NARF utilizes rational fraction durations over predictable step grids, allowing for complex polyrhythms, tuplets, and "West Coast" rhythmic shifting in the style of the 251e, the MARF, and the Orthoganol Devices ER-101. It also has built-in support for the 16n and Korg NanoKontrol2, pitch randomization per step, and keyboard pitch input per step. Global quantization is enabled from the parameters menu.

NARF is a vibe coded with Google Gemini. ZORT!

### **Installation**: `;install https://github.com/rync/NARF.git`

## Features

* **Four Independent Tracks:** A, B, C, and D, each with 99 steps.  
* **Rational Durations:** Step lengths from $1/1$ to $32/32$.  
* **Proportional Timeline:** A visual playhead that scales step widths based on their rhythmic value.  
* **Assignable MIDI CCs:** Two independent, per-step MIDI CC destinations (0–127).  
* **10 Save Slots:** Store and recall up to 10 full project banks (4 tracks each) on the fly.  
* **Stochastic Nesting:** "Loop To" logic with repeat counts and probability-based breakouts.  
* **Global Visual Feedback:** High-fidelity loop-end markers and a screen-wide "Global Flash" on resets.  
* **Tactile Integration:** Pre-mapped for **16n Faderbank** and **Korg nanoKONTROL2**.


## Controls & Navigation

### Global Modifiers

| Key Combo           | Action                                                                 |
|:--------------------|:-----------------------------------------------------------------------|
| **K1 (Hold) \+ E1** | **Adjust Tempo:** From 20 to 300 bpm.                                  |
| **K1 (Hold) \+ E2** | **Track Select:** Switch active track (A, B, C, D).                    |
| **K1 (Hold) \+ K2** | **Jump to Edit:** Snap playhead to the step you are currently viewing. |
| **K1 (Hold) \+ K3** | **Global Transport:** Start/Stop all four tracks in sync.              |

### Sequential Editing

* **E1:** Scroll through the 99-step buffer.  
* **E2:** Cycle through Parameter rows.  
  * *Note:* On the **DURATION** row, turning E2 toggles focus between the **Numerator** and **Denominator**.  
* **E3:** Adjust value of the highlighted parameter.  
* **K2:** Toggle playback for the selected track.  
* **K3 (Short):** Stochastic Randomize (Pitch, Velocity, CC, and Duration).  
* **K3 (Long):** Save data to the currently active **Save Slot**.

### Parameter Guide

| Parameter | Logic |
| :---- | :---- |
| **PITCH** | MIDI Note 0-127. (Snaps if Quantize is ON). |
| **VELOCITY** | MIDI Velocity 0-127. |
| **DURATION** | Numerator/Denominator. Based on a $1/4$ note \= 1 beat. |
| **CC1/2 VALUE** | Value sent to CC1 or 2 when the step triggers (0-127). CC destinations are set per channel under the external Parameters menu. |
| **MODULATION** | Hardwired to the modwheel. |
| **ARTICULATION** | Gate length/Articulation (10% to 100% "Tie"). |
| **LOOP TO** | Step number to jump to. |
| **REPEATS** | Number of times to loop the jump. |
| **PROBABILITY** | % chance the step triggers or a loop occurs. |

## Hardware Mappings

NARF includes default mappings for the 16n and Korg nanoKontrol2. These are limited, but avaialble for quick editing of specific parameters across 4 channels.

### 16n Faderbank

* **Faders 1–4:** Pitch (Tracks A–D)  
* **Faders 5–8:** Velocity (Tracks A–D)  
* **Faders 9–12:** Duration Numerator (Tracks A–D)  
* **Faders 13–16:** Modulation (modwheel) (Tracks A–D)

### Korg nanoKONTROL2

* **Knobs 1–8:** Toggle Pitch/Velocity for Tracks A–D.  
* **Faders 1–8:** Toggle Modulation/Articulation for Tracks A–D.

## Performance Cues

* **The Wall (|):** A vertical line indicates the Pattern End step set in the Params menu.  
* **The Triangle:** A bright marker above the playhead indicates you have reached the final step of the loop.  
* **The Flash:** The screen will pulse white whenever a track returns to its Pattern Start point.  
* **The \! Marker:** If the edit\_focus is on the final step of the loop, parameter labels change (e.g., PI\!) as a warning.

## Save Data

To switch save slots, go to **PARAMS \> NARF CONFIG \> SAVE/LOAD SLOT**. The slot is shown on the screen, and can be autosaved via hotkey.
