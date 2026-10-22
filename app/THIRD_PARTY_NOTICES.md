# Third-party exercise content

Leanora's application code remains MIT licensed. The following content has its own license; the repository's MIT license does not replace these licenses. Runtime uses only bundled files and makes no requests to these services.

## Free Exercise DB

- Project: [yuhonas/free-exercise-db](https://github.com/yuhonas/free-exercise-db)
- Revision: `f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5`
- License: **The Unlicense** (public domain), [upstream license](https://github.com/yuhonas/free-exercise-db/blob/f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/LICENSE.md).
- Credit: yuhonas / free-exercise-db contributors. Upstream credits `wrkout/exercises.json` as its origin.
- Uses: common names, classifications, original English instructions, and exercise photographs. Three entries without images are excluded.
- Changes: photos resized to at most 640 pixels on the longest edge, JPEG recompressed at quality 82, image metadata removed. Selected Chinese names and the legacy catalog's Chinese guidance were independently prepared for Leanora. Source text and media licenses are recorded per guide.
- Full license is bundled at [FreeExerciseDB-Unlicense.txt](ios/Leanora/Resources/ExerciseMedia/Notices/FreeExerciseDB-Unlicense.txt).

## Workout Guide / Everkinetic

- Project: [bryllim/workout-guide](https://github.com/bryllim/workout-guide)
- Revision: `aac599224bb9780305239607ef98540b7e0ce389`
- Creator: **Bryl Lim**, [bryllim.com](https://bryllim.com); original pose artwork from **Everkinetic**, [everkinetic/data](https://github.com/everkinetic/data).
- Artwork license: **Creative Commons Attribution-ShareAlike 4.0 International**, [license](https://creativecommons.org/licenses/by-sa/4.0/).
- Uses: selected original PNG frames for seven legacy exercises whose exact variants are not covered by the photo mappings. No package code is imported.
- Changes: PNG files are unmodified. For dumbbell Romanian deadlift and kettlebell swing, two checked poses are selected, without motion interpolation. Source per-frame attribution, including Everkinetic-derived work, is retained in `content/exercises/sources/workout-guide.json`. These images retain CC BY-SA 4.0, are publicly available under the same license in this repository, and are not relicensed as MIT.
- Full license and credits are bundled at [WorkoutGuide-CC-BY-SA-4.0.txt](ios/Leanora/Resources/ExerciseMedia/Notices/WorkoutGuide-CC-BY-SA-4.0.txt) and [WorkoutGuide-Attribution.md](ios/Leanora/Resources/ExerciseMedia/Notices/WorkoutGuide-Attribution.md).
- Per-exercise attribution, license links and source links are also shown inside the App.

## openGym reference boundary

[DuarteSantos8/openGym](https://github.com/DuarteSantos8/openGym) was reviewed for exercise-library organization and guidance access. Its code and translations are not imported. Its Gym visual stills and animations are separately licensed for openGym and are **not included**. See [openGym NOTICE](https://github.com/DuarteSantos8/openGym/blob/main/NOTICE.md).

The older `alexpcosta/opengym` research remains a separate historical reference. No content from 训记 or 薄荷 is included.
