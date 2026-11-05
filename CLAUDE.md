# Circulation Sim — Claude Code Project Context

## Summary
Simple visual (not a real simulation) Godot 4.5 illustration of the double loop of human circulation.
A stylized RBC with a yellow outline moves station to station; fill turns red in the lung capillaries and
purplish-blue in the body capillaries. Explore mode (step / continuous) and Quiz mode (drag next station).
Target: HTML5 export, mouse + touch + keyboard.

## Standards
- Godot 4.5, GDScript, TABS only, static typing, GL Compatibility renderer.
- UI built in code; only scene is scenes/main.tscn.
- All geometry/text lives in scripts/circulation_data.gd. Path + stations were traced from the
  guide path (class cls-20) in art/source/circulatory-path.svg; background PNG is that SVG rendered
  at 1360x1442 with the guide hidden. If the art changes, re-trace and re-render.
- No numeric oxygen values shown to students.

See docs/SPEC.md for the full spec and README.md for controls.
