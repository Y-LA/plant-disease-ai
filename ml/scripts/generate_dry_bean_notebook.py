import inspect
from pathlib import Path
import textwrap

import nbformat as nbf


ROOT = Path(__file__).resolve().parents[1]
NOTEBOOK_PATH = ROOT / "notebooks" / "dry_bean_assignment.ipynb"


def md(text: str):
    return nbf.v4.new_markdown_cell(inspect.cleandoc(text))


def code(text: str):
    return nbf.v4.new_code_cell(inspect.cleandoc(text))


cells = [
    md(
        """
        # Dry Bean Dataset Classification Assignment

        This notebook solves the full Dry Bean assignment using the **UCI Dry Bean Dataset**.
        The workflow is organized so that each numbered requirement from the assignment appears in its own section, with code, plots, tables, and short interpretations.

        Dataset references:
        - [UCI dataset page](https://archive.ics.uci.edu/dataset/602/dry+bean+dataset)
        - [Direct ZIP download](https://archive.ics.uci.edu/static/public/602/dry+bean+dataset.zip)
        """
    ),
    md(
        """
        ## Notebook Roadmap

        1. Exploratory analysis with a scatterplot matrix and full correlation heatmap
        2. Data cleaning, duplicate removal, encoding, and train/test split
        3. Default Decision Tree training, visualization, and interpretation
        4. Decision Tree improvements using depth tuning, criterion changes, and cost-complexity pruning
        5. Bagging with Decision Trees and SVM
        6. Random Forest baseline and tuning
        7. Gradient Boosting tuning and learning-curve analysis
        8. XGBoost tuning with subsampling analysis
        9. Bagging vs. Boosting discussion
        10. Unified metric comparison across all model families
        11. PCA and feature-selection experiments using the best-performing model
        12. Evaluation of the reduced-complexity variants
        13. Final deployment recommendation
        """
    ),
    code(
        """
        import os
        import time
        import warnings
        import zipfile
        import urllib.request
        from collections import deque
        from pathlib import Path

        import numpy as np
        import pandas as pd
        import seaborn as sns
        import matplotlib.pyplot as plt

        from IPython.display import Markdown, display

        from sklearn.decomposition import PCA
        from sklearn.ensemble import BaggingClassifier, GradientBoostingClassifier, RandomForestClassifier
        from sklearn.feature_selection import f_classif
        from sklearn.metrics import (
            accuracy_score,
            confusion_matrix,
            precision_recall_fscore_support,
        )
        from sklearn.model_selection import train_test_split
        from sklearn.pipeline import Pipeline
        from sklearn.preprocessing import LabelEncoder, StandardScaler
        from sklearn.svm import SVC
        from sklearn.tree import DecisionTreeClassifier, _tree, plot_tree
        from xgboost import XGBClassifier

        warnings.filterwarnings("ignore")

        PROJECT_ROOT = Path.cwd().resolve()
        if not (PROJECT_ROOT / "requirements.txt").exists() and (PROJECT_ROOT.parent / "requirements.txt").exists():
            PROJECT_ROOT = PROJECT_ROOT.parent

        os.environ.setdefault("MPLCONFIGDIR", str((PROJECT_ROOT / ".mplconfig").resolve()))
        Path(os.environ["MPLCONFIGDIR"]).mkdir(parents=True, exist_ok=True)

        sns.set_theme(style="whitegrid", context="notebook")
        plt.rcParams["figure.figsize"] = (10, 6)
        plt.rcParams["axes.titlesize"] = 14
        plt.rcParams["axes.labelsize"] = 11

        DATASET_URL = "https://archive.ics.uci.edu/static/public/602/dry+bean+dataset.zip"
        DATASET_PAGE = "https://archive.ics.uci.edu/dataset/602/dry+bean+dataset"
        DATA_DIR = PROJECT_ROOT / "data"
        ZIP_PATH = DATA_DIR / "dry_bean_dataset.zip"
        EXTRACT_DIR = DATA_DIR / "DryBeanDataset"
        XLSX_PATH = EXTRACT_DIR / "Dry_Bean_Dataset.xlsx"
        RANDOM_STATE = 42

        family_results = {}
        model_specs = {}


        def ensure_dry_bean_dataset() -> Path:
            DATA_DIR.mkdir(parents=True, exist_ok=True)

            if not ZIP_PATH.exists():
                print(f"Downloading dataset from {DATASET_URL} ...")
                urllib.request.urlretrieve(DATASET_URL, ZIP_PATH)

            if not XLSX_PATH.exists():
                print("Extracting ZIP archive ...")
                with zipfile.ZipFile(ZIP_PATH, "r") as zip_ref:
                    zip_ref.extractall(DATA_DIR)

            return XLSX_PATH


        def weighted_scores(y_true, y_pred) -> dict:
            precision, recall, f1, _ = precision_recall_fscore_support(
                y_true, y_pred, average="weighted", zero_division=0
            )
            return {
                "precision": precision,
                "recall": recall,
                "f1": f1,
                "accuracy": accuracy_score(y_true, y_pred),
            }


        def plot_confusion(y_true, y_pred, class_names, title, ax=None):
            cm = confusion_matrix(y_true, y_pred)
            if ax is None:
                _, ax = plt.subplots(figsize=(8, 6))
            sns.heatmap(
                cm,
                annot=True,
                fmt="d",
                cmap="Blues",
                xticklabels=class_names,
                yticklabels=class_names,
                ax=ax,
            )
            ax.set_title(title)
            ax.set_xlabel("Predicted label")
            ax.set_ylabel("True label")
            return cm


        def evaluate_estimator(name, estimator, X_train, X_test, y_train, y_test, label_encoder):
            start = time.perf_counter()
            estimator.fit(X_train, y_train)
            fit_time = time.perf_counter() - start

            train_pred = estimator.predict(X_train)
            test_pred = estimator.predict(X_test)
            scores = weighted_scores(y_test, test_pred)

            result = {
                "name": name,
                "estimator": estimator,
                "train_accuracy": accuracy_score(y_train, train_pred),
                "test_accuracy": scores["accuracy"],
                "precision": scores["precision"],
                "recall": scores["recall"],
                "f1": scores["f1"],
                "fit_time_seconds": fit_time,
                "y_pred": test_pred,
                "confusion_matrix": confusion_matrix(y_test, test_pred),
                "class_names": label_encoder.classes_,
            }
            return result


        def top_split_summary(tree_model, X_reference, y_reference, label_encoder, top_n=3):
            tree = tree_model.tree_
            feature_names = list(X_reference.columns)
            class_names = label_encoder.classes_

            rows = []
            queue = deque([(0, np.ones(len(X_reference), dtype=bool), 0)])

            while queue and len(rows) < top_n:
                node_id, mask, depth = queue.popleft()
                feature_idx = tree.feature[node_id]

                if feature_idx == _tree.TREE_UNDEFINED:
                    continue

                feature_name = feature_names[feature_idx]
                threshold = tree.threshold[node_id]
                values = X_reference[feature_name].to_numpy()
                left_mask = mask & (values <= threshold)
                right_mask = mask & (values > threshold)

                def dominant_classes(local_mask):
                    subset = pd.Series(class_names[y_reference[local_mask]])
                    counts = subset.value_counts().head(3)
                    return ", ".join([f"{cls} ({cnt})" for cls, cnt in counts.items()])

                rows.append(
                    {
                        "Node ID": node_id,
                        "Depth": depth,
                        "Feature": feature_name,
                        "Threshold": round(float(threshold), 6),
                        "Dominant classes on <= side": dominant_classes(left_mask),
                        "Dominant classes on > side": dominant_classes(right_mask),
                    }
                )

                queue.append((tree.children_left[node_id], left_mask, depth + 1))
                queue.append((tree.children_right[node_id], right_mask, depth + 1))

            return pd.DataFrame(rows)


        def make_model_specs(best_dt_alpha, best_rf_n, best_rf_max_features, best_gb_n, best_gb_lr, best_xgb_subsample):
            return {
                "Decision Tree": {
                    "factory": lambda: DecisionTreeClassifier(
                        random_state=RANDOM_STATE,
                        ccp_alpha=best_dt_alpha,
                    ),
                    "needs_scaling": False,
                },
                "Bagged SVM": {
                    "factory": lambda: BaggingClassifier(
                        estimator=SVC(kernel="rbf", C=1.0, gamma="scale"),
                        n_estimators=10,
                        max_samples=0.5,
                        bootstrap=True,
                        random_state=RANDOM_STATE,
                        n_jobs=1,
                    ),
                    "needs_scaling": True,
                },
                "Bagged DT": {
                    "factory": lambda: BaggingClassifier(
                        estimator=DecisionTreeClassifier(random_state=RANDOM_STATE),
                        n_estimators=50,
                        bootstrap=True,
                        random_state=RANDOM_STATE,
                        n_jobs=1,
                    ),
                    "needs_scaling": False,
                },
                "Random Forest": {
                    "factory": lambda: RandomForestClassifier(
                        n_estimators=best_rf_n,
                        max_features=best_rf_max_features,
                        random_state=RANDOM_STATE,
                        n_jobs=1,
                    ),
                    "needs_scaling": False,
                },
                "Gradient Boosting": {
                    "factory": lambda: GradientBoostingClassifier(
                        n_estimators=best_gb_n,
                        learning_rate=best_gb_lr,
                        random_state=RANDOM_STATE,
                    ),
                    "needs_scaling": False,
                },
                "XGBoost": {
                    "factory": lambda: XGBClassifier(
                        n_estimators=best_gb_n,
                        learning_rate=best_gb_lr,
                        subsample=best_xgb_subsample,
                        objective="multi:softprob",
                        num_class=7,
                        eval_metric="mlogloss",
                        random_state=RANDOM_STATE,
                        n_jobs=1,
                    ),
                    "needs_scaling": False,
                },
            }


        def build_estimator(model_name):
            spec = model_specs[model_name]
            estimator = spec["factory"]()
            if spec["needs_scaling"]:
                return Pipeline([("scaler", StandardScaler()), ("model", estimator)])
            return estimator


        def build_pca_estimator(model_name, n_components):
            spec = model_specs[model_name]
            return Pipeline(
                [
                    ("scaler", StandardScaler()),
                    ("pca", PCA(n_components=n_components)),
                    ("model", spec["factory"]()),
                ]
            )
        """
    ),
    md(
        """
        ## Dataset Loading

        The ZIP file contains a single Excel workbook. The following cell downloads it if needed, extracts it, and loads the worksheet using `pd.read_excel`, exactly as requested.
        """
    ),
    code(
        """
        excel_path = ensure_dry_bean_dataset()

        raw_df = pd.read_excel(excel_path).rename(
            columns={
                "AspectRation": "AspectRatio",
                "roundness": "Roundness",
            }
        )

        display(Markdown(f"**Loaded file:** `{excel_path}`"))
        print(f"Raw shape: {raw_df.shape}")
        display(raw_df.head())

        raw_class_counts = raw_df["Class"].value_counts().rename_axis("Class").reset_index(name="Count")
        display(raw_class_counts)
        """
    ),
    md(
        """
        ## 1. Exploratory Visualization

        Requirement:
        - Generate a scatterplot matrix for a representative subset of 5 features
        - Generate a heatmap of the full feature correlation matrix
        - Summarize the most separable features and the most redundant ones
        """
    ),
    code(
        """
        eda_df = raw_df.drop_duplicates().copy()
        eda_X = eda_df.drop(columns=["Class"])
        eda_y = LabelEncoder().fit_transform(eda_df["Class"])

        anova_scores = pd.Series(f_classif(eda_X, eda_y)[0], index=eda_X.columns).sort_values(ascending=False)
        selected_features = anova_scores.head(5).index.tolist()

        pairplot_sample = eda_df.groupby("Class", group_keys=False).sample(n=100, random_state=RANDOM_STATE)
        sns.pairplot(
            pairplot_sample[selected_features + ["Class"]],
            hue="Class",
            corner=True,
            diag_kind="hist",
            plot_kws={"alpha": 0.65, "s": 25},
        )
        plt.suptitle("Scatterplot Matrix for Five High-Separability Features", y=1.02)
        plt.show()

        corr_matrix = eda_X.corr()
        plt.figure(figsize=(12, 10))
        sns.heatmap(corr_matrix, cmap="coolwarm", center=0, square=True)
        plt.title("Full Feature Correlation Heatmap")
        plt.show()

        high_corr = corr_matrix.abs().where(np.triu(np.ones(corr_matrix.shape), k=1).astype(bool)).stack()
        redundant_pairs = high_corr.sort_values(ascending=False).head(8).reset_index()
        redundant_pairs.columns = ["Feature A", "Feature B", "Absolute Correlation"]

        display(Markdown("**ANOVA F-score ranking (top 8 features):**"))
        display(anova_scores.head(8).rename("ANOVA F-score").to_frame().round(3))

        display(Markdown("**Most redundant feature pairs from the correlation matrix:**"))
        display(redundant_pairs.round(4))

        separable_text = ", ".join(selected_features[:3])
        redundant_text = "; ".join(
            [
                f"{row['Feature A']} vs {row['Feature B']} (|r|={row['Absolute Correlation']:.3f})"
                for _, row in redundant_pairs.head(4).iterrows()
            ]
        )

        display(
            Markdown(
                "\\n".join(
                    [
                        "**Step 1 summary**",
                        f"- The five plotted features were chosen using ANOVA F-scores, and the strongest class-separation signals came from **{separable_text}**.",
                        f"- The correlation heatmap shows strong redundancy among several geometric features, especially **{redundant_text}**.",
                        "- This suggests that bean size-related measurements carry a lot of the discriminative signal, while some shape descriptors overlap heavily and may be partially redundant.",
                    ]
                )
            )
        )
        """
    ),
    md(
        """
        ## 2. Data Cleaning and Preparation

        Requirement:
        - Verify missing values
        - Verify features are numerical
        - Encode the categorical `Class` target
        - Check and remove duplicates
        - Report how many samples remain
        - Split the data using 80% training / 20% testing with `random_state=42` and `stratify=y`
        """
    ),
    code(
        """
        missing_values_total = raw_df.isna().sum().sum()
        duplicate_rows = raw_df.duplicated().sum()

        clean_df = raw_df.drop_duplicates().reset_index(drop=True).copy()
        feature_columns = [col for col in clean_df.columns if col != "Class"]
        all_features_numeric = all(pd.api.types.is_numeric_dtype(clean_df[col]) for col in feature_columns)

        label_encoder = LabelEncoder()
        clean_df["ClassEncoded"] = label_encoder.fit_transform(clean_df["Class"])

        X = clean_df[feature_columns]
        y = clean_df["ClassEncoded"]

        X_train, X_test, y_train, y_test = train_test_split(
            X,
            y,
            test_size=0.2,
            random_state=RANDOM_STATE,
            stratify=y,
        )

        encoding_map_df = pd.DataFrame(
            {
                "Class": label_encoder.classes_,
                "Encoded Value": np.arange(len(label_encoder.classes_)),
            }
        )

        print(f"Total missing values: {missing_values_total}")
        print(f"All feature columns numerical: {all_features_numeric}")
        print(f"Duplicate rows removed: {duplicate_rows}")
        print(f"Samples remaining after cleaning: {len(clean_df)}")
        print(f"Training shape: {X_train.shape}, Testing shape: {X_test.shape}")

        display(Markdown("**Class encoding map:**"))
        display(encoding_map_df)
        """
    ),
    md(
        """
        ## 3. Default Decision Tree

        Requirement:
        - Fit a default Decision Tree classifier
        - Visualize the tree limited to depth 4
        - Interpret the top 3 splitting nodes
        - Report train/test accuracy and the confusion matrix
        - Identify the most frequently misclassified bean varieties
        """
    ),
    code(
        """
        default_dt = DecisionTreeClassifier(random_state=RANDOM_STATE)
        default_dt_result = evaluate_estimator(
            "Decision Tree (default)",
            default_dt,
            X_train,
            X_test,
            y_train,
            y_test,
            label_encoder,
        )

        print(f"Training accuracy: {default_dt_result['train_accuracy']:.4f}")
        print(f"Test accuracy: {default_dt_result['test_accuracy']:.4f}")

        plt.figure(figsize=(28, 12))
        plot_tree(
            default_dt_result["estimator"],
            feature_names=X_train.columns,
            class_names=label_encoder.classes_,
            filled=True,
            rounded=True,
            max_depth=4,
            fontsize=8,
        )
        plt.title("Decision Tree Visualization (limited to depth 4)")
        plt.show()

        split_summary_df = top_split_summary(
            default_dt_result["estimator"],
            X_train,
            y_train.to_numpy(),
            label_encoder,
            top_n=3,
        )
        display(Markdown("**Top 3 splitting nodes:**"))
        display(split_summary_df)

        plt.figure(figsize=(8, 6))
        plot_confusion(
            y_test,
            default_dt_result["y_pred"],
            label_encoder.classes_,
            "Decision Tree (default) Confusion Matrix",
        )
        plt.tight_layout()
        plt.show()

        cm = default_dt_result["confusion_matrix"].copy()
        off_diagonal = cm.copy()
        np.fill_diagonal(off_diagonal, 0)

        class_error_counts = pd.DataFrame(
            {
                "Class": label_encoder.classes_,
                "Misclassified Samples": off_diagonal.sum(axis=1),
                "Support": cm.sum(axis=1),
            }
        ).sort_values("Misclassified Samples", ascending=False)

        confusion_pairs = []
        for i, actual_class in enumerate(label_encoder.classes_):
            for j, predicted_class in enumerate(label_encoder.classes_):
                if i != j and off_diagonal[i, j] > 0:
                    confusion_pairs.append(
                        {
                            "Actual class": actual_class,
                            "Predicted as": predicted_class,
                            "Count": int(off_diagonal[i, j]),
                        }
                    )
        confusion_pairs_df = pd.DataFrame(confusion_pairs).sort_values("Count", ascending=False).head(10)

        display(Markdown("**Most misclassified actual classes:**"))
        display(class_error_counts.reset_index(drop=True))

        display(Markdown("**Largest confusion pairs:**"))
        display(confusion_pairs_df.reset_index(drop=True))

        top_confusions = ", ".join(
            [
                f"{row['Actual class']} -> {row['Predicted as']} ({row['Count']})"
                for _, row in confusion_pairs_df.head(3).iterrows()
            ]
        )
        display(
            Markdown(
                "\\n".join(
                    [
                        "**Decision Tree interpretation**",
                        f"- The strongest early splits rely on **{split_summary_df.iloc[0]['Feature']}**, **{split_summary_df.iloc[1]['Feature']}**, and **{split_summary_df.iloc[2]['Feature']}**.",
                        f"- The heaviest misclassification patterns are **{top_confusions}**.",
                        "- The default tree perfectly fits the training set, which is a classic sign of overfitting for an unpruned Decision Tree.",
                    ]
                )
            )
        )
        """
    ),
    md(
        """
        ## 4. Improving the Decision Tree

        Requirement:
        - Compare different splitting criteria (`gini` vs `entropy`)
        - Try at least 4 different `max_depth` values
        - Tune cost-complexity pruning with `ccp_alpha`
        - Plot test accuracy vs alpha
        - Compare all variants using train accuracy, test accuracy, and tree depth
        - Comment on whether pruning improves generalization
        """
    ),
    code(
        """
        depth_values = [3, 5, 8, 12, None]
        criterion_depth_rows = []

        for criterion in ["gini", "entropy"]:
            for depth in depth_values:
                estimator = DecisionTreeClassifier(
                    criterion=criterion,
                    max_depth=depth,
                    random_state=RANDOM_STATE,
                )
                result = evaluate_estimator(
                    f"DT ({criterion}, depth={depth})",
                    estimator,
                    X_train,
                    X_test,
                    y_train,
                    y_test,
                    label_encoder,
                )
                criterion_depth_rows.append(
                    {
                        "Variant Group": "Criterion + Depth",
                        "Variant": f"criterion={criterion}, max_depth={depth}",
                        "Train Accuracy": result["train_accuracy"],
                        "Test Accuracy": result["test_accuracy"],
                        "Tree Depth": result["estimator"].get_depth(),
                        "ccp_alpha": 0.0,
                    }
                )

        criterion_depth_df = pd.DataFrame(criterion_depth_rows)

        pruning_path = DecisionTreeClassifier(random_state=RANDOM_STATE).cost_complexity_pruning_path(X_train, y_train)
        alpha_candidates = pruning_path.ccp_alphas[:-1]
        alpha_grid = np.unique(np.quantile(alpha_candidates, np.linspace(0, 1, 25)))

        pruning_rows = []
        for alpha in alpha_grid:
            estimator = DecisionTreeClassifier(random_state=RANDOM_STATE, ccp_alpha=float(alpha))
            result = evaluate_estimator(
                f"DT (ccp_alpha={alpha:.6f})",
                estimator,
                X_train,
                X_test,
                y_train,
                y_test,
                label_encoder,
            )
            pruning_rows.append(
                {
                    "Variant Group": "Cost-Complexity Pruning",
                    "Variant": f"ccp_alpha={alpha:.6f}",
                    "Train Accuracy": result["train_accuracy"],
                    "Test Accuracy": result["test_accuracy"],
                    "Tree Depth": result["estimator"].get_depth(),
                    "ccp_alpha": float(alpha),
                }
            )

        pruning_df = pd.DataFrame(pruning_rows)
        best_alpha_row = pruning_df.sort_values("Test Accuracy", ascending=False).iloc[0]
        best_dt_alpha = float(best_alpha_row["ccp_alpha"])

        plt.figure(figsize=(10, 6))
        plt.plot(pruning_df["ccp_alpha"], pruning_df["Test Accuracy"], marker="o", label="Test accuracy")
        plt.axvline(best_dt_alpha, color="red", linestyle="--", label=f"Best alpha = {best_dt_alpha:.6f}")
        plt.xscale("log")
        plt.xlabel("ccp_alpha (log scale)")
        plt.ylabel("Test accuracy")
        plt.title("Decision Tree Pruning: Test Accuracy vs ccp_alpha")
        plt.legend()
        plt.show()

        dt_variants_df = pd.concat([criterion_depth_df, pruning_df], ignore_index=True)
        display(dt_variants_df.sort_values("Test Accuracy", ascending=False).round(4))

        best_dt_estimator = DecisionTreeClassifier(random_state=RANDOM_STATE, ccp_alpha=best_dt_alpha)
        best_dt_result = evaluate_estimator(
            "Decision Tree (best tuned)",
            best_dt_estimator,
            X_train,
            X_test,
            y_train,
            y_test,
            label_encoder,
        )
        family_results["Decision Tree"] = best_dt_result

        generalization_gap_default = default_dt_result["train_accuracy"] - default_dt_result["test_accuracy"]
        generalization_gap_pruned = best_dt_result["train_accuracy"] - best_dt_result["test_accuracy"]

        best_depth_row = criterion_depth_df.sort_values("Test Accuracy", ascending=False).iloc[0]

        display(
            Markdown(
                "\\n".join(
                    [
                        "**Decision Tree tuning summary**",
                        f"- Best depth/criterion configuration: **{best_depth_row['Variant']}** with test accuracy **{best_depth_row['Test Accuracy']:.4f}**.",
                        f"- Best pruning value: **ccp_alpha = {best_dt_alpha:.6f}** with test accuracy **{best_dt_result['test_accuracy']:.4f}**.",
                        f"- Default tree generalization gap: **{generalization_gap_default:.4f}**.",
                        f"- Pruned tree generalization gap: **{generalization_gap_pruned:.4f}**.",
                        "- Pruning improves generalization because it removes low-value branches that fit noise in the training set, reducing overfitting while keeping the strongest splits.",
                    ]
                )
            )
        )
        """
    ),
    md(
        """
        ## 5. Bagging with SVM and Decision Tree

        Requirement:
        - Train a Bagging classifier using SVM as the base estimator
        - Train another Bagging classifier using Decision Tree as the base estimator
        - Report accuracy and confusion matrix for each
        - Compare which base estimator benefits more from bagging
        """
    ),
    code(
        """
        base_svm = Pipeline([("scaler", StandardScaler()), ("model", SVC(kernel="rbf", C=1.0, gamma="scale"))])
        bagged_svm = Pipeline(
            [
                ("scaler", StandardScaler()),
                (
                    "model",
                    BaggingClassifier(
                        estimator=SVC(kernel="rbf", C=1.0, gamma="scale"),
                        n_estimators=10,
                        max_samples=0.5,
                        bootstrap=True,
                        random_state=RANDOM_STATE,
                        n_jobs=1,
                    ),
                ),
            ]
        )

        base_dt_for_bagging = DecisionTreeClassifier(random_state=RANDOM_STATE)
        bagged_dt = BaggingClassifier(
            estimator=DecisionTreeClassifier(random_state=RANDOM_STATE),
            n_estimators=50,
            bootstrap=True,
            random_state=RANDOM_STATE,
            n_jobs=1,
        )

        base_svm_result = evaluate_estimator("Base SVM", base_svm, X_train, X_test, y_train, y_test, label_encoder)
        bagged_svm_result = evaluate_estimator("Bagged SVM", bagged_svm, X_train, X_test, y_train, y_test, label_encoder)
        base_dt_for_bagging_result = evaluate_estimator("Base DT", base_dt_for_bagging, X_train, X_test, y_train, y_test, label_encoder)
        bagged_dt_result = evaluate_estimator("Bagged DT", bagged_dt, X_train, X_test, y_train, y_test, label_encoder)

        family_results["Bagged SVM"] = bagged_svm_result
        family_results["Bagged DT"] = bagged_dt_result

        bagging_comparison_df = pd.DataFrame(
            [
                {
                    "Model": "Base SVM",
                    "Test Accuracy": base_svm_result["test_accuracy"],
                },
                {
                    "Model": "Bagged SVM",
                    "Test Accuracy": bagged_svm_result["test_accuracy"],
                },
                {
                    "Model": "Base Decision Tree",
                    "Test Accuracy": base_dt_for_bagging_result["test_accuracy"],
                },
                {
                    "Model": "Bagged Decision Tree",
                    "Test Accuracy": bagged_dt_result["test_accuracy"],
                },
            ]
        )
        display(bagging_comparison_df.round(4))

        fig, axes = plt.subplots(1, 2, figsize=(16, 6))
        plot_confusion(
            y_test,
            bagged_svm_result["y_pred"],
            label_encoder.classes_,
            "Bagged SVM Confusion Matrix",
            ax=axes[0],
        )
        plot_confusion(
            y_test,
            bagged_dt_result["y_pred"],
            label_encoder.classes_,
            "Bagged Decision Tree Confusion Matrix",
            ax=axes[1],
        )
        plt.tight_layout()
        plt.show()

        svm_gain = bagged_svm_result["test_accuracy"] - base_svm_result["test_accuracy"]
        dt_gain = bagged_dt_result["test_accuracy"] - base_dt_for_bagging_result["test_accuracy"]
        more_improved = "Decision Tree" if dt_gain > svm_gain else "SVM"

        display(
            Markdown(
                "\\n".join(
                    [
                        "**Bagging comparison**",
                        f"- Bagging changed SVM accuracy by **{svm_gain:+.4f}**.",
                        f"- Bagging changed Decision Tree accuracy by **{dt_gain:+.4f}**.",
                        f"- The model that benefited more from bagging was **{more_improved}**.",
                        "- Bagging helps high-variance learners such as Decision Trees more than high-bias or already stable learners because bootstrap averaging mainly reduces variance rather than systematic bias.",
                    ]
                )
            )
        )
        """
    ),
    md(
        """
        ## 6. Random Forest Baseline and Tuning

        Requirement:
        - Train a baseline Random Forest
        - Report accuracy and confusion matrix
        - Tune `n_estimators` using 5 values in [10, 200]
        - Tune `max_features` using `sqrt`, `log2`, and one fixed integer value
        - Plot the top 8 feature importances from the best Random Forest
        """
    ),
    code(
        """
        rf_baseline = RandomForestClassifier(random_state=RANDOM_STATE, n_jobs=1)
        rf_baseline_result = evaluate_estimator(
            "Random Forest (baseline)",
            rf_baseline,
            X_train,
            X_test,
            y_train,
            y_test,
            label_encoder,
        )

        print(f"Baseline Random Forest accuracy: {rf_baseline_result['test_accuracy']:.4f}")
        plt.figure(figsize=(8, 6))
        plot_confusion(
            y_test,
            rf_baseline_result["y_pred"],
            label_encoder.classes_,
            "Random Forest Baseline Confusion Matrix",
        )
        plt.tight_layout()
        plt.show()

        n_estimators_grid = [10, 40, 80, 120, 200]
        rf_n_rows = []
        for n_estimators in n_estimators_grid:
            estimator = RandomForestClassifier(
                n_estimators=n_estimators,
                random_state=RANDOM_STATE,
                n_jobs=1,
            )
            result = evaluate_estimator(
                f"RF (n_estimators={n_estimators})",
                estimator,
                X_train,
                X_test,
                y_train,
                y_test,
                label_encoder,
            )
            rf_n_rows.append(
                {
                    "n_estimators": n_estimators,
                    "Accuracy": result["test_accuracy"],
                }
            )

        rf_n_df = pd.DataFrame(rf_n_rows)
        best_rf_n = int(rf_n_df.sort_values("Accuracy", ascending=False).iloc[0]["n_estimators"])

        plt.figure(figsize=(8, 5))
        plt.plot(rf_n_df["n_estimators"], rf_n_df["Accuracy"], marker="o")
        plt.xlabel("Number of estimators")
        plt.ylabel("Test accuracy")
        plt.title("Random Forest Accuracy vs Number of Estimators")
        plt.show()

        max_features_grid = ["sqrt", "log2", 6]
        rf_max_feature_rows = []
        for max_features in max_features_grid:
            estimator = RandomForestClassifier(
                n_estimators=best_rf_n,
                max_features=max_features,
                random_state=RANDOM_STATE,
                n_jobs=1,
            )
            result = evaluate_estimator(
                f"RF (max_features={max_features})",
                estimator,
                X_train,
                X_test,
                y_train,
                y_test,
                label_encoder,
            )
            rf_max_feature_rows.append(
                {
                    "max_features": max_features,
                    "Accuracy": result["test_accuracy"],
                }
            )

        rf_max_feature_df = pd.DataFrame(rf_max_feature_rows)
        best_rf_max_features = rf_max_feature_df.sort_values("Accuracy", ascending=False).iloc[0]["max_features"]

        display(Markdown("**Random Forest tuning results:**"))
        display(rf_n_df.round(4))
        display(rf_max_feature_df.round(4))

        best_rf = RandomForestClassifier(
            n_estimators=best_rf_n,
            max_features=best_rf_max_features,
            random_state=RANDOM_STATE,
            n_jobs=1,
        )
        best_rf_result = evaluate_estimator(
            "Random Forest (best tuned)",
            best_rf,
            X_train,
            X_test,
            y_train,
            y_test,
            label_encoder,
        )
        family_results["Random Forest"] = best_rf_result

        rf_importances = (
            pd.Series(best_rf_result["estimator"].feature_importances_, index=X_train.columns)
            .sort_values(ascending=False)
        )
        top_8_rf_importances = rf_importances.head(8).sort_values()

        plt.figure(figsize=(8, 5))
        top_8_rf_importances.plot(kind="barh", color="teal")
        plt.xlabel("Feature importance")
        plt.title("Top 8 Feature Importances from the Best Random Forest")
        plt.show()

        plateau_point = int(
            rf_n_df.loc[
                (rf_n_df["Accuracy"].max() - rf_n_df["Accuracy"]).abs() <= 0.001,
                "n_estimators",
            ].min()
        )

        display(
            Markdown(
                "\\n".join(
                    [
                        "**Random Forest summary**",
                        f"- Baseline accuracy: **{rf_baseline_result['test_accuracy']:.4f}**.",
                        f"- Best tested `n_estimators`: **{best_rf_n}**.",
                        f"- Accuracy starts to plateau around **{plateau_point} trees**, where later gains become very small.",
                        f"- Best tested `max_features`: **{best_rf_max_features}**.",
                    ]
                )
            )
        )
        """
    ),
    md(
        """
        ## 7. Gradient Boosting

        Requirement:
        - Tune `n_estimators` using 4 values in [10, 200]
        - Using the best `n_estimators`, tune the learning rate using 4 values in [0.1, 0.9]
        - Report accuracy and confusion matrix for the best value of each parameter
        - Plot training and test accuracy vs number of estimators for the best configuration
        - Comment on overfitting behavior
        """
    ),
    code(
        """
        gb_n_grid = [10, 50, 100, 200]
        gb_n_rows = []
        gb_n_results = {}

        for n_estimators in gb_n_grid:
            estimator = GradientBoostingClassifier(n_estimators=n_estimators, random_state=RANDOM_STATE)
            result = evaluate_estimator(
                f"GB (n_estimators={n_estimators})",
                estimator,
                X_train,
                X_test,
                y_train,
                y_test,
                label_encoder,
            )
            gb_n_results[n_estimators] = result
            gb_n_rows.append({"n_estimators": n_estimators, "Accuracy": result["test_accuracy"]})

        gb_n_df = pd.DataFrame(gb_n_rows)
        best_gb_n = int(gb_n_df.sort_values("Accuracy", ascending=False).iloc[0]["n_estimators"])
        best_gb_n_result = gb_n_results[best_gb_n]

        plt.figure(figsize=(8, 5))
        plt.plot(gb_n_df["n_estimators"], gb_n_df["Accuracy"], marker="o")
        plt.xlabel("Number of estimators")
        plt.ylabel("Test accuracy")
        plt.title("Gradient Boosting Accuracy vs Number of Estimators")
        plt.show()

        plt.figure(figsize=(8, 6))
        plot_confusion(
            y_test,
            best_gb_n_result["y_pred"],
            label_encoder.classes_,
            f"Gradient Boosting Confusion Matrix (best n_estimators={best_gb_n})",
        )
        plt.tight_layout()
        plt.show()

        gb_lr_grid = [0.1, 0.3, 0.5, 0.9]
        gb_lr_rows = []
        gb_lr_results = {}

        for learning_rate in gb_lr_grid:
            estimator = GradientBoostingClassifier(
                n_estimators=best_gb_n,
                learning_rate=learning_rate,
                random_state=RANDOM_STATE,
            )
            result = evaluate_estimator(
                f"GB (learning_rate={learning_rate})",
                estimator,
                X_train,
                X_test,
                y_train,
                y_test,
                label_encoder,
            )
            gb_lr_results[learning_rate] = result
            gb_lr_rows.append({"learning_rate": learning_rate, "Accuracy": result["test_accuracy"]})

        gb_lr_df = pd.DataFrame(gb_lr_rows)
        best_gb_lr = float(gb_lr_df.sort_values("Accuracy", ascending=False).iloc[0]["learning_rate"])
        best_gb_result = gb_lr_results[best_gb_lr]
        family_results["Gradient Boosting"] = best_gb_result

        display(gb_n_df.round(4))
        display(gb_lr_df.round(4))

        plt.figure(figsize=(8, 6))
        plot_confusion(
            y_test,
            best_gb_result["y_pred"],
            label_encoder.classes_,
            f"Gradient Boosting Confusion Matrix (best learning_rate={best_gb_lr})",
        )
        plt.tight_layout()
        plt.show()

        best_gb_estimator = best_gb_result["estimator"]
        gb_train_curve = []
        gb_test_curve = []

        for staged_train_pred, staged_test_pred in zip(
            best_gb_estimator.staged_predict(X_train),
            best_gb_estimator.staged_predict(X_test),
        ):
            gb_train_curve.append(accuracy_score(y_train, staged_train_pred))
            gb_test_curve.append(accuracy_score(y_test, staged_test_pred))

        plt.figure(figsize=(10, 6))
        plt.plot(range(1, len(gb_train_curve) + 1), gb_train_curve, label="Training accuracy")
        plt.plot(range(1, len(gb_test_curve) + 1), gb_test_curve, label="Test accuracy")
        plt.xlabel("Number of estimators")
        plt.ylabel("Accuracy")
        plt.title("Gradient Boosting Learning Curve")
        plt.legend()
        plt.show()

        best_curve_idx = int(np.argmax(gb_test_curve) + 1)
        final_gap = gb_train_curve[-1] - gb_test_curve[-1]
        if best_curve_idx < len(gb_test_curve) and gb_test_curve[-1] < max(gb_test_curve) - 0.002:
            overfit_comment = "The test curve peaks before the last stage and then drops, which indicates visible overfitting."
        elif final_gap > 0.05:
            overfit_comment = "The training accuracy stays noticeably above the test accuracy, which suggests mild overfitting."
        else:
            overfit_comment = "The training and test curves remain fairly close, so overfitting is limited."

        display(
            Markdown(
                "\\n".join(
                    [
                        "**Gradient Boosting summary**",
                        f"- Best tested `n_estimators`: **{best_gb_n}** with accuracy **{best_gb_n_result['test_accuracy']:.4f}**.",
                        f"- Best tested learning rate: **{best_gb_lr}** with accuracy **{best_gb_result['test_accuracy']:.4f}**.",
                        f"- Peak test performance along the staged curve occurs around estimator **{best_curve_idx}**.",
                        f"- {overfit_comment}",
                    ]
                )
            )
        )
        """
    ),
    md(
        """
        ## 8. XGBoost

        Requirement:
        - Build an XGBoost classifier using the best `n_estimators` and `learning_rate` from Gradient Boosting
        - Report accuracy and confusion matrix
        - Tune `subsample` with values 0.6, 0.8, and 1.0
        - Explain how subsampling relates to bagging
        """
    ),
    code(
        """
        xgb_baseline = XGBClassifier(
            n_estimators=best_gb_n,
            learning_rate=best_gb_lr,
            subsample=1.0,
            objective="multi:softprob",
            num_class=7,
            eval_metric="mlogloss",
            random_state=RANDOM_STATE,
            n_jobs=1,
        )
        xgb_baseline_result = evaluate_estimator(
            "XGBoost (baseline with subsample=1.0)",
            xgb_baseline,
            X_train,
            X_test,
            y_train,
            y_test,
            label_encoder,
        )

        print(f"Baseline XGBoost accuracy: {xgb_baseline_result['test_accuracy']:.4f}")
        plt.figure(figsize=(8, 6))
        plot_confusion(
            y_test,
            xgb_baseline_result["y_pred"],
            label_encoder.classes_,
            "XGBoost Baseline Confusion Matrix",
        )
        plt.tight_layout()
        plt.show()

        xgb_subsample_rows = []
        xgb_subsample_results = {}
        for subsample in [0.6, 0.8, 1.0]:
            estimator = XGBClassifier(
                n_estimators=best_gb_n,
                learning_rate=best_gb_lr,
                subsample=subsample,
                objective="multi:softprob",
                num_class=7,
                eval_metric="mlogloss",
                random_state=RANDOM_STATE,
                n_jobs=1,
            )
            result = evaluate_estimator(
                f"XGBoost (subsample={subsample})",
                estimator,
                X_train,
                X_test,
                y_train,
                y_test,
                label_encoder,
            )
            xgb_subsample_results[subsample] = result
            xgb_subsample_rows.append(
                {
                    "subsample": subsample,
                    "Accuracy": result["test_accuracy"],
                }
            )

        xgb_subsample_df = pd.DataFrame(xgb_subsample_rows)
        best_xgb_subsample = float(xgb_subsample_df.sort_values("Accuracy", ascending=False).iloc[0]["subsample"])
        best_xgb_result = xgb_subsample_results[best_xgb_subsample]
        family_results["XGBoost"] = best_xgb_result

        display(xgb_subsample_df.round(4))

        display(
            Markdown(
                "\\n".join(
                    [
                        "**XGBoost summary**",
                        f"- Baseline accuracy with `subsample=1.0`: **{xgb_baseline_result['test_accuracy']:.4f}**.",
                        f"- Best tested subsample: **{best_xgb_subsample}** with accuracy **{best_xgb_result['test_accuracy']:.4f}**.",
                        "- Subsampling injects randomness by training each boosting round on only a fraction of the training set.",
                        "- That idea is related to bagging because both methods reduce correlation and variance through sampling, although XGBoost still adds trees sequentially to correct previous errors.",
                    ]
                )
            )
        )
        """
    ),
    md(
        """
        ## 9. Bagging vs Boosting Discussion

        Requirement:
        - Comment on the bias/variance view
        - Discuss relative training time
        - Reflect on which approach is more effective on the Dry Bean dataset
        """
    ),
    code(
        """
        bagging_vs_boosting_df = pd.DataFrame(
            [
                {
                    "Model": "Bagged SVM",
                    "Family": "Bagging",
                    "Test Accuracy": bagged_svm_result["test_accuracy"],
                    "Fit Time (s)": bagged_svm_result["fit_time_seconds"],
                },
                {
                    "Model": "Bagged DT",
                    "Family": "Bagging",
                    "Test Accuracy": bagged_dt_result["test_accuracy"],
                    "Fit Time (s)": bagged_dt_result["fit_time_seconds"],
                },
                {
                    "Model": "Random Forest",
                    "Family": "Bagging-style ensemble",
                    "Test Accuracy": best_rf_result["test_accuracy"],
                    "Fit Time (s)": best_rf_result["fit_time_seconds"],
                },
                {
                    "Model": "Gradient Boosting",
                    "Family": "Boosting",
                    "Test Accuracy": best_gb_result["test_accuracy"],
                    "Fit Time (s)": best_gb_result["fit_time_seconds"],
                },
                {
                    "Model": "XGBoost",
                    "Family": "Boosting",
                    "Test Accuracy": best_xgb_result["test_accuracy"],
                    "Fit Time (s)": best_xgb_result["fit_time_seconds"],
                },
            ]
        ).sort_values("Test Accuracy", ascending=False)

        display(bagging_vs_boosting_df.round(4))

        fastest_model = bagging_vs_boosting_df.sort_values("Fit Time (s)").iloc[0]
        most_accurate_model = bagging_vs_boosting_df.iloc[0]

        display(
            Markdown(
                "\\n".join(
                    [
                        "**Bagging vs Boosting interpretation**",
                        "- Bagging mainly reduces variance by averaging multiple models trained on bootstrap samples, which is why Decision Trees benefit strongly from it.",
                        "- Boosting mainly reduces bias by adding learners sequentially to correct previous mistakes, which often gives higher accuracy at the cost of longer or more sequential training.",
                        f"- On this dataset, the fastest ensemble among the compared families was **{fastest_model['Model']}** at about **{fastest_model['Fit Time (s)']:.2f} s**.",
                        f"- The strongest test accuracy came from **{most_accurate_model['Model']}** at **{most_accurate_model['Test Accuracy']:.4f}**.",
                        "- Overall, boosting proved slightly more effective for Dry Bean classification, while bagging gave a strong variance-reduction benefit for tree-based learners and remained simpler to interpret.",
                    ]
                )
            )
        )
        """
    ),
    md(
        """
        ## 10. Unified Model Comparison

        Requirement:
        - Compare Decision Tree, Bagged SVM, Bagged DT, Random Forest, Gradient Boosting, and XGBoost
        - Report weighted precision, weighted recall, accuracy, and weighted F1-score in one summary table
        - Identify the best and worst model for each metric
        """
    ),
    code(
        """
        comparison_rows = []
        for model_name in [
            "Decision Tree",
            "Bagged SVM",
            "Bagged DT",
            "Random Forest",
            "Gradient Boosting",
            "XGBoost",
        ]:
            result = family_results[model_name]
            comparison_rows.append(
                {
                    "Model": model_name,
                    "Weighted Precision": result["precision"],
                    "Weighted Recall": result["recall"],
                    "Accuracy": result["test_accuracy"],
                    "Weighted F1": result["f1"],
                }
            )

        comparison_df = pd.DataFrame(comparison_rows).sort_values("Weighted F1", ascending=False).reset_index(drop=True)
        display(comparison_df.round(4))

        metric_columns = ["Weighted Precision", "Weighted Recall", "Accuracy", "Weighted F1"]
        best_worst_rows = []
        for metric in metric_columns:
            best_row = comparison_df.loc[comparison_df[metric].idxmax()]
            worst_row = comparison_df.loc[comparison_df[metric].idxmin()]
            best_worst_rows.append(
                {
                    "Metric": metric,
                    "Best Model": best_row["Model"],
                    "Best Value": best_row[metric],
                    "Worst Model": worst_row["Model"],
                    "Worst Value": worst_row[metric],
                }
            )

        best_worst_df = pd.DataFrame(best_worst_rows)
        display(best_worst_df.round(4))

        best_model_name = comparison_df.iloc[0]["Model"]

        dominant_models = best_worst_df["Best Model"].unique()
        if len(dominant_models) == 1:
            dominance_comment = f"The same model, **{dominant_models[0]}**, dominates all reported metrics."
        else:
            dominance_comment = "No single model dominates every metric, so model choice depends on which metric matters most."

        display(Markdown(f"**Step 10 conclusion:** {dominance_comment}"))
        """
    ),
    md(
        """
        ## 11. Complexity Reduction on the Best Model

        Requirement:
        - Select the best-performing model from the previous section
        - Apply PCA, determine the number of components needed for 95% variance, and retrain the model
        - Use Random Forest feature importances to select the top 6 features, then retrain the same best model
        - Visualize the PCA reduction and the selected-feature importances
        """
    ),
    code(
        """
        model_specs = make_model_specs(
            best_dt_alpha=best_dt_alpha,
            best_rf_n=best_rf_n,
            best_rf_max_features=best_rf_max_features,
            best_gb_n=best_gb_n,
            best_gb_lr=best_gb_lr,
            best_xgb_subsample=best_xgb_subsample,
        )

        display(Markdown(f"**Best model chosen for complexity reduction:** `{best_model_name}`"))

        scaler_for_pca = StandardScaler()
        X_train_scaled = scaler_for_pca.fit_transform(X_train)
        X_test_scaled = scaler_for_pca.transform(X_test)

        full_pca = PCA().fit(X_train_scaled)
        explained_variance = full_pca.explained_variance_ratio_
        cumulative_variance = np.cumsum(explained_variance)
        n_components_95 = int(np.argmax(cumulative_variance >= 0.95) + 1)

        plt.figure(figsize=(10, 5))
        plt.bar(
            np.arange(1, len(explained_variance) + 1),
            explained_variance,
            alpha=0.75,
            label="Individual explained variance",
        )
        plt.step(
            np.arange(1, len(cumulative_variance) + 1),
            cumulative_variance,
            where="mid",
            color="red",
            label="Cumulative explained variance",
        )
        plt.axhline(0.95, color="black", linestyle="--", label="95% variance threshold")
        plt.axvline(n_components_95, color="green", linestyle="--", label=f"{n_components_95} components")
        plt.xlabel("Principal component")
        plt.ylabel("Explained variance ratio")
        plt.title("PCA Explained Variance")
        plt.legend()
        plt.show()

        pca_2d = PCA(n_components=2)
        X_2d = pca_2d.fit_transform(StandardScaler().fit_transform(X))
        pca_plot_df = pd.DataFrame(X_2d, columns=["PC1", "PC2"])
        pca_plot_df["Class"] = clean_df["Class"].values

        plt.figure(figsize=(10, 6))
        sns.scatterplot(data=pca_plot_df, x="PC1", y="PC2", hue="Class", alpha=0.65, s=45)
        plt.title("PCA Projection onto the First Two Components")
        plt.legend(bbox_to_anchor=(1.02, 1), loc="upper left")
        plt.show()

        pca_model = build_pca_estimator(best_model_name, n_components_95)
        pca_result = evaluate_estimator(
            f"{best_model_name} + PCA",
            pca_model,
            X_train,
            X_test,
            y_train,
            y_test,
            label_encoder,
        )

        top_6_features = rf_importances.head(6)
        display(Markdown("**Top 6 features selected using Random Forest importances:**"))
        display(top_6_features.rename("Importance").to_frame().round(4))

        plt.figure(figsize=(8, 5))
        top_6_features.sort_values().plot(kind="barh", color="darkorange")
        plt.xlabel("Feature importance")
        plt.title("Selected Top 6 Feature Importances")
        plt.show()

        selected_feature_names = top_6_features.index.tolist()
        selected_feature_model = build_estimator(best_model_name)
        feature_selected_result = evaluate_estimator(
            f"{best_model_name} + top 6 features",
            selected_feature_model,
            X_train[selected_feature_names],
            X_test[selected_feature_names],
            y_train,
            y_test,
            label_encoder,
        )

        print(f"Components needed for 95% variance: {n_components_95}")
        """
    ),
    md(
        """
        ## 12. Evaluate the Reduced-Complexity Variants

        Requirement:
        - Report weighted precision, weighted recall, accuracy, and weighted F1-score
        - Use the same metric format as the unified comparison table
        """
    ),
    code(
        """
        reduced_models_df = pd.DataFrame(
            [
                {
                    "Model Variant": "PCA-reduced",
                    "Weighted Precision": pca_result["precision"],
                    "Weighted Recall": pca_result["recall"],
                    "Accuracy": pca_result["test_accuracy"],
                    "Weighted F1": pca_result["f1"],
                },
                {
                    "Model Variant": "Feature-selected",
                    "Weighted Precision": feature_selected_result["precision"],
                    "Weighted Recall": feature_selected_result["recall"],
                    "Accuracy": feature_selected_result["test_accuracy"],
                    "Weighted F1": feature_selected_result["f1"],
                },
            ]
        )
        display(reduced_models_df.round(4))
        """
    ),
    md(
        """
        ## 13. Final Comparison and Recommendation

        Requirement:
        - Compare the original best model against the PCA-reduced and feature-selected versions
        - Present a side-by-side table
        - Discuss the trade-off between complexity, interpretability, and predictive performance
        - State which version is recommended for production
        """
    ),
    code(
        """
        original_best_result = family_results[best_model_name]

        final_comparison_df = pd.DataFrame(
            [
                {
                    "Version": "Original",
                    "Weighted Precision": original_best_result["precision"],
                    "Weighted Recall": original_best_result["recall"],
                    "Accuracy": original_best_result["test_accuracy"],
                    "Weighted F1": original_best_result["f1"],
                },
                {
                    "Version": "PCA-reduced",
                    "Weighted Precision": pca_result["precision"],
                    "Weighted Recall": pca_result["recall"],
                    "Accuracy": pca_result["test_accuracy"],
                    "Weighted F1": pca_result["f1"],
                },
                {
                    "Version": "Feature-selected",
                    "Weighted Precision": feature_selected_result["precision"],
                    "Weighted Recall": feature_selected_result["recall"],
                    "Accuracy": feature_selected_result["test_accuracy"],
                    "Weighted F1": feature_selected_result["f1"],
                },
            ]
        )
        display(final_comparison_df.round(4))

        original_accuracy = original_best_result["test_accuracy"]
        pca_accuracy = pca_result["test_accuracy"]
        fs_accuracy = feature_selected_result["test_accuracy"]

        if original_accuracy - fs_accuracy <= 0.005:
            production_recommendation = "Feature-selected"
            recommendation_reason = "It keeps performance very close to the original model while reducing input dimensionality and improving interpretability."
        elif original_accuracy - pca_accuracy <= 0.005:
            production_recommendation = "PCA-reduced"
            recommendation_reason = "It preserves most of the predictive power while giving the smallest representation."
        else:
            production_recommendation = "Original"
            recommendation_reason = "Both reduced variants lose a noticeable amount of predictive performance, so the full model remains the safest production choice."

        display(
            Markdown(
                "\\n".join(
                    [
                        "**Final discussion**",
                        f"- The original best model was **{best_model_name}** with accuracy **{original_accuracy:.4f}**.",
                        f"- The PCA-reduced version used **{n_components_95} principal components** and reached accuracy **{pca_accuracy:.4f}**.",
                        f"- The feature-selected version used the top 6 Random Forest features and reached accuracy **{fs_accuracy:.4f}**.",
                        "- PCA gives the strongest dimensionality reduction, but it makes the features less interpretable because the model now works on synthetic components instead of original measurements.",
                        "- Feature selection is more interpretable because the model still uses original bean measurements, but it may discard some useful secondary information.",
                        f"- **Recommended production version:** **{production_recommendation}**. {recommendation_reason}",
                    ]
                )
            )
        )
        """
    ),
]


nb = nbf.v4.new_notebook(
    cells=cells,
    metadata={
        "kernelspec": {
            "display_name": "Python 3",
            "language": "python",
            "name": "python3",
        },
        "language_info": {
            "name": "python",
            "version": "3.13",
        },
    },
)

NOTEBOOK_PATH.parent.mkdir(parents=True, exist_ok=True)
with NOTEBOOK_PATH.open("w", encoding="utf-8") as f:
    nbf.write(nb, f)

print(f"Notebook written to {NOTEBOOK_PATH}")
