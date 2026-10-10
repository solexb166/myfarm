"""Train a crop-disease classifier for the MY FARM app, on CPU.

Same model as the Colab notebooks (EfficientNetB0, ImageNet weights,
224 x 224 input), so the result drops into assets/models/ unchanged:

  input   float32 [1, 224, 224, 3], plain 0-255 RGB, whole photo stretched
          to 224 x 224 (what lib/services/inference_service.dart sends)
  output  float32 [1, N] softmax, in the order of <crop>_labels.txt

Photos are decoded once and kept in memory; augmentation happens in the
input pipeline, not in the model, so the exported graph stays plain.

    python ml/train_cpu.py --data DIR --out OUT --crop cassava \\
        --labels "cbb=cassava_bacterial_blight,healthy=healthy,..."

DIR holds one folder per class, either directly or inside train/,
validation/ and test/ folders (a split is made when those are missing).
--labels maps class folder names to the app's treatment keys
(lib/services/treatment_db.dart). OUT receives <crop>.tflite,
<crop>_labels.txt, <crop>_confusion_matrix.png and report.json.
"""
import argparse
import json
import os
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from PIL import Image, ImageOps

IMG = 224
SEED = 42
EXTS = ('.jpg', '.jpeg', '.png')


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--data', required=True)
    p.add_argument('--out', required=True)
    p.add_argument('--crop', required=True)
    p.add_argument('--labels', required=True,
                   help='folder=app_key pairs, comma separated')
    p.add_argument('--head-epochs', type=int, default=6)
    p.add_argument('--ft-epochs', type=int, default=10)
    p.add_argument('--unfreeze', default='block5a',
                   help='first EfficientNet layer to fine-tune')
    p.add_argument('--batch', type=int, default=32)
    p.add_argument('--old-model', help='current .tflite to compare against')
    p.add_argument('--max-train-per-class', type=int, default=0,
                   help='use at most this many training photos per class '
                        '(0 = all); keeps CPU training time reasonable')
    return p.parse_args()


def load_image(path):
    with Image.open(path) as im:
        im = ImageOps.exif_transpose(im).convert('RGB')
        # Stretch, like the app's img.copyResize(width: 224, height: 224).
        return np.asarray(im.resize((IMG, IMG), Image.BILINEAR), np.uint8)


def list_split(root, folders):
    items = []
    for folder, idx in folders.items():
        d = os.path.join(root, folder)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.lower().endswith(EXTS):
                items.append((os.path.join(d, f), idx))
    return items


def load_split(items):
    x = np.zeros((len(items), IMG, IMG, 3), np.uint8)
    y = np.array([i for _, i in items], np.int32)
    keep = np.ones(len(items), bool)

    def work(k):
        try:
            x[k] = load_image(items[k][0])
        except Exception:
            keep[k] = False

    with ThreadPoolExecutor(8) as pool:
        list(pool.map(work, range(len(items))))
    if (~keep).any():
        print(f'  skipped {(~keep).sum()} unreadable files')
    return x[keep], y[keep]


def stratified_split(items, fractions, rng):
    """Split items into len(fractions) parts, per class."""
    parts = [[] for _ in fractions]
    by_class = {}
    for it in items:
        by_class.setdefault(it[1], []).append(it)
    for group in by_class.values():
        group = list(group)
        rng.shuffle(group)
        start = 0
        for k, frac in enumerate(fractions):
            end = len(group) if k == len(fractions) - 1 else \
                start + round(frac * len(group))
            parts[k] += group[start:end]
            start = end
    return parts


def main():
    a = parse_args()
    os.makedirs(a.out, exist_ok=True)
    pairs = [kv.split('=') for kv in a.labels.split(',')]
    folders = {f.strip(): i for i, (f, _) in enumerate(pairs)}
    keys = [k.strip() for _, k in pairs]
    rng = np.random.default_rng(SEED)

    splits = {s: os.path.join(a.data, s) for s in ('train', 'validation', 'test')}
    if all(os.path.isdir(p) for p in splits.values()):
        items = {s: list_split(p, folders) for s, p in splits.items()}
    else:
        tr, va, te = stratified_split(list_split(a.data, folders),
                                      (0.7, 0.15, 0.15), rng)
        items = {'train': tr, 'validation': va, 'test': te}

    if a.max_train_per_class:
        kept = []
        for idx in range(len(keys)):
            group = [it for it in items['train'] if it[1] == idx]
            rng.shuffle(group)
            kept += group[:a.max_train_per_class]
        items['train'] = kept

    data = {}
    for s, it in items.items():
        t = time.time()
        data[s] = load_split(it)
        counts = np.bincount(data[s][1], minlength=len(keys))
        print(f'{s}: {len(it)} photos in {time.time() - t:.0f}s '
              + ', '.join(f'{k}={c}' for k, c in zip(keys, counts)))

    import tensorflow as tf
    tf.random.set_seed(SEED)
    from tensorflow.keras import layers, models

    xtr, ytr = data['train']
    counts = np.bincount(ytr, minlength=len(keys))
    class_weight = {i: len(ytr) / (len(keys) * max(c, 1))
                    for i, c in enumerate(counts)}

    aug = models.Sequential([
        layers.RandomFlip('horizontal_and_vertical'),
        layers.RandomRotation(0.15),
        layers.RandomZoom(0.15),
        layers.RandomContrast(0.15),
        layers.RandomBrightness(0.15, value_range=(0, 255)),
    ])

    def pipeline(x, y, training):
        ds = tf.data.Dataset.from_tensor_slices((x, y))
        if training:
            ds = ds.shuffle(len(x), seed=SEED, reshuffle_each_iteration=True)
        ds = ds.batch(a.batch)
        ds = ds.map(lambda i, l: (tf.cast(i, tf.float32), l),
                    num_parallel_calls=tf.data.AUTOTUNE)
        if training:
            ds = ds.map(lambda i, l: (tf.clip_by_value(aug(i, training=True),
                                                       0, 255), l),
                        num_parallel_calls=tf.data.AUTOTUNE)
        return ds.prefetch(tf.data.AUTOTUNE)

    train_ds = pipeline(xtr, ytr, True)
    val_ds = pipeline(*data['validation'], False)

    # EfficientNet in Keras rescales 0-255 input itself.
    base = tf.keras.applications.EfficientNetB0(
        include_top=False, weights='imagenet', input_shape=(IMG, IMG, 3))
    base.trainable = False
    inputs = layers.Input((IMG, IMG, 3), name='image')
    x = base(inputs, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(len(keys), activation='softmax')(x)
    model = models.Model(inputs, outputs)

    def fit(epochs, lr, patience):
        model.compile(optimizer=tf.keras.optimizers.Adam(lr),
                      loss='sparse_categorical_crossentropy',
                      metrics=['accuracy'])
        return model.fit(
            train_ds, validation_data=val_ds, epochs=epochs,
            class_weight=class_weight, verbose=2,
            callbacks=[
                tf.keras.callbacks.EarlyStopping(
                    monitor='val_accuracy', patience=patience,
                    restore_best_weights=True),
                tf.keras.callbacks.ReduceLROnPlateau(
                    monitor='val_loss', factor=0.3, patience=2, min_lr=1e-6),
            ]).history

    print('\nPhase 1: new classifier head, backbone frozen')
    h1 = fit(a.head_epochs, 1e-3, 3)

    print(f'\nPhase 2: fine-tune from {a.unfreeze} (BatchNorm stays frozen)')
    base.trainable = True
    on = False
    for layer in base.layers:
        on = on or layer.name.startswith(a.unfreeze)
        layer.trainable = on and not isinstance(layer,
                                                layers.BatchNormalization)
    h2 = fit(a.ft_epochs, 1e-4, 4)

    # ---- export ----
    conv = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite = conv.convert()
    tfl_path = os.path.join(a.out, f'{a.crop}.tflite')
    with open(tfl_path, 'wb') as f:
        f.write(tflite)
    with open(os.path.join(a.out, f'{a.crop}_labels.txt'), 'w') as f:
        f.write('\n'.join(keys))

    # ---- evaluate the exported file, as the app runs it ----
    xte, yte = data['test']
    report = {'classes': keys, 'test_photos': int(len(yte)),
              'history': {'head': h1, 'finetune': h2}}
    report['new'] = evaluate(tfl_path, xte, yte, keys, a.out,
                             f'{a.crop}_confusion_matrix.png')
    if a.old_model:
        report['old'] = evaluate(a.old_model, xte, yte, keys, a.out,
                                 f'{a.crop}_old_confusion_matrix.png')
    with open(os.path.join(a.out, 'report.json'), 'w') as f:
        json.dump(report, f, indent=1, default=float)
    print(json.dumps({k: report[k] for k in ('new', 'old') if k in report},
                     indent=1, default=float))


def evaluate(path, x, y, keys, out, png):
    import tensorflow as tf
    interp = tf.lite.Interpreter(model_path=path, num_threads=4)
    interp.allocate_tensors()
    inp = interp.get_input_details()[0]
    outp = interp.get_output_details()[0]
    probs = np.zeros((len(x), len(keys)), np.float32)
    for k in range(len(x)):
        interp.set_tensor(inp['index'], x[k:k + 1].astype(np.float32))
        interp.invoke()
        probs[k] = interp.get_tensor(outp['index'])[0]
    pred = probs.argmax(1)
    conf = probs.max(1)
    n = len(keys)
    cm = np.zeros((n, n), int)
    for t, p in zip(y, pred):
        cm[t, p] += 1
    recall = {keys[i]: cm[i, i] / max(cm[i].sum(), 1) for i in range(n)}
    sure = conf >= 0.55  # the app's minimum confidence
    result = {
        'file': os.path.basename(path),
        'accuracy': float((pred == y).mean()),
        'balanced_accuracy': float(np.mean(list(recall.values()))),
        'recall': recall,
        'shown_share': float(sure.mean()),
        'accuracy_when_shown': float((pred[sure] == y[sure]).mean())
        if sure.any() else 0.0,
        'confusion_matrix': cm.tolist(),
    }
    plot_cm(cm, keys, os.path.join(out, png),
            f"{result['file']}: {result['accuracy']:.1%} correct")
    return result


def plot_cm(cm, keys, path, title):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(7.5, 6.5))
    ax.imshow(cm, cmap='Greens')
    ax.set_xticks(range(len(keys)), keys, rotation=45, ha='right')
    ax.set_yticks(range(len(keys)), keys)
    for i in range(len(keys)):
        for j in range(len(keys)):
            ax.text(j, i, cm[i, j], ha='center', va='center',
                    color='white' if cm[i, j] > cm.max() / 2 else 'black')
    ax.set_xlabel('Predicted')
    ax.set_ylabel('Actual')
    ax.set_title(title)
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    plt.close(fig)


if __name__ == '__main__':
    main()
