# MY FARM models

All models are EfficientNetB0 (ImageNet weights) with a new classification
head, exported to TensorFlow Lite. Input: float32 `[1, 224, 224, 3]`, plain
0-255 RGB, the whole photo stretched to 224 x 224. Output: softmax over the
classes in `assets/models/<crop>_labels.txt`. The app hides answers below
55% confidence ("shown" below).

Scores are on test photos the model never saw in training.

## Cassava (retrained October 2026)

- **Data:** Makerere AI Lab / NaCRRI cassava leaf images, Uganda (the public
  2019 release, `storage.googleapis.com/emcassavadata/cassavaleafdata.zip`):
  5,656 training, 1,889 validation and 1,885 test photos.
- **Training:** `ml/train_cpu.py` on CPU. 6 epochs head only, then
  fine-tuning from `block5a` (BatchNorm frozen) with early stopping on
  validation accuracy. Best epoch: 3 of fine-tuning.
- **Report:** `ml/reports/cassava.json`; confusion matrix in
  `assets/models/cassava_confusion_matrix.png`.

| On the 1,885 test photos | Previous model | Current model |
|---|---|---|
| Correct | 75.2% | **82.3%** |
| Balanced (average of the classes) | 70.3% | **80.3%** |
| Shown (confident enough) | 83.8% | 87.0% |
| Correct when shown | 82.0% | **87.2%** |
| Bacterial blight found | 47.7% | **70.3%** |
| Brown streak found | **73.0%** | 70.7% |
| Green mottle found | 60.1% | **82.2%** |
| Mosaic found | 84.2% | **90.0%** |
| Healthy recognised | 86.7% | **88.6%** |

The previous model was trained in Colab on the larger Kaggle 2020 version of
this dataset, which probably contains some of these test photos, so its
score here is if anything flattering.

## Maize (new, October 2026)

- **Classes:** healthy, northern leaf blight, lethal necrosis (MLN), streak
  virus (MSV).
- **Data** (`ml/prepare_maize.py`), all photos stretched to 224 x 224:
  - NM-AIST Tanzania maize dataset, doi:10.7910/DVN/GDON8Q (CC0):
    healthy, MLN, MSV
  - Makerere University (Uganda) maize image dataset, doi:10.7910/DVN/LPGHKK
    (CC0): healthy, MSV, maize leaf blight (used as northern leaf blight)
  - PLANTHEAD maize leaves, Tanzania, EWA-BELT project,
    doi:10.5281/zenodo.17085836 (CC BY 4.0), 321 photos: half in training
    (repeated 8x), half held back as the "other project" test. Its MLN
    photos show late-stage, drying leaves, which the two main datasets lack.
- **Training:** `ml/train_cpu.py --max-train-per-class 2500 --extra ...`;
  10,000 main training photos plus the PLANTHEAD half; 4,675 validation and
  4,676 test photos (main datasets).
- **Report:** `ml/reports/maize.json`; confusion matrices in
  `assets/models/maize_confusion_matrix.png` and
  `ml/reports/maize_external_confusion_matrix.png`.

| | Main test (4,676) | Other project (162) |
|---|---|---|
| Correct | 99.1% | 98.8% |
| Healthy | 99.5% | 100% |
| Northern leaf blight | 99.2% | 100% |
| Lethal necrosis | 95.8% | 96.1% |
| Streak virus | 99.8% | 100% |

A first version trained without the PLANTHEAD photos scored 99.5% on the
main test but only 39% on late-stage lethal necrosis (it called most of it
streak virus), so it was not used.

These scores are optimistic: photos in each collection were taken in the same
fields on the same days, so test photos have near-twins in training. Expect
lower accuracy on farmers' own photos, especially early lethal necrosis,
which looks like streak virus. Collecting a few hundred photos from Ugandan
farms, labelled by an extension officer, is the best next step.

Photo credit (CC BY 4.0): PLANTHEAD Diagnostic Platform, EWA-BELT project
(EU Horizon 2020, GA 862848).

## Beans, matooke

Trained in Colab with the notebooks in this folder; see
`assets/models/<crop>_confusion_matrix.png`.

## Retraining

```bash
pip install tensorflow-cpu pillow numpy scikit-learn matplotlib
python ml/train_cpu.py --data DATA --out OUT --crop cassava \
  --labels "cbb=cassava_bacterial_blight,cbsd=cassava_brown_streak_disease,cgm=cassava_green_mottle,cmd=cassava_mosaic_disease,healthy=healthy" \
  --old-model assets/models/cassava.tflite
```

Before replacing a model, check its test scores in `OUT/report.json`, and
that it uses no newer TensorFlow Lite operators than the one it replaces.
