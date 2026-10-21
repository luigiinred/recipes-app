# Mascots

Source art for the tomato chef and friends.

| File | What it is |
|---|---|
| `sheet-poses.webp` | Transparent sprite sheet: the tomato in many poses (waving, tossing veggies in the wok, with a tablet, laptop, spoon, books, groceries), the potato, lemon and chili, wok frames, burner flames, steam and ingredient pieces. |
| `sheet-parts.webp` | Transparent sprite sheet of the tomato in separate parts (faces, arms, wok, feet) and more ingredient pieces. |
| `mockup-onboarding.webp` | Onboarding mockup: welcome carousel, import steps and the success screen. |
| `mockup-import-flow.webp` | Import mockup in light and dark, including the loading states. |

The sprites used by the app are cut from the sheets into `apps/ios/App/Assets.xcassets/Mascot`.

## Rigged SVGs

`apps/ios/App/Mascot/Rigs` has the four characters as layered SVGs for skeleton animation, and `Props` has the wok, the veggie pieces and the ingredient decorations. The app draws them at runtime (`SVGRig.swift`), so they stay sharp at any size and the bones can be posed every frame.

Every character is a 400 by 400 canvas of nested groups. A group with `data-bone` is a bone: `data-parent` names its parent and `data-pivot` is the point it rotates, scales and shears about. A bone's pose is applied about its pivot, children follow their parent.

| Character | Bones |
|---|---|
| tomato | `root` > `leg-l`, `leg-r`, `body` > `face` (`eye-l`, `eye-r`), `hat`, `calyx`, `arm-l`, `arm-r` |
| potato | `root` > `leg-l`, `leg-r`, `body` > `face` (`eye-l`, `eye-r`), `arm-l`, `arm-r` |
| lemon | `root` > `leg-l`, `leg-r`, `body` > `face` (`eye-l`, `eye-r`), `leaf`, `arm-l`, `arm-r` |
| chili | `root` > `body` (one solid shape that bends by shearing) > `face` (`eye-l`, `eye-r`), `stem`, `arm-l`, `arm-r` |

Face parts are plain groups that are shown or hidden: `eyes-open`, `eyes-happy`, `eyes-sour`, `brows`, `mouth-smile`, `mouth-open`, `mouth-sour` (the sour ones are the lemon's).

Animations live in `MascotMotion.swift` (idle, wave, hop, sour) and `MascotScenes.swift` (stir fry, empty wok, turning pages, writing). To add one, write a function from a loop position (0 to 1) to bone poses and add a case to `MascotScene`.
