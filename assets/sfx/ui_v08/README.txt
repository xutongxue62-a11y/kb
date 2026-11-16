UI v0.8 soft paper / wood cues
=============================
Original synthesized foley. No external media or recording license dependencies.
No tonal oscillators, electronic sweeps, resonant filters, clipping or per-clip peak normalization.
The source WAVs are already quiet. Playback gains below add headroom; do not normalize on import.

Cue / seconds / suggested gain / semantic use
button_press / 0.072 / -3 dB / an ordinary local button action
paper_popup / 0.220 / -2 dB / a small panel or modal opens
page_turn / 0.380 / -3 dB / changing the current full page
scroll_unroll / 0.580 / -4 dB / growth or shop parchment unfolds
paper_close / 0.164 / -2 dB / a panel folds or closes
parchment_burn / 0.890 / -5 dB / a special parchment burn/dissolve exit
choice_confirm / 0.168 / -1 dB / an accepted purchase or growth choice

Hover: silent. Use one semantic sound for a visible UI action, avoiding a redundant press + page cue.
UIAudio: preload('res://src/ui_audio.gd').new(); add_child(node); node.play('page_turn').
Four voices maximum; per-cue cooldowns; full pool drops new requests to preserve soft tails.
Headless mode creates no AudioStreamPlayer nodes and loads no audio streams.

Listening boundary: NOT listened to in this model session. Technical QC cannot establish pleasantness.
ui_v08_preview.wav plays these cues at the actual suggested gains. Timings:
  0.500 - 0.572 s : button_press
  1.222 - 1.442 s : paper_popup
  2.092 - 2.472 s : page_turn
  3.122 - 3.702 s : scroll_unroll
  4.352 - 4.516 s : paper_close
  5.166 - 6.056 s : parchment_burn
  6.706 - 6.874 s : choice_confirm
