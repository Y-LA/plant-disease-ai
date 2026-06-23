"use strict";
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  ImageRun, Header, Footer, AlignmentType, HeadingLevel, BorderStyle,
  WidthType, ShadingType, VerticalAlign, PageNumber, PageBreak,
  LevelFormat, TabStopType, TabStopPosition
} = require("docx");
const fs = require("fs");
const path = require("path");

// ── Paths ──────────────────────────────────────────────────────────────────────
const ASSETS = "/Users/y_la9/Desktop/plant_mobile_app/report_assets";
const OUT    = "/Users/y_la9/Desktop/plant_mobile_app/ResNet50_Plant_Disease_Report.docx";

// ── Colors ─────────────────────────────────────────────────────────────────────
const C = {
  greenDark : "1B4332",
  greenMid  : "2D6A4F",
  greenLight: "52B788",
  greenPale : "D8F3DC",
  grayDark  : "343A40",
  grayMid   : "ADB5BD",
  grayLight : "F8F9FA",
  white     : "FFFFFF",
  black     : "000000",
};

// ── Layout (A4, 2 cm margins) ──────────────────────────────────────────────────
// 1 inch = 1440 DXA;  1 cm ≈ 567 DXA
const MARGIN      = 1134;   // ~2 cm
const PAGE_W_DXA  = 11906;
const CONTENT_DXA = PAGE_W_DXA - 2 * MARGIN; // 9638 DXA ≈ 17 cm

// Image widths: target 580 px wide (≈ 6 in @96 dpi)
// Known pixel dims for aspect-ratio scaling
const IMG_DIMS = {
  "fold_comparison.png"                              : [2367, 1468],
  "fold4_accuracy_from_notebook.png"                 : [2365, 1768],
  "classification_report_snapshot.png"               : [3645, 3830],
  "resnet50_adv_confusion_matrix_test_sklearn.png"   : [3956, 3659],
  "dataset_samples_grid.png"                         : [1166, 1181],
  "hardest_classes_f1.png"                           : [2667, 1468],
};

function imgSize(filename, maxW = 560, maxH = 700) {
  const [pw, ph] = IMG_DIMS[filename] || [800, 600];
  const aspect = ph / pw;
  let w = maxW, h = Math.round(w * aspect);
  if (h > maxH) { h = maxH; w = Math.round(h / aspect); }
  return { width: w, height: h };
}

function imgParagraph(filename, maxW, maxH, captionText) {
  const fullPath = path.join(ASSETS, filename);
  if (!fs.existsSync(fullPath)) return [];
  const data = fs.readFileSync(fullPath);
  const { width, height } = imgSize(filename, maxW, maxH);
  const paras = [
    new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 120, after: 60 },
      children: [new ImageRun({
        type: "png",
        data,
        transformation: { width, height },
        altText: { title: filename, description: filename, name: filename }
      })]
    })
  ];
  if (captionText) {
    paras.push(new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 0, after: 200 },
      children: [new TextRun({ text: captionText, italics: true, size: 18,
                               color: "6C757D", font: "Arial" })]
    }));
  }
  return paras;
}

// ── Border helpers ─────────────────────────────────────────────────────────────
const bSingle = (color = "CCCCCC") => ({ style: BorderStyle.SINGLE, size: 1, color });
const bNone   = () => ({ style: BorderStyle.NIL, size: 0, color: "FFFFFF" });
const cellBorders = (color = "CCCCCC") => ({
  top: bSingle(color), bottom: bSingle(color),
  left: bSingle(color), right: bSingle(color)
});

// ── Text helpers ───────────────────────────────────────────────────────────────
const run  = (t, opts = {}) => new TextRun({ text: t, font: "Arial", size: 22, ...opts });
const bold = (t, opts = {}) => run(t, { bold: true, ...opts });

function para(children, opts = {}) {
  return new Paragraph({
    spacing: { after: 100, before: 60, ...opts.spacing },
    alignment: AlignmentType.LEFT,
    ...opts,
    children: Array.isArray(children) ? children : [children]
  });
}

function heading1(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 360, after: 120 },
    shading: { fill: C.greenDark, type: ShadingType.CLEAR },
    children: [new TextRun({ text: `  ${text}`, bold: true, color: C.white,
                             size: 28, font: "Arial" })]
  });
}

function heading2(text) {
  return new Paragraph({
    heading: HeadingLevel.HEADING_2,
    spacing: { before: 200, after: 80 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: C.greenLight } },
    children: [new TextRun({ text, bold: true, color: C.greenDark, size: 24, font: "Arial" })]
  });
}

function bodyPara(text) {
  return para([run(text, { size: 21, color: C.grayDark })],
              { spacing: { before: 60, after: 120 },
                alignment: AlignmentType.JUSTIFIED });
}

// ── Table builders ─────────────────────────────────────────────────────────────
function styledTable(headers, rows, colWidths) {
  const totalW = colWidths.reduce((a, b) => a + b, 0);
  const makeRow = (cells, isHeader) =>
    new TableRow({
      tableHeader: isHeader,
      children: cells.map((text, i) =>
        new TableCell({
          borders: cellBorders(C.greenMid),
          width: { size: colWidths[i], type: WidthType.DXA },
          shading: isHeader
            ? { fill: C.greenMid, type: ShadingType.CLEAR }
            : { fill: i % 2 === 0 ? C.white : C.grayLight, type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          verticalAlign: VerticalAlign.CENTER,
          children: [new Paragraph({
            alignment: AlignmentType.CENTER,
            children: [new TextRun({
              text: String(text), bold: isHeader,
              color: isHeader ? C.white : C.grayDark,
              size: 19, font: "Arial"
            })]
          })]
        })
      )
    });

  return new Table({
    width: { size: totalW, type: WidthType.DXA },
    columnWidths: colWidths,
    rows: [
      makeRow(headers, true),
      ...rows.map(r => makeRow(r, false))
    ]
  });
}

function metricBoxTable(items) {
  // items = [{label, value}]
  const cw = Math.floor(CONTENT_DXA / items.length);
  return new Table({
    width: { size: CONTENT_DXA, type: WidthType.DXA },
    columnWidths: items.map(() => cw),
    rows: [
      new TableRow({
        children: items.map(item =>
          new TableCell({
            borders: cellBorders(C.greenLight),
            width: { size: cw, type: WidthType.DXA },
            shading: { fill: C.greenPale, type: ShadingType.CLEAR },
            margins: { top: 120, bottom: 60, left: 100, right: 100 },
            verticalAlign: VerticalAlign.CENTER,
            children: [new Paragraph({
              alignment: AlignmentType.CENTER,
              children: [new TextRun({
                text: item.value, bold: true, color: C.greenDark,
                size: 32, font: "Arial"
              })]
            })]
          })
        )
      }),
      new TableRow({
        children: items.map(item =>
          new TableCell({
            borders: cellBorders(C.greenLight),
            width: { size: cw, type: WidthType.DXA },
            shading: { fill: C.grayLight, type: ShadingType.CLEAR },
            margins: { top: 40, bottom: 80, left: 100, right: 100 },
            verticalAlign: VerticalAlign.CENTER,
            children: [new Paragraph({
              alignment: AlignmentType.CENTER,
              children: [new TextRun({
                text: item.label, italics: true, color: "6C757D",
                size: 16, font: "Arial"
              })]
            })]
          })
        )
      })
    ]
  });
}

// ── Bullet helper ──────────────────────────────────────────────────────────────
const bulletPara = (text) =>
  new Paragraph({
    numbering: { reference: "bullets", level: 0 },
    spacing: { before: 40, after: 60 },
    children: [new TextRun({ text, size: 21, color: C.grayDark, font: "Arial" })]
  });

const numPara = (text) =>
  new Paragraph({
    numbering: { reference: "numbers", level: 0 },
    spacing: { before: 40, after: 60 },
    children: [new TextRun({ text, size: 21, color: C.grayDark, font: "Arial" })]
  });

// ── Note box (green background para) ──────────────────────────────────────────
function notePara(text) {
  return new Paragraph({
    spacing: { before: 80, after: 120 },
    shading: { fill: C.greenPale, type: ShadingType.CLEAR },
    border: { left: { style: BorderStyle.SINGLE, size: 12, color: C.greenLight } },
    indent: { left: 200, right: 200 },
    children: [new TextRun({ text, italics: true, size: 19, color: C.greenDark,
                             font: "Arial" })]
  });
}

// ── Spacer ─────────────────────────────────────────────────────────────────────
const spacer = (pts = 120) => new Paragraph({
  spacing: { before: 0, after: pts },
  children: [new TextRun({ text: "" })]
});

// ── Header / Footer ────────────────────────────────────────────────────────────
const docHeader = new Header({
  children: [new Paragraph({
    border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: C.greenDark } },
    spacing: { after: 80 },
    shading: { fill: C.greenDark, type: ShadingType.CLEAR },
    tabStops: [{ type: TabStopType.RIGHT, position: TabStopPosition.MAX }],
    children: [
      new TextRun({ text: "  ResNet50 Plant Disease Classification – Training Report",
                   color: C.white, size: 17, font: "Arial", bold: true }),
      new TextRun({ text: "\t", color: C.white }),
      new TextRun({ text: "April 2026  ", color: C.greenPale, size: 16, font: "Arial" }),
    ]
  })]
});

const docFooter = new Footer({
  children: [new Paragraph({
    border: { top: { style: BorderStyle.SINGLE, size: 4, color: C.grayMid } },
    spacing: { before: 80 },
    tabStops: [{ type: TabStopType.RIGHT, position: TabStopPosition.MAX }],
    children: [
      new TextRun({ text: "  Confidential – For Research Use Only",
                   size: 16, color: "6C757D", italics: true, font: "Arial" }),
      new TextRun({ text: "\tPage ", size: 16, color: "6C757D", font: "Arial" }),
      new TextRun({ children: [PageNumber.CURRENT], size: 16, color: "6C757D", font: "Arial" }),
      new TextRun({ text: "  ", size: 16, color: "6C757D", font: "Arial" }),
    ]
  })]
});

// ══════════════════════════════════════════════════════════════════════════════
// DOCUMENT BODY
// ══════════════════════════════════════════════════════════════════════════════
const children = [];

// ── Cover Page ─────────────────────────────────────────────────────────────────
children.push(spacer(1200));

children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { before: 0, after: 80 },
  shading: { fill: C.greenDark, type: ShadingType.CLEAR },
  children: [new TextRun({ text: "  ResNet50  ", bold: true, size: 56,
                           color: C.white, font: "Arial" })]
}));

children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { before: 0, after: 80 },
  shading: { fill: C.greenDark, type: ShadingType.CLEAR },
  children: [new TextRun({ text: "  Plant Disease Classification  ", bold: true,
                           size: 40, color: C.greenPale, font: "Arial" })]
}));

children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { before: 100, after: 100 },
  shading: { fill: C.greenDark, type: ShadingType.CLEAR },
  children: [new TextRun({ text: "  Training & Evaluation Report  ",
                           size: 28, color: C.white, font: "Arial", italics: true })]
}));

children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { before: 80, after: 600 },
  shading: { fill: C.greenDark, type: ShadingType.CLEAR },
  children: [new TextRun({ text: "  PyTorch  ·  Google Colab  ·  NVIDIA L4  ·  April 2026  ",
                           size: 22, color: C.greenLight, font: "Arial" })]
}));

children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { before: 0, after: 40 },
  children: [new TextRun({ text: "Final Test Accuracy", size: 22, color: C.greenMid,
                           font: "Arial" })]
}));

children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { before: 0, after: 80 },
  children: [new TextRun({ text: "98.85%", bold: true, size: 96, color: C.greenDark,
                           font: "Arial" })]
}));

children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { before: 60, after: 400 },
  children: [new TextRun({ text: "42 Classes  ·  50,400 Images  ·  5-Fold Cross Validation",
                           size: 22, color: C.grayDark, font: "Arial" })]
}));

// Cover metric mini-table
children.push(metricBoxTable([
  { label: "Mean CV Accuracy",  value: "98.45%" },
  { label: "Mean CV F1-Score",  value: "98.46%" },
  { label: "Macro Precision",   value: "98.86%" },
  { label: "Macro Recall",      value: "98.85%" },
]));

children.push(new Paragraph({ children: [new PageBreak()] }));

// ── Section 1: Executive Summary ───────────────────────────────────────────────
children.push(heading1("1.  Executive Summary"));
children.push(bodyPara(
  "A ResNet50 model initialized with pretrained ImageNet weights was trained to classify " +
  "42 plant disease and healthy classes. The training pipeline combined the PlantVillage " +
  "dataset with the RiceLeafs dataset and balanced all classes to 1,200 images each. " +
  "The model was evaluated using 5-fold cross-validation and Test-Time Augmentation (TTA)."
));
children.push(spacer(80));
children.push(metricBoxTable([
  { label: "Mean CV Accuracy",  value: "98.45%" },
  { label: "Mean CV F1-Score",  value: "98.46%" },
  { label: "Test Accuracy",     value: "98.85%" },
  { label: "Macro F1-Score",    value: "98.85%" },
]));
children.push(spacer(80));
children.push(metricBoxTable([
  { label: "Macro Precision",   value: "98.86%" },
  { label: "Macro Recall",      value: "98.85%" },
  { label: "Total Classes",     value: "42" },
  { label: "Total Images",      value: "50,400" },
]));
children.push(spacer(160));

// ── Section 2: Training Objective ─────────────────────────────────────────────
children.push(heading1("2.  Training Objective"));
for (const t of [
  "Merge multiple datasets into one unified classification task.",
  "Reduce class imbalance through per-class balancing to 1,200 images.",
  "Improve robustness to real-world mobile-captured images via strong augmentation.",
  "Reliable evaluation using Train/Test split, 5-Fold CV, Early Stopping, and TTA.",
]) children.push(bulletPara(t));
children.push(spacer(160));

// ── Section 3: Datasets ────────────────────────────────────────────────────────
children.push(heading1("3.  Datasets Used"));
children.push(spacer(80));
children.push(styledTable(
  ["Source", "Description"],
  [["PlantVillage", "Widely used benchmark dataset for plant disease classification"],
   ["RiceLeafs_merged_224", "Additional rice leaf disease images (224 × 224)"]],
  [3000, 6638]
));
children.push(spacer(120));
children.push(styledTable(
  ["Split", "Samples"],
  [["Total (balanced)",   "50,400"],
   ["Training set",       "40,320"],
   ["Test set",           "10,080"],
   ["Train / fold",       "~32,256"],
   ["Validation / fold",  "~8,064"]],
  [4819, 4819]
));
children.push(spacer(160));

// ── Section 4: Preprocessing ──────────────────────────────────────────────────
children.push(heading1("4.  Preprocessing & Augmentation"));
children.push(heading2("4.1  Training Transforms"));
for (const t of [
  "RandomResizedCrop", "RandomHorizontalFlip", "RandomVerticalFlip",
  "RandomRotation (30°)", "ColorJitter", "GaussianBlur",
  "RandomPerspective", "RandomGrayscale",
  "Normalize using ImageNet statistics", "RandomErasing",
]) children.push(bulletPara(t));
children.push(heading2("4.2  Evaluation / Test Transforms"));
for (const t of [
  "Resize to 224 × 224",
  "Normalize with ImageNet statistics",
  "Test-Time Augmentation (TTA) with 5 steps",
]) children.push(bulletPara(t));
children.push(spacer(160));

// ── Section 5: Model Configuration ────────────────────────────────────────────
children.push(heading1("5.  Model & Training Configuration"));
children.push(heading2("5.1  Architecture"));
children.push(bodyPara(
  "ResNet50 with pretrained IMAGENET1K_V2 weights, full fine-tuning of all layers, " +
  "and a replaced final FC layer: nn.Linear(2048, 42)."
));
children.push(heading2("5.2  Hyperparameters"));
children.push(spacer(60));
children.push(styledTable(
  ["Parameter", "Value"],
  [["Image size",     "224 × 224"],
   ["Batch size",     "32"],
   ["Max epochs",     "30"],
   ["Folds",          "5"],
   ["Learning rate",  "1e-4"],
   ["Weight decay",   "1e-4"],
   ["Loss function",  "CrossEntropyLoss (label_smoothing = 0.05)"],
   ["Optimizer",      "AdamW"],
   ["Scheduler",      "CosineAnnealingLR"],
   ["Early stopping", "patience = 5,  min_delta = 0.001"],
   ["TTA steps",      "5"],
   ["Seed",           "42"]],
  [4000, 5638]
));
children.push(spacer(160));

// ── Section 6: Cross-Validation Results ───────────────────────────────────────
children.push(heading1("6.  Cross-Validation Results"));
children.push(spacer(60));
children.push(styledTable(
  ["Fold", "Val Accuracy", "Val F1", "Stop Epoch", "Note"],
  [["Fold 1", "98.34%", "98.34%", "19", "Very strong"],
   ["Fold 2", "98.83%", "98.84%", "22", "Excellent"],
   ["Fold 3", "97.46%", "97.47%", "11", "Lowest fold"],
   ["Fold 4", "98.87%", "98.88%", "29", "★  Best fold"],
   ["Fold 5", "98.77%", "98.77%", "29", "Excellent"],
   ["Mean",   "98.45% ± 0.60%", "98.46%", "—", ""]],
  [1200, 2000, 1800, 1800, 2838]
));
children.push(spacer(120));

// Fold comparison figure
children.push(...imgParagraph(
  "fold_comparison.png", 570, 380,
  "Figure 1 – Validation accuracy and F1-score comparison across the 5 folds. " +
  "Fold 4 achieved the best performance."
));

// Fold 4 accuracy curve
children.push(...imgParagraph(
  "fold4_accuracy_from_notebook.png", 570, 430,
  "Figure 2 – Training / Validation Accuracy curve for Fold 4 (best fold, 29 epochs). " +
  "Validation accuracy consistently leads training accuracy, indicating strong generalization."
));
children.push(spacer(160));

// ── Section 7: Final Test Results ─────────────────────────────────────────────
children.push(heading1("7.  Final Test Results"));
children.push(spacer(80));
children.push(metricBoxTable([
  { label: "Test Accuracy",   value: "98.85%" },
  { label: "Macro Precision", value: "98.86%" },
  { label: "Macro Recall",    value: "98.85%" },
  { label: "Macro F1-Score",  value: "98.85%" },
]));
children.push(spacer(120));
children.push(bodyPara(
  "The final model (selected from Fold 4, saved as resnet50_FINAL_best.pth) was evaluated " +
  "on the held-out test set of 10,080 samples using Test-Time Augmentation. " +
  "The macro-average metrics are nearly identical, confirming balanced per-class performance."
));
children.push(spacer(160));

// ── Section 8: Classification Report ──────────────────────────────────────────
children.push(heading1("8.  Classification Report"));
children.push(bodyPara(
  "The per-class classification report shows that 28 out of 42 classes achieved " +
  "perfect Precision = Recall = F1 = 1.00 on the test set. " +
  "The most challenging classes were from the rice categories."
));
children.push(spacer(80));
children.push(...imgParagraph(
  "classification_report_snapshot.png", 540, 580,
  "Figure 3 – Full per-class classification report on the test set (10,080 samples, 42 classes)."
));
children.push(spacer(160));

// ── Section 9: Confusion Matrix ───────────────────────────────────────────────
children.push(heading1("9.  Confusion Matrix"));
children.push(bodyPara(
  "The confusion matrix confirms that predictions are heavily concentrated on the main diagonal. " +
  "Visible off-diagonal confusion occurs mainly among the four rice classes " +
  "(Rice___Healthy, Rice___Hispa, Rice___Leaf_blast, Rice___Brown_spot), " +
  "which are the most visually similar."
));
children.push(spacer(80));
children.push(...imgParagraph(
  "resnet50_adv_confusion_matrix_test_sklearn.png", 540, 540,
  "Figure 4 – Confusion matrix on the test set. Nearly all predictions fall on the diagonal; " +
  "rice classes show minor inter-class confusion."
));
children.push(spacer(160));

// ── Section 10: Dataset Samples ───────────────────────────────────────────────
children.push(heading1("10.  Dataset Sample Images"));
children.push(bodyPara(
  "Sample images from the merged and balanced dataset illustrating the diversity of " +
  "plant species and disease categories included in the training data."
));
children.push(spacer(80));
children.push(...imgParagraph(
  "dataset_samples_grid.png", 520, 520,
  "Figure 5 – Representative samples from the merged PlantVillage + RiceLeafs dataset " +
  "(balanced at 1,200 images per class)."
));
children.push(spacer(160));

// ── Section 11: Hardest Classes ───────────────────────────────────────────────
children.push(heading1("11.  Hardest Classes Analysis"));
children.push(spacer(60));
children.push(styledTable(
  ["Class", "Precision", "Recall", "F1-Score"],
  [["Rice___Healthy",    "0.82", "0.87", "0.85"],
   ["Rice___Hispa",      "0.89", "0.84", "0.86"],
   ["Rice___Leaf_blast", "0.92", "0.92", "0.92"]],
  [4000, 1879, 1879, 1880]
));
children.push(spacer(100));
children.push(bodyPara(
  "These three rice classes share very similar visual characteristics — uniform green leaf " +
  "backgrounds with subtle lesion patterns — making it difficult for the model to distinguish " +
  "between them. Collecting more diverse real-world images for these classes is the " +
  "primary recommendation for improvement."
));
children.push(spacer(80));
children.push(...imgParagraph(
  "hardest_classes_f1.png", 560, 340,
  "Figure 6 – F1-scores of the most challenging classes. All three are rice-related, " +
  "highlighting the visual similarity challenge."
));
children.push(spacer(160));

// ── Section 12: Important Notes ───────────────────────────────────────────────
children.push(heading1("12.  Important Notes"));
children.push(heading2("12.1  Best Fold Discrepancy in Notebook"));
children.push(notePara(
  "The training-curve plotting cell inside the original notebook was configured with " +
  "best_fold = 3, but the actual best-performing fold according to validation results " +
  "was Fold 4. All figures in this report are based on the correct Fold 4."
));
children.push(heading2("12.2  Gradio Interface Error"));
children.push(notePara(
  "The Gradio cell in the notebook raised a FileNotFoundError because it attempted to load " +
  "resnet50_fold3_best.pth. For deployment, connect the interface to " +
  "resnet50_fold4_best.pth or preferably resnet50_FINAL_best.pth."
));
children.push(spacer(160));

// ── Section 13: Recommendations ───────────────────────────────────────────────
children.push(heading1("13.  Recommendations for Future Improvement"));
for (const t of [
  "Collect more real-world images for the confusing rice classes instead of relying solely on balancing.",
  "Perform a deeper error analysis for rice categories (e.g., GradCAM visualizations).",
  "Compare with modern architectures: EfficientNet, ConvNeXt, and Vision Transformer (ViT).",
  "Benchmark performance with and without Test-Time Augmentation (TTA) to quantify its contribution.",
  "Connect the final deployment application directly to resnet50_FINAL_best.pth.",
]) children.push(numPara(t));
children.push(spacer(160));

// ── Section 14: Conclusion ────────────────────────────────────────────────────
children.push(heading1("14.  Conclusion"));
children.push(bodyPara(
  "This experiment demonstrates that ResNet50, when properly fine-tuned and evaluated " +
  "with rigorous methodology, can achieve near-perfect performance on a 42-class plant " +
  "disease classification task. The combination of dataset merging, class balancing, " +
  "strong augmentation, 5-fold cross-validation, and Test-Time Augmentation produced " +
  "a final test accuracy of 98.85% and a macro F1-score of 98.85%."
));
children.push(bodyPara(
  "These results form a strong, practically deployable baseline for a plant disease " +
  "diagnosis system — whether as a research prototype, mobile application backend, " +
  "or cloud inference service."
));
children.push(spacer(200));
children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  border: { top: { style: BorderStyle.SINGLE, size: 4, color: C.grayMid } },
  spacing: { before: 120, after: 80 },
  children: [new TextRun({
    text: "Generated on April 21, 2026  ·  ResNet50 Plant Disease Classification Project",
    italics: true, size: 17, color: "6C757D", font: "Arial"
  })]
}));

// ══════════════════════════════════════════════════════════════════════════════
// BUILD DOCUMENT
// ══════════════════════════════════════════════════════════════════════════════
const doc = new Document({
  numbering: {
    config: [
      {
        reference: "bullets",
        levels: [{
          level: 0, format: LevelFormat.BULLET, text: "\u2022",
          alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } } }
        }]
      },
      {
        reference: "numbers",
        levels: [{
          level: 0, format: LevelFormat.DECIMAL, text: "%1.",
          alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } } }
        }]
      },
    ]
  },
  styles: {
    default: {
      document: { run: { font: "Arial", size: 22 } }
    },
    paragraphStyles: [
      {
        id: "Heading1", name: "Heading 1",
        basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 28, bold: true, font: "Arial", color: C.white },
        paragraph: { spacing: { before: 360, after: 120 }, outlineLevel: 0 }
      },
      {
        id: "Heading2", name: "Heading 2",
        basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 24, bold: true, font: "Arial", color: C.greenDark },
        paragraph: { spacing: { before: 200, after: 80 }, outlineLevel: 1 }
      },
    ]
  },
  sections: [{
    properties: {
      page: {
        size: { width: PAGE_W_DXA, height: 16838 },
        margin: { top: MARGIN, right: MARGIN, bottom: MARGIN, left: MARGIN }
      }
    },
    headers: { default: docHeader },
    footers: { default: docFooter },
    children
  }]
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync(OUT, buf);
  console.log(`Saved: ${OUT}  (${(buf.length / 1024).toFixed(0)} KB)`);
}).catch(err => { console.error(err); process.exit(1); });
