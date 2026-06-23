from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    Image, PageBreak, HRFlowable, KeepTogether
)
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
from reportlab.platypus import BaseDocTemplate, Frame, PageTemplate
from reportlab.lib.colors import HexColor
import os

# Color palette
GREEN_DARK   = HexColor("#1B4332")
GREEN_MID    = HexColor("#2D6A4F")
GREEN_LIGHT  = HexColor("#52B788")
GREEN_PALE   = HexColor("#D8F3DC")
GRAY_LIGHT   = HexColor("#F8F9FA")
GRAY_MID     = HexColor("#DEE2E6")
GRAY_DARK    = HexColor("#495057")
WHITE        = colors.white
BLACK        = colors.black

BASE_DIR = "/Users/y_la9/Desktop/plant_mobile_app"
ASSETS   = os.path.join(BASE_DIR, "report_assets")
OUT_PATH = os.path.join(BASE_DIR, "ResNet50_Plant_Disease_Report.pdf")

# ── Page geometry ──────────────────────────────────────────────────────────────
PAGE_W, PAGE_H = A4
MARGIN = 2 * cm

def header_footer(canvas, doc):
    canvas.saveState()
    # Header bar
    canvas.setFillColor(GREEN_DARK)
    canvas.rect(0, PAGE_H - 1.2*cm, PAGE_W, 1.2*cm, fill=1, stroke=0)
    canvas.setFillColor(WHITE)
    canvas.setFont("Helvetica-Bold", 8)
    canvas.drawString(MARGIN, PAGE_H - 0.8*cm,
                      "ResNet50 Plant Disease Classification – Training Report")
    # Footer
    canvas.setFillColor(GRAY_MID)
    canvas.rect(0, 0, PAGE_W, 0.8*cm, fill=1, stroke=0)
    canvas.setFillColor(GRAY_DARK)
    canvas.setFont("Helvetica", 7.5)
    canvas.drawString(MARGIN, 0.22*cm, "Confidential – For Research Use Only")
    canvas.drawRightString(PAGE_W - MARGIN, 0.22*cm, f"Page {doc.page}")
    canvas.restoreState()

# ── Styles ─────────────────────────────────────────────────────────────────────
styles = getSampleStyleSheet()

def S(name, **kw):
    return ParagraphStyle(name, **kw)

style_cover_title = S("CoverTitle",
    fontSize=28, leading=36, textColor=WHITE,
    fontName="Helvetica-Bold", alignment=TA_CENTER)

style_cover_sub = S("CoverSub",
    fontSize=13, leading=18, textColor=GREEN_PALE,
    fontName="Helvetica", alignment=TA_CENTER)

style_h1 = S("H1",
    fontSize=14, leading=20, textColor=WHITE,
    fontName="Helvetica-Bold", alignment=TA_LEFT,
    spaceBefore=14, spaceAfter=6,
    backColor=GREEN_DARK,
    leftIndent=-0.5*cm, rightIndent=-0.5*cm,
    borderPad=(4, 8, 4, 8))

style_h2 = S("H2",
    fontSize=11, leading=15, textColor=GREEN_DARK,
    fontName="Helvetica-Bold",
    spaceBefore=10, spaceAfter=4,
    borderPadding=(0, 0, 2, 0))

style_body = S("Body",
    fontSize=10, leading=15, textColor=GRAY_DARK,
    fontName="Helvetica", alignment=TA_JUSTIFY,
    spaceAfter=6)

style_bullet = S("Bullet",
    fontSize=10, leading=14, textColor=GRAY_DARK,
    fontName="Helvetica",
    leftIndent=16, bulletIndent=6,
    spaceAfter=3)

style_caption = S("Caption",
    fontSize=8.5, leading=12, textColor=GRAY_DARK,
    fontName="Helvetica-Oblique", alignment=TA_CENTER,
    spaceAfter=10)

style_note = S("Note",
    fontSize=9, leading=13, textColor=GREEN_DARK,
    fontName="Helvetica-Oblique",
    backColor=GREEN_PALE,
    leftIndent=6, rightIndent=6,
    borderPad=6, spaceAfter=8)

style_metric = S("Metric",
    fontSize=10, leading=13, textColor=GREEN_DARK,
    fontName="Helvetica-Bold", alignment=TA_CENTER)

# ── Helper builders ─────────────────────────────────────────────────────────────

def section_title(text):
    return Paragraph(f"&nbsp;&nbsp;{text}", style_h1)

def subsection_title(text):
    return Paragraph(text, style_h2)

def body(text):
    return Paragraph(text, style_body)

def bullet(text):
    return Paragraph(f"• &nbsp;{text}", style_bullet)

def caption(text):
    return Paragraph(f"<i>{text}</i>", style_caption)

def note(text):
    return Paragraph(text, style_note)

def spacer(h=0.3):
    return Spacer(1, h*cm)

def hr():
    return HRFlowable(width="100%", thickness=1, color=GRAY_MID, spaceAfter=6)

def img(filename, width=13*cm, max_height=16*cm, caption_text=None):
    path = os.path.join(ASSETS, filename)
    if not os.path.exists(path):
        return [body(f"[Image not found: {filename}]")]
    from PIL import Image as PILImage
    pil = PILImage.open(path)
    pw, ph = pil.size
    aspect = ph / pw
    h = width * aspect
    if h > max_height:
        h = max_height
        width = h / aspect
    items = [Image(path, width=width, height=h)]
    if caption_text:
        items.append(caption(caption_text))
    return items

def metric_box(data):
    """data = list of (label, value) tuples"""
    col = len(data)
    cell_w = (PAGE_W - 2*MARGIN) / col
    tdata = [[Paragraph(v, style_metric) for _, v in data],
             [Paragraph(f"<font color='#6C757D' size='8'>{l}</font>", style_caption)
              for l, _ in data]]
    t = Table([tdata[0], tdata[1]],
              colWidths=[cell_w]*col)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,0), GREEN_PALE),
        ("BACKGROUND", (0,1), (-1,1), GRAY_LIGHT),
        ("BOX",        (0,0), (-1,-1), 1, GREEN_MID),
        ("INNERGRID",  (0,0), (-1,-1), 0.5, GRAY_MID),
        ("ALIGN",      (0,0), (-1,-1), "CENTER"),
        ("VALIGN",     (0,0), (-1,-1), "MIDDLE"),
        ("TOPPADDING", (0,0), (-1,-1), 8),
        ("BOTTOMPADDING",(0,0),(-1,-1), 8),
    ]))
    return t

def styled_table(headers, rows, col_widths=None):
    all_rows = [[Paragraph(f"<b>{h}</b>", S("th", fontSize=9,
                fontName="Helvetica-Bold", textColor=WHITE,
                alignment=TA_CENTER)) for h in headers]]
    for row in rows:
        all_rows.append([Paragraph(str(c), S("td", fontSize=9,
                         fontName="Helvetica", textColor=GRAY_DARK,
                         alignment=TA_CENTER)) for c in row])
    t = Table(all_rows, colWidths=col_widths)
    t.setStyle(TableStyle([
        ("BACKGROUND",    (0,0), (-1,0),  GREEN_MID),
        ("ROWBACKGROUNDS",(0,1), (-1,-1), [WHITE, GREEN_PALE]),
        ("BOX",           (0,0), (-1,-1), 1,   GREEN_MID),
        ("INNERGRID",     (0,0), (-1,-1), 0.5, GRAY_MID),
        ("ALIGN",         (0,0), (-1,-1), "CENTER"),
        ("VALIGN",        (0,0), (-1,-1), "MIDDLE"),
        ("TOPPADDING",    (0,0), (-1,-1), 6),
        ("BOTTOMPADDING", (0,0), (-1,-1), 6),
    ]))
    return t

# ── Cover page ─────────────────────────────────────────────────────────────────

def cover_page():
    elems = []

    # Full-page green background via a wide table
    cover_table = Table(
        [[Paragraph("", S("x"))]],
        colWidths=[PAGE_W], rowHeights=[PAGE_H]
    )
    cover_table.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,-1), GREEN_DARK),
    ]))
    elems.append(cover_table)

    # Overlay content using a nested approach: build as separate story then use
    # canvas directly via a drawing flowable – simpler: just use normal flow
    # (cover will have no header/footer applied via the onPage kwarg on doc.build)
    return elems  # We'll instead build the cover with canvas in onFirstPage

# We'll use a two-template approach: first page (cover) vs inner pages
# ── Document setup ─────────────────────────────────────────────────────────────

story = []

# ── Cover ──────────────────────────────────────────────────────────────────────
# We'll draw the cover manually using the canvas callback on the first page.
# To do that cleanly with Platypus, insert a single-cell full-bleed table.

cover_inner = [
    spacer(5),
    Paragraph("🌿 ResNet50", style_cover_title),
    Paragraph("Plant Disease Classification", style_cover_title),
    spacer(0.5),
    HRFlowable(width="60%", thickness=2, color=GREEN_LIGHT, spaceAfter=12),
    Paragraph("Training &amp; Evaluation Report", style_cover_sub),
    spacer(0.4),
    Paragraph("PyTorch · Google Colab · NVIDIA L4", style_cover_sub),
    spacer(0.4),
    Paragraph("April 2026", style_cover_sub),
    spacer(3),
    Paragraph("Final Test Accuracy", S("x", fontSize=11, textColor=GREEN_LIGHT,
              fontName="Helvetica", alignment=TA_CENTER)),
    Paragraph("98.85%", S("x", fontSize=52, leading=58, textColor=WHITE,
              fontName="Helvetica-Bold", alignment=TA_CENTER)),
    Paragraph("42 Classes · 50,400 Images · 5-Fold Cross Validation",
              S("x", fontSize=10, textColor=GREEN_PALE,
                fontName="Helvetica", alignment=TA_CENTER)),
]

cover_frame_table = Table([[c] for c in cover_inner],
                          colWidths=[PAGE_W - 2*MARGIN])
cover_frame_table.setStyle(TableStyle([
    ("BACKGROUND", (0,0), (-1,-1), GREEN_DARK),
    ("ALIGN",      (0,0), (-1,-1), "CENTER"),
    ("LEFTPADDING",(0,0), (-1,-1), 0),
    ("RIGHTPADDING",(0,0),(-1,-1), 0),
    ("TOPPADDING", (0,0), (-1,-1), 0),
    ("BOTTOMPADDING",(0,0),(-1,-1),0),
]))

# Simpler: just stack paragraphs with green background via a wrapper table
cover_block = Table(
    [[Paragraph("", S("e"))],
     [Paragraph("<b>ResNet50</b>", S("c1", fontSize=32, leading=40,
                textColor=WHITE, fontName="Helvetica-Bold",
                alignment=TA_CENTER))],
     [Paragraph("Plant Disease Classification", S("c2", fontSize=20,
                textColor=GREEN_PALE, fontName="Helvetica",
                alignment=TA_CENTER, leading=26))],
     [Spacer(1, 0.4*cm)],
     [HRFlowable(width="60%", thickness=2, color=GREEN_LIGHT)],
     [Spacer(1, 0.4*cm)],
     [Paragraph("Training &amp; Evaluation Report", S("c3", fontSize=14,
                textColor=GREEN_PALE, fontName="Helvetica-Bold",
                alignment=TA_CENTER))],
     [Paragraph("PyTorch · Google Colab · NVIDIA L4 · April 2026",
                S("c4", fontSize=10, textColor=GREEN_LIGHT,
                  fontName="Helvetica", alignment=TA_CENTER))],
     [Spacer(1, 2*cm)],
     [Paragraph("98.85%", S("acc", fontSize=60, leading=72,
                textColor=WHITE, fontName="Helvetica-Bold",
                alignment=TA_CENTER))],
     [Paragraph("Final Test Accuracy", S("c5", fontSize=11,
                textColor=GREEN_LIGHT, fontName="Helvetica",
                alignment=TA_CENTER))],
     [Spacer(1, 0.6*cm)],
     [Paragraph("42 Classes · 50,400 Images · 5-Fold Cross Validation",
                S("c6", fontSize=10, textColor=GREEN_PALE,
                  fontName="Helvetica", alignment=TA_CENTER))],
     [Spacer(1, 3*cm)],
    ],
    colWidths=[PAGE_W - 2*MARGIN],
)
cover_block.setStyle(TableStyle([
    ("BACKGROUND",    (0,0), (-1,-1), GREEN_DARK),
    ("ALIGN",         (0,0), (-1,-1), "CENTER"),
    ("LEFTPADDING",   (0,0), (-1,-1), 10),
    ("RIGHTPADDING",  (0,0), (-1,-1), 10),
    ("TOPPADDING",    (0,0), (-1,-1), 4),
    ("BOTTOMPADDING", (0,0), (-1,-1), 4),
]))

story.append(cover_block)
story.append(PageBreak())

# ── Section 1: Executive Summary ───────────────────────────────────────────────
story.append(section_title("1.  Executive Summary"))
story.append(spacer(0.3))
story.append(body(
    "A <b>ResNet50</b> model initialized with pretrained ImageNet weights was trained "
    "to classify <b>42 plant disease and healthy classes</b>. The training pipeline "
    "combined the <b>PlantVillage</b> dataset with the <b>RiceLeafs</b> dataset and "
    "balanced all classes to <b>1,200 images each</b>. The model was evaluated using "
    "5-fold cross-validation and Test-Time Augmentation (TTA)."))
story.append(spacer(0.3))

# Key metrics boxes
story.append(metric_box([
    ("Mean CV Accuracy",  "98.45%"),
    ("Mean CV F1-Score",  "98.46%"),
    ("Test Accuracy",     "98.85%"),
    ("Macro F1-Score",    "98.85%"),
]))
story.append(spacer(0.4))
story.append(metric_box([
    ("Macro Precision",   "98.86%"),
    ("Macro Recall",      "98.85%"),
    ("Total Classes",     "42"),
    ("Total Images",      "50,400"),
]))
story.append(spacer(0.5))

# ── Section 2: Training Objective ─────────────────────────────────────────────
story.append(section_title("2.  Training Objective"))
story.append(spacer(0.3))
for txt in [
    "Merge multiple datasets into one unified classification task.",
    "Reduce class imbalance through per-class balancing to 1,200 images.",
    "Improve robustness to real-world mobile-captured images via strong augmentation.",
    "Reliable evaluation using Train/Test split, 5-Fold CV, Early Stopping, and TTA.",
]:
    story.append(bullet(txt))
story.append(spacer(0.4))

# ── Section 3: Datasets ────────────────────────────────────────────────────────
story.append(section_title("3.  Datasets Used"))
story.append(spacer(0.3))
story.append(styled_table(
    ["Source", "Description"],
    [["PlantVillage", "Widely used benchmark dataset for plant disease classification"],
     ["RiceLeafs_merged_224", "Additional rice leaf disease images (224×224)"]],
    col_widths=[6*cm, 11*cm]
))
story.append(spacer(0.4))
story.append(styled_table(
    ["Split",       "Samples"],
    [["Total (balanced)", "50,400"],
     ["Training set",     "40,320"],
     ["Test set",         "10,080"],
     ["Train / fold",     "~32,256"],
     ["Validation / fold","~8,064"]],
    col_widths=[8*cm, 9*cm]
))
story.append(spacer(0.5))

# ── Section 4: Preprocessing ──────────────────────────────────────────────────
story.append(section_title("4.  Preprocessing &amp; Augmentation"))
story.append(spacer(0.3))
story.append(subsection_title("4.1 Training Transforms"))
aug_items = [
    "RandomResizedCrop", "RandomHorizontalFlip", "RandomVerticalFlip",
    "RandomRotation(30°)", "ColorJitter", "GaussianBlur",
    "RandomPerspective", "RandomGrayscale", "Normalize (ImageNet stats)",
    "RandomErasing",
]
cols = 2
rows = [aug_items[i:i+cols] for i in range(0, len(aug_items), cols)]
aug_table = Table(
    [[Paragraph(f"• {c}", style_bullet) for c in row] + ([""] if len(row)<cols else [])
     for row in rows],
    colWidths=[(PAGE_W-2*MARGIN)/cols]*cols
)
aug_table.setStyle(TableStyle([
    ("ROWBACKGROUNDS", (0,0), (-1,-1), [WHITE, GRAY_LIGHT]),
    ("TOPPADDING",     (0,0), (-1,-1), 4),
    ("BOTTOMPADDING",  (0,0), (-1,-1), 4),
]))
story.append(aug_table)
story.append(spacer(0.3))
story.append(subsection_title("4.2 Evaluation / Test Transforms"))
for t in ["Resize to 224×224", "Normalize with ImageNet statistics",
          "Test-Time Augmentation (TTA) with 5 steps"]:
    story.append(bullet(t))
story.append(spacer(0.5))

# ── Section 5: Model Configuration ────────────────────────────────────────────
story.append(section_title("5.  Model &amp; Training Configuration"))
story.append(spacer(0.3))
story.append(subsection_title("5.1 Architecture"))
story.append(body(
    "ResNet50 with pretrained <b>IMAGENET1K_V2</b> weights, <b>full fine-tuning of all "
    "layers</b>, and a replaced final FC layer: <code>nn.Linear(2048, 42)</code>."))
story.append(spacer(0.3))
story.append(subsection_title("5.2 Hyperparameters"))
story.append(styled_table(
    ["Parameter", "Value"],
    [["Image size",     "224 × 224"],
     ["Batch size",     "32"],
     ["Max epochs",     "30"],
     ["Folds",          "5"],
     ["Learning rate",  "1e-4"],
     ["Weight decay",   "1e-4"],
     ["Loss function",  "CrossEntropyLoss (label_smoothing=0.05)"],
     ["Optimizer",      "AdamW"],
     ["Scheduler",      "CosineAnnealingLR"],
     ["Early stopping", "patience=5, min_delta=0.001"],
     ["TTA steps",      "5"],
     ["Seed",           "42"]],
    col_widths=[8*cm, 9*cm]
))
story.append(spacer(0.5))

# ── Section 6: Cross-Validation Results ───────────────────────────────────────
story.append(section_title("6.  Cross-Validation Results"))
story.append(spacer(0.3))
story.append(styled_table(
    ["Fold", "Val Accuracy", "Val F1", "Stop Epoch", "Note"],
    [["Fold 1", "98.34%", "98.34%", "19", "Very strong"],
     ["Fold 2", "98.83%", "98.84%", "22", "Excellent"],
     ["Fold 3", "97.46%", "97.47%", "11", "Lowest fold"],
     ["Fold 4", "98.87%", "98.88%", "29", "★ Best fold"],
     ["Fold 5", "98.77%", "98.77%", "29", "Excellent"],
     ["Mean",   "98.45% ± 0.60%", "98.46%", "—", ""]],
    col_widths=[2.5*cm, 3.5*cm, 3*cm, 3*cm, 5*cm]
))
story.append(spacer(0.5))

# Fold comparison figure
story += img("fold_comparison.png", width=13*cm,
             caption_text="Figure 1 – Validation accuracy and F1-score comparison across the 5 folds. Fold 4 achieved the best performance.")
story.append(spacer(0.4))

# Fold 4 accuracy curve
story += img("fold4_accuracy_from_notebook.png", width=14*cm,
             caption_text="Figure 2 – Training / Validation Accuracy curve for Fold 4 (best fold, 29 epochs). "
                          "Validation accuracy consistently leads training accuracy, indicating strong generalization.")
story.append(spacer(0.5))
story.append(PageBreak())

# ── Section 7: Final Test Results ─────────────────────────────────────────────
story.append(section_title("7.  Final Test Results"))
story.append(spacer(0.3))
story.append(metric_box([
    ("Test Accuracy",   "98.85%"),
    ("Macro Precision", "98.86%"),
    ("Macro Recall",    "98.85%"),
    ("Macro F1-Score",  "98.85%"),
]))
story.append(spacer(0.3))
story.append(body(
    "The final model (selected from <b>Fold 4</b>, saved as "
    "<b>resnet50_FINAL_best.pth</b>) was evaluated on the held-out test set of "
    "<b>10,080 samples</b> using Test-Time Augmentation. The macro-average metrics "
    "are nearly identical, confirming balanced per-class performance."))
story.append(spacer(0.5))

# ── Section 8: Classification Report ──────────────────────────────────────────
story.append(section_title("8.  Classification Report"))
story.append(spacer(0.3))
story.append(body(
    "The per-class classification report shows that <b>28 out of 42 classes</b> "
    "achieved perfect Precision = Recall = F1 = 1.00 on the test set. "
    "The most challenging classes were from the rice categories."))
story.append(spacer(0.3))
story += img("classification_report_snapshot.png", width=15*cm,
             caption_text="Figure 3 – Full per-class classification report on the test set (10,080 samples, 42 classes).")
story.append(spacer(0.5))

# ── Section 9: Confusion Matrix ───────────────────────────────────────────────
story.append(section_title("9.  Confusion Matrix"))
story.append(spacer(0.3))
story.append(body(
    "The confusion matrix below confirms that predictions are heavily concentrated "
    "on the main diagonal. Visible off-diagonal confusion occurs mainly among "
    "the four rice classes (Rice___Healthy, Rice___Hispa, Rice___Leaf_blast, "
    "Rice___Brown_spot), which are the most visually similar."))
story.append(spacer(0.3))
story += img("resnet50_adv_confusion_matrix_test_sklearn.png", width=15*cm,
             caption_text="Figure 4 – Confusion matrix on the test set. Nearly all predictions fall on the diagonal; "
                          "rice classes show minor inter-class confusion.")
story.append(spacer(0.5))
story.append(PageBreak())

# ── Section 10: Dataset Samples ───────────────────────────────────────────────
story.append(section_title("10.  Dataset Sample Images"))
story.append(spacer(0.3))
story.append(body(
    "Sample images from the merged and balanced dataset are shown below, "
    "illustrating the diversity of plant species and disease categories included "
    "in the training data."))
story.append(spacer(0.3))
story += img("dataset_samples_grid.png", width=14*cm,
             caption_text="Figure 5 – Representative samples from the merged PlantVillage + RiceLeafs dataset "
                          "(balanced at 1,200 images per class).")
story.append(spacer(0.5))

# ── Section 11: Hardest Classes ───────────────────────────────────────────────
story.append(section_title("11.  Hardest Classes Analysis"))
story.append(spacer(0.3))
story.append(styled_table(
    ["Class",           "Precision", "Recall", "F1-Score"],
    [["Rice___Healthy",   "0.82",    "0.87",   "0.85"],
     ["Rice___Hispa",     "0.89",    "0.84",   "0.86"],
     ["Rice___Leaf_blast","0.92",    "0.92",   "0.92"]],
    col_widths=[7*cm, 3.5*cm, 3.5*cm, 3.5*cm]
))
story.append(spacer(0.3))
story.append(body(
    "These three rice classes share very similar visual characteristics — uniform "
    "green leaf backgrounds with subtle lesion patterns — which makes it difficult "
    "for the model to distinguish between them. Collecting more diverse real-world "
    "images for these classes is the primary recommendation for improvement."))
story.append(spacer(0.3))
story += img("hardest_classes_f1.png", width=13*cm,
             caption_text="Figure 6 – F1-scores of the most challenging classes. All three are rice-related, "
                          "highlighting the visual similarity challenge within this plant category.")
story.append(spacer(0.5))
story.append(PageBreak())

# ── Section 12: Important Notes ───────────────────────────────────────────────
story.append(section_title("12.  Important Notes"))
story.append(spacer(0.3))
story.append(subsection_title("12.1  Best Fold Discrepancy in Notebook"))
story.append(note(
    "The training-curve plotting cell inside the original notebook was configured "
    "with best_fold = 3, but the actual best-performing fold according to validation "
    "results was Fold 4. All figures in this report are based on the correct Fold 4."))
story.append(spacer(0.3))
story.append(subsection_title("12.2  Gradio Interface Error"))
story.append(note(
    "The Gradio cell in the notebook raised a FileNotFoundError because it attempted "
    "to load resnet50_fold3_best.pth. For deployment, connect the interface to "
    "resnet50_fold4_best.pth or preferably resnet50_FINAL_best.pth."))
story.append(spacer(0.5))

# ── Section 13: Recommendations ───────────────────────────────────────────────
story.append(section_title("13.  Recommendations for Future Improvement"))
story.append(spacer(0.3))
for i, txt in enumerate([
    "Collect more real-world images for the confusing rice classes instead of relying solely on balancing.",
    "Perform a deeper error analysis specifically for the rice categories (e.g., GradCAM visualizations).",
    "Compare with modern architectures: EfficientNet, ConvNeXt, and Vision Transformer (ViT).",
    "Benchmark performance with and without Test-Time Augmentation (TTA) to quantify TTA's contribution.",
    "Connect the final deployment application directly to resnet50_FINAL_best.pth.",
], 1):
    story.append(bullet(f"<b>{i}.</b> {txt}"))
story.append(spacer(0.5))

# ── Section 14: Conclusion ────────────────────────────────────────────────────
story.append(section_title("14.  Conclusion"))
story.append(spacer(0.3))
story.append(body(
    "This experiment demonstrates that <b>ResNet50</b>, when properly fine-tuned "
    "and evaluated with rigorous methodology, can achieve near-perfect performance "
    "on a 42-class plant disease classification task. The combination of <b>dataset "
    "merging, class balancing, strong augmentation, 5-fold cross-validation, and "
    "Test-Time Augmentation</b> produced a final test accuracy of <b>98.85%</b> and "
    "a macro F1-score of <b>98.85%</b>."))
story.append(spacer(0.2))
story.append(body(
    "These results form a strong, practically deployable baseline for a <b>plant "
    "disease diagnosis system</b> — whether as a research prototype, mobile application "
    "backend, or cloud inference service."))
story.append(spacer(0.6))
story.append(hr())
story.append(Paragraph(
    "<i>Generated on April 21, 2026 · ResNet50 Plant Disease Classification Project</i>",
    S("footer_note", fontSize=8, textColor=GRAY_DARK, fontName="Helvetica-Oblique",
      alignment=TA_CENTER)))

# ── Build ──────────────────────────────────────────────────────────────────────
doc = SimpleDocTemplate(
    OUT_PATH,
    pagesize=A4,
    leftMargin=MARGIN, rightMargin=MARGIN,
    topMargin=1.6*cm, bottomMargin=1.2*cm,
    title="ResNet50 Plant Disease Classification – Training Report",
    author="Plant Disease Classification Project",
    subject="Deep Learning Training Report",
)

doc.build(story, onFirstPage=header_footer, onLaterPages=header_footer)
print(f"PDF saved to: {OUT_PATH}")
