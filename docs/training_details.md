# Training Details — ResNet50 Plant Disease Classification

> PyTorch · Google Colab · NVIDIA L4 · April 2026

---

## 1. Executive Summary

| Metric | Value |
|---|---|
| Mean CV Accuracy | **98.45% ± 0.60%** |
| Mean CV F1-Score | **98.46%** |
| Test Accuracy | **98.85%** |
| Macro F1-Score | **98.85%** |
| Macro Precision | **98.86%** |
| Macro Recall | **98.85%** |
| Total Classes | 42 |
| Total Images (balanced) | 50,400 |

---

## 2. Training Objective

- Merge PlantVillage and RiceLeafs into one unified classification task.
- Reduce class imbalance through per-class balancing to 1,200 images.
- Improve robustness to real-world mobile-captured images via strong augmentation.
- Reliable evaluation using Train/Test split, 5-Fold CV, Early Stopping, and TTA.

---

## 3. Datasets

| Source | Description |
|---|---|
| PlantVillage | Widely used benchmark dataset for plant disease classification |
| RiceLeafs_merged_224 | Additional rice leaf disease images (224×224) |

| Split | Samples |
|---|---|
| Total (balanced) | 50,400 |
| Training set | 40,320 |
| Test set | 10,080 |
| Train / fold | ~32,256 |
| Validation / fold | ~8,064 |

### All 42 Classes

| class_id | class_name |
|---|---|
| 0 | Apple___Apple_scab |
| 1 | Apple___Black_rot |
| 2 | Apple___Cedar_apple_rust |
| 3 | Apple___healthy |
| 4 | Blueberry___healthy |
| 5 | Cherry_(including_sour)___Powdery_mildew |
| 6 | Cherry_(including_sour)___healthy |
| 7 | Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot |
| 8 | Corn_(maize)___Common_rust_ |
| 9 | Corn_(maize)___Northern_Leaf_Blight |
| 10 | Corn_(maize)___healthy |
| 11 | Grape___Black_rot |
| 12 | Grape___Esca_(Black_Measles) |
| 13 | Grape___Leaf_blight_(Isariopsis_Leaf_Spot) |
| 14 | Grape___healthy |
| 15 | Orange___Haunglongbing_(Citrus_greening) |
| 16 | Peach___Bacterial_spot |
| 17 | Peach___healthy |
| 18 | Pepper,_bell___Bacterial_spot |
| 19 | Pepper,_bell___healthy |
| 20 | Potato___Early_blight |
| 21 | Potato___Late_blight |
| 22 | Potato___healthy |
| 23 | Raspberry___healthy |
| 24 | Rice___Brown_spot |
| 25 | Rice___Healthy |
| 26 | Rice___Hispa |
| 27 | Rice___Leaf_blast |
| 28 | Soybean___healthy |
| 29 | Squash___Powdery_mildew |
| 30 | Strawberry___Leaf_scorch |
| 31 | Strawberry___healthy |
| 32 | Tomato___Bacterial_spot |
| 33 | Tomato___Early_blight |
| 34 | Tomato___Late_blight |
| 35 | Tomato___Leaf_Mold |
| 36 | Tomato___Septoria_leaf_spot |
| 37 | Tomato___Spider_mites Two-spotted_spider_mite |
| 38 | Tomato___Target_Spot |
| 39 | Tomato___Tomato_Yellow_Leaf_Curl_Virus |
| 40 | Tomato___Tomato_mosaic_virus |
| 41 | Tomato___healthy |

---

## 4. Preprocessing & Augmentation

### 4.1 Training Transforms

| Transform | |
|---|---|
| RandomResizedCrop(224, scale=(0.5, 1.0)) | RandomHorizontalFlip |
| RandomVerticalFlip | RandomRotation(30°) |
| ColorJitter(brightness=0.3, contrast=0.3, saturation=0.3, hue=0.1) | GaussianBlur |
| RandomPerspective(distortion_scale=0.3, p=0.4) | RandomGrayscale(p=0.05) |
| Normalize (ImageNet stats) | RandomErasing(p=0.2, scale=(0.02, 0.15)) |

### 4.2 Evaluation / Test Transforms

- Resize to 224×224
- Normalize with ImageNet statistics
- Test-Time Augmentation (TTA) with 5 steps

---

## 5. Model & Training Configuration

### Architecture

ResNet50 with pretrained IMAGENET1K_V2 weights, full fine-tuning of all layers, and a replaced final FC layer: `nn.Linear(2048, 42)`.

### Hyperparameters

| Parameter | Value |
|---|---|
| Image size | 224 × 224 |
| Batch size | 32 |
| Max epochs | 30 |
| Folds | 5 |
| Learning rate | 1e-4 |
| Weight decay | 1e-4 |
| Loss function | CrossEntropyLoss (label_smoothing=0.05) |
| Optimizer | AdamW |
| Scheduler | CosineAnnealingLR |
| Early stopping | patience=5, min_delta=0.001 |
| TTA steps | 5 |
| Seed | 42 |

---

## 6. Cross-Validation Results

| Fold | Val Accuracy | Val F1 | Stop Epoch | Note |
|---|---|---|---|---|
| Fold 1 | 98.34% | 98.34% | 19 | Very strong |
| Fold 2 | 98.83% | 98.84% | 22 | Excellent |
| Fold 3 | 97.46% | 97.47% | 11 | Lowest fold |
| Fold 4 | **98.87%** | **98.88%** | 29 | ★ Best fold |
| Fold 5 | 98.77% | 98.77% | 29 | Excellent |
| **Mean** | **98.45% ± 0.60%** | **98.46%** | — | |

Fold 4 achieved the best performance and was selected as the final model (`resnet50_FINAL_best.pth`).

Validation accuracy consistently led training accuracy across all epochs in Fold 4, indicating strong generalization with no overfitting.

---

## 7. Final Test Results

The final model (Fold 4, saved as `resnet50_FINAL_best.pth`) was evaluated on the held-out test set of **10,080 samples** using Test-Time Augmentation.

| Metric | Value |
|---|---|
| Test Accuracy | **98.85%** |
| Macro Precision | **98.86%** |
| Macro Recall | **98.85%** |
| Macro F1-Score | **98.85%** |

The macro-average metrics are nearly identical, confirming balanced per-class performance.

**28 out of 42 classes** achieved perfect Precision = Recall = F1 = 1.00 on the test set.

---

## 8. Hardest Classes

The most challenging classes were from the rice categories due to their very similar visual characteristics — uniform green leaf backgrounds with subtle lesion patterns.

| Class | Precision | Recall | F1-Score |
|---|---|---|---|
| Rice___Healthy | 0.82 | 0.87 | **0.85** |
| Rice___Hispa | 0.89 | 0.84 | **0.86** |
| Rice___Leaf_blast | 0.92 | 0.92 | **0.92** |

Collecting more diverse real-world images for these classes is the primary recommendation for improvement.

---

## 9. Important Notes

### Best Fold Discrepancy in Notebook

> The training-curve plotting cell inside the original notebook was configured with `best_fold = 3`, but the actual best-performing fold according to validation results was **Fold 4**. All figures in the report are based on the correct Fold 4.

### Gradio Interface Error

> The Gradio cell in the notebook raised a `FileNotFoundError` because it attempted to load `resnet50_fold3_best.pth`. For deployment, connect the interface to `resnet50_fold4_best.pth` or preferably `resnet50_FINAL_best.pth`.

---

## 10. Recommendations for Future Improvement

1. Collect more real-world images for the confusing rice classes instead of relying solely on balancing.
2. Perform deeper error analysis specifically for the rice categories (e.g., GradCAM visualizations).
3. Compare with modern architectures: EfficientNet, ConvNeXt, and Vision Transformer (ViT).
4. Benchmark performance with and without TTA to quantify TTA's contribution.
5. Connect the final deployment application directly to `resnet50_FINAL_best.pth`.

---

## 11. Conclusion

ResNet50, when properly fine-tuned and evaluated with rigorous methodology, achieves near-perfect performance on a 42-class plant disease classification task. The combination of dataset merging, class balancing, strong augmentation, 5-fold cross-validation, and Test-Time Augmentation produced a final test accuracy of **98.85%** and a macro F1-score of **98.85%**.

These results form a strong, practically deployable baseline for a plant disease diagnosis system — whether as a research prototype, mobile application backend, or cloud inference service.

---

*Generated on April 21, 2026 · ResNet50 Plant Disease Classification Project*
