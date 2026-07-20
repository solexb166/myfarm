# MY FARM — Flutter app (offline)

An AI agronomist in your pocket. Photograph a sick crop and get a diagnosis,
treatment, and a season plan — all running **fully offline on the phone**.
Cross-platform (Android + iOS) via Flutter. English + Luganda, with voice for
low-literacy users.

## How diagnosis works (offline)

The app bundles a small **TensorFlow Lite** model per crop, trained on real
crop-disease images (see the `myfarm_ml` training pipeline). When a farmer
photographs a leaf:

1. They pick the crop (cassava, maize, tomato, beans).
2. The photo is classified **on the device** by that crop's `.tflite` model — no
   internet needed.
3. The predicted disease is matched to a bundled **treatment knowledge base**
   (`lib/services/treatment_db.dart`) for cause, organic + chemical treatment
   and prevention, in English or Luganda.

The crop calendar is also fully offline: it is generated from per-crop
growth-stage templates (`lib/services/calendar_service.dart`) and the planting
date. Calendar and scan history are stored on the device.

## Training the models

There is one Colab notebook per crop in `ml/`. Each uses transfer learning
(EfficientNetB0) and exports a quantised TFLite model whose class labels
**exactly match the keys in `treatment_db.dart`**, so every prediction maps
straight to the right treatment text.

| Crop | Notebook | Dataset | Classes |
|------|----------|---------|---------|
| Cassava | `cassava_training_colab.ipynb` | Makerere / NaCRRI (Kaggle), 21,367 Ugandan field photos | mosaic, brown streak, bacterial blight, green mottle, healthy |
| Maize | `maize_training_colab.ipynb` | Tanzania maize set (Mduma et al.), ~18k photos | MLN, MSV, healthy |
| Beans | `beans_training_colab.ipynb` | ibean (Makerere AI Lab) | angular leaf spot, bean rust, healthy |
| Matooke | `matooke_training_colab.ipynb` | Tanzania banana leaves & stems set, ~16k photos | black sigatoka, fusarium wilt race 1, healthy |

To run any of them: open in Google Colab, set runtime to GPU, follow the
dataset cell to get the images arranged as one folder per class, then run all
cells. Each prints a per-class accuracy report and confusion matrix for your
report, and gives you `<crop>.tflite` + `<crop>_labels.txt` to download.

> **The cassava notebook** pulls its data automatically from Kaggle (CSV-based).
> The other three datasets are folder-per-class image sets you download from
> their repositories (links in each notebook) and point the notebook at — the
> simplest route is to upload to Google Drive and mount it in Colab.

> **Treatment text must be verified.** The cause / organic / chemical /
> prevention text in `treatment_db.dart` was drafted for this project and needs
> checking against MAAIF / NaCRRI extension guidance and local agro-input
> availability before any public release — especially chemical names and doses.

## Adding the trained models

After training, copy two files per crop into `assets/models/`:

```
assets/models/cassava.tflite
assets/models/cassava_labels.txt
assets/models/maize.tflite
assets/models/maize_labels.txt
...
```

They are already registered via the `assets/models/` entry in `pubspec.yaml`.
The app reads `<crop>_labels.txt` to stay in sync with the model's class order.
Crops without a bundled model show a **"Soon"** badge in the picker and are
disabled — so the app ships fine with only cassava trained.

## Project structure

```
lib/
  main.dart
  theme/app_theme.dart            colour system + fonts
  models/models.dart              Diagnosis, CropPlan, CropTask
  services/
    inference_service.dart        on-device TFLite classification
    treatment_db.dart             offline treatment knowledge base (EN + LG)
    calendar_service.dart         offline rule-based season planner
    storage.dart                  local cache (calendar + history)
    l10n.dart                     English + Luganda strings
  screens/
    home_screen.dart
    diagnose_screen.dart          crop pick → photo → on-device result
    calendar_screen.dart          setup → season timeline
    history_screen.dart           saved past diagnoses
  widgets/common.dart
assets/models/                    put trained .tflite + labels here
```

## Run it

```bash
flutter create .          # fills in native scaffolding around lib/
flutter pub get
flutter run
```

> Note: TFLite generally does not run in the iOS simulator — test on a physical
> device or an Android emulator.

## Notes

- **Treatment text** is curated for a student project. Have an agronomist review
  `treatment_db.dart` before any real-world release.
- **Model quality** varies by crop: cassava and beans are trained on real field
  photos; maize and tomato use lab images (PlantVillage) and may be less
  accurate on real garden photos. See the training README.
- **Voice**: Luganda text is correct; spoken output falls back to the nearest
  available device voice (Swahili), as phones do not ship a Luganda TTS voice.
