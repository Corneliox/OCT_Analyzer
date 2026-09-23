# 🚀 OCT Skin Layer Analyzer v2.3.0

We are pleased to announce **OCT Skin Layer Analyzer v2.3.0**! This release introduces critical stability enhancements for directory hierarchy auto-discovery and complex timestamp parsing, alongside the core v2.2.0 foundation of 100% legacy pipeline compatibility (Richard V1 design), regularized spike-free boundary tracking, and Windows 10/11 native responsive UI.

---

## 🌟 What's New in v2.3.0

### 1. 🛡️ Robust Timestamp Parsing & Zero False-Positive Crawler
* **Immunity to Decimal Timestamps:** Resolved an issue where condition subfolders containing dot timestamps (e.g. `1_30_after_11.33` or `protocol_14.50`) were mistakenly parsed as file extensions with scan indices (`_11` + `.33`).
* **Strict Non-Directory Image Filter:** Updated `folder_has_images` with strict `~[d.isdir]` filtering, preventing subdirectories ending in `.bin/` (e.g. `raw_..._MMode_0.bin/`) from being misclassified as loose image files.
* **Flawless Multi-Subject Traversal:** The tree crawler now cleanly traverses from master root (`oct ica/`), descends past subject folders (`bayu/`, `azmi/`), and correctly locks onto every protocol condition run without early termination.

### 2. 🎯 100% Legacy Pipeline Compatibility (Richard V1 Preserved)
* **In-Protocol Analysis Outputs:** All primary analysis outputs (`timeseries.csv` and `timeseries.png`) are saved **directly inside the protocol directory** as `<protocol>_analysis/` (e.g., `azmi/1_30_after_analysis/timeseries.csv`), strictly honoring Richard's original V1 design.
* **Full Downstream Compatibility:** Existing downstream analysis scripts (biomechanics, stiffness, strain, pick event) continue to function without any modifications.
* **Cached Segmentation Integrity:** Intermediate raw `_out` segmentation directories are preserved and reused automatically.

### 3. 🌲 Universal Multi-Scale Top Folder Crawler
* **Flexible Input Selection:** Select any top folder level:
  * Master Root Study folder (e.g., `oct ica/` with multiple subjects)
  * Protocol Set / Batch folder (above `oct ica/`)
  * Individual Subject folder (e.g., `azmi/`)
  * Individual Protocol folder (e.g., `1_30_after/`)
* **Automated Sequential Execution:** Automatically identifies and queues every protocol scan across all subjects without requiring manual selection.
* **Optional Subject Mirror Export:** In addition to the primary legacy output, results are mirrored to `<subject>_analysis/` (e.g., `azmi_analysis/1_30_after_timeseries.csv`), enabling instant side-by-side protocol comparison in a single folder.

```text
oct ica/                           <-- [Select this or any folder in the App]
├── azmi/
│   ├── 1_30_after/
│   │   ├── raw_..._MMode_0.bin/   (raw scan data)
│   │   └── raw_..._MMode_0.bin_out/ (segmentation cache)
│   ├── 1_30_after_analysis/       <-- [PRIMARY V1 OUTPUT: timeseries.csv & .png]
│   ├── 1_30_before/
│   └── 1_30_before_analysis/      <-- [PRIMARY V1 OUTPUT: timeseries.csv & .png]
│
├── azmi_analysis/                 <-- [MIRRORED SUBJECT OVERVIEW]
│   ├── 1_30_after_timeseries.csv
│   ├── 1_30_after_timeseries.png
│   ├── 1_30_before_timeseries.csv
│   └── ...
│
├── batch_summary.csv              <-- [Overall batch execution report]
└── batch_log.txt                  <-- [Unattended execution log]
```

### 4. 🛡️ Robust & Spike-Free Epidermis (`end ED` / DEJ) Boundary Extraction
* **Regularized Dynamic Programming:** Upgraded curvature penalty ($\lambda_{\text{ed}} = 2.0$) and constrained jump radius ($max\_jump = 3$) eliminate depth-scattering traps and false local maxima.
* **Multi-Stage Outlier Rejection:** Hampel and Savitzky-Golay filters strip vertical impulse noise across B-scan columns and sequential time-series frames.
* **Physiological Thickness Constraint:** Enforces non-zero anatomical layer separation ($z_{\text{ED}} \ge z_{\text{bot SC}} + \Delta$).

### 5. 🖥️ Modern Responsive UI (Windows 10 & 11 Native)
* **Responsive `uigridlayout`:** Dynamically scales to monitor resolutions and window resize/maximize events.
* **High-DPI Scaling Friendly:** Crisp text on 100%, 125%, 150%, and 175% scaling using native `Segoe UI`.

---

## 🎯 Tracked Anatomical Boundaries
1. 🔴 **Red Line (`top SC`):** Skin surface / Stratum Corneum interface with air.
2. 🟡 **Yellow Line (`bot SC`):** Boundary between Stratum Corneum and viable Epidermis.
3. 🟢 **Green Line (`end ED`):** Dermal-Epidermal Junction (DEJ) separating Epidermis from Papillary Dermis.

---

## 📦 Downloads & Installation

### Option A: Standalone Executable (Fastest)
If you already have **MATLAB R2025b** or the **MATLAB Runtime R2025b (v25.2)** installed:
1. Download **`OCTAnalyzer_Optimized.exe`** (~35.2 MB) below.
2. Double-click to launch immediately.

### Option B: Windows Setup Installer (Recommended for Clean Machines)
If you are distributing to another computer or do not have MATLAB Runtime installed:
1. Download **`OCTAnalyzer_OptimizedInstaller_Win.exe`** (~36.7 MB) below.
2. Run the installer wizard. It will automatically download and configure the free MathWorks MATLAB Runtime (R2025b).
3. Launch **OCT Skin Layer Analyzer** directly from your Windows Start Menu or Desktop shortcut.

---

## 💻 System Requirements
* **Operating System:** Windows 10 (64-bit) or Windows 11.
* **Memory (RAM):** 8 GB minimum (16 GB recommended for high-volume 500-frame time series).
* **GPU (Optional):** NVIDIA GPU with $\ge$ 4 GB VRAM for accelerated neural network inference (CPU fallback supported).
* **Runtime:** MATLAB Runtime R2025b (v25.2).

---

## 📄 Verification
* Version: `v2.3.0`
* Developed for skin biomechanics, dermatology, and optical coherence tomography (OCT) imaging research.
