UI v0.9: short bright micro-plucks / ticks

Original deterministic synthesis. No external recording or licensing dependencies.
Seven semantic keys, existing gains/cooldowns, four-voice scheduler and silent hover are retained.
v08 remains intact. Resonant plucks supersede the rejected v08 filtered-noise palette.
No reverb, pitch sweeps, sustained hiss, limiter or clipping. Modal attacks fade in under 1ms.
Peak-scaled individually, then production gain is applied at playback; previews use that same gain.
Engineering QC only: no model listening assessment and no user acceptance claimed.

Reproduce: python tools/make_ui_crisp_v09.py
Check: python tools/make_ui_crisp_v09.py --check

ui_v09_preview.wav
New v09 only, seven actions in the order below. No spoken labels.
 0.300- 0.360s  v09  button_press
 0.910- 1.040s  v09  paper_popup
 1.590- 1.790s  v09  page_turn
 2.340- 2.640s  v09  scroll_unroll
 3.190- 3.285s  v09  paper_close
 3.835- 4.295s  v09  parchment_burn
 4.845- 4.995s  v09  choice_confirm

ui_v08_v09_ab_preview.wav
A/B preview: for EACH action, v08 first then v09. No spoken labels.
 0.300- 0.372s  v08  button_press
 0.922- 0.982s  v09  button_press
 1.532- 1.752s  v08  paper_popup
 2.302- 2.432s  v09  paper_popup
 2.982- 3.362s  v08  page_turn
 3.912- 4.112s  v09  page_turn
 4.662- 5.242s  v08  scroll_unroll
 5.792- 6.092s  v09  scroll_unroll
 6.642- 6.806s  v08  paper_close
 7.356- 7.451s  v09  paper_close
 8.001- 8.891s  v08  parchment_burn
 9.441- 9.901s  v09  parchment_burn
10.451-10.619s  v08  choice_confirm
11.169-11.319s  v09  choice_confirm
