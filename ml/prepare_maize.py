"""Download and shrink the two public maize datasets for ml/train_cpu.py.

Both are CC0 (public domain), on Harvard Dataverse:
  - NM-AIST Tanzania maize dataset, doi:10.7910/DVN/GDON8Q
    (healthy, maize lethal necrosis, maize streak virus)
  - Makerere University (Uganda) maize image dataset, doi:10.7910/DVN/LPGHKK
    (healthy, maize streak virus, maize leaf blight)

Each archive is downloaded, unpacked, every photo is stretched to 224 x 224
(what the app feeds the model) and saved as a small JPEG, and the archive is
deleted before the next one, so the ~17 GB of downloads never sit on disk at
once. Result: OUT/<class>/<source>_<n>.jpg

    python ml/prepare_maize.py OUT     (needs curl, and 7z for the .rar files)
"""
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageOps

API = 'https://dataverse.harvard.edu/api/access/datafile/'
# (Dataverse file id, file name, class folder, source tag)
FILES = [
    (6966997, 'HEATHLY.zip', 'healthy', 'tz'),
    (6962066, 'MLN.zip', 'mln', 'tz'),
    (6966998, 'MSV_1.zip', 'msv', 'tz'),
    (6962930, 'MSV_2.zip', 'msv', 'tz'),
    (6045938, 'Healthy_1.rar', 'healthy', 'ug'),
    (6045939, 'Healthy_2.rar', 'healthy', 'ug'),
    (6284851, 'MLB_1.rar', 'mlb', 'ug'),
    (6284853, 'MLB_2.rar', 'mlb', 'ug'),
    (6299680, 'MSV_1.rar', 'msv', 'ug'),
    (6299689, 'MSV_2.rar', 'msv', 'ug'),
]
SIZE = 224
EXTS = ('.jpg', '.jpeg', '.png')


def shrink(src, dst):
    try:
        with Image.open(src) as im:
            im = ImageOps.exif_transpose(im).convert('RGB')
            im.resize((SIZE, SIZE), Image.BILINEAR).save(dst, quality=92)
        return True
    except Exception:
        return False


def main(out):
    work = os.path.join(out, '_work')
    os.makedirs(work, exist_ok=True)
    for file_id, name, cls, src in FILES:
        done = os.path.join(out, f'.done_{src}_{name}')
        if os.path.exists(done):
            print(f'{src}/{name}: already done', flush=True)
            continue
        archive = os.path.join(work, name)
        print(f'{src}/{name}: downloading', flush=True)
        # curl, not urllib: Dataverse refuses Python's default client.
        subprocess.run(['curl', '-sS', '-f', '-L', '--retry', '5',
                        '--retry-all-errors', '-o', archive,
                        f'{API}{file_id}'], check=True)
        unpacked = os.path.join(work, 'x')
        shutil.rmtree(unpacked, ignore_errors=True)
        os.makedirs(unpacked)
        print(f'{src}/{name}: unpacking', flush=True)
        subprocess.run(['7z', 'x', '-y', f'-o{unpacked}', archive],
                       check=True, stdout=subprocess.DEVNULL)
        os.remove(archive)

        dest = os.path.join(out, cls)
        os.makedirs(dest, exist_ok=True)
        stem = os.path.splitext(name)[0].lower()
        jobs = []
        for root, _, files in os.walk(unpacked):
            for f in files:
                if f.lower().endswith(EXTS):
                    jobs.append(os.path.join(root, f))
        jobs.sort()
        with ThreadPoolExecutor(2) as pool:
            ok = list(pool.map(
                lambda kv: shrink(kv[1], os.path.join(
                    dest, f'{src}_{stem}_{kv[0]:05d}.jpg')),
                enumerate(jobs)))
        shutil.rmtree(unpacked)
        print(f'{src}/{name}: {sum(ok)} photos -> {cls} '
              f'({len(ok) - sum(ok)} unreadable)', flush=True)
        open(done, 'w').close()
    shutil.rmtree(work, ignore_errors=True)
    for cls in sorted(os.listdir(out)):
        d = os.path.join(out, cls)
        if os.path.isdir(d) and not cls.startswith('_'):
            print(f'{cls}: {len(os.listdir(d))} photos', flush=True)
    print('ALL DONE', flush=True)


if __name__ == '__main__':
    main(sys.argv[1])
