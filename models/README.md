# Model Weights

The trained ResNet50 weights are **not stored in this repository** because the
file is ~91 MB, which bloats the repo and is close to GitHub's 100 MB per-file
limit.

## Required file

```
models/resnet50_43_FINAL_best.pth
```

The backend (`backend/app.py`) loads the weights from this exact path.

## How to obtain the weights

Choose one of the following:

1. **GitHub Release (recommended)** — download `resnet50_43_FINAL_best.pth`
   from the latest release on the repository's *Releases* page and place it in
   this `models/` folder.
2. **Direct copy** — if you have the file locally (e.g. from training on
   Google Colab), copy it into this folder.

> To publish the weights as a release asset:
> create a release on GitHub, then drag the `.pth` file into the
> "Attach binaries" box. Release assets support files up to 2 GB.

## Model summary

| Property | Value |
|---|---|
| Architecture | ResNet50 (checkpoint dict with `model_state_dict` + `class_names`) |
| Classes | 43 (38 PlantVillage + 4 Rice + 1 "Not_plant") |
| Input | 224 × 224 px |
| Test accuracy | 98.85% |

See [`../docs/training_details.md`](../docs/training_details.md) and
[`../docs/ResNet50_Plant_Disease_Report.pdf`](../docs/ResNet50_Plant_Disease_Report.pdf)
for full details.
