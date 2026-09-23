# 🚀 OCT Skin Layer Analyzer v2.1.0

We are proud to announce the release of **OCT Skin Layer Analyzer v2.1.0**! This major update brings a complete overhaul of the batch directory discovery engine, introduces regularized spike-free Epidermal-Dermal Junction (`end ED`) boundary extraction, and modernizes the desktop UI for full native responsiveness on Windows 10 and Windows 11.

---

## 🌟 What's New in v2.1.0

### 1. 🌲 Intelligent Subject-Level Batch Crawler
* **Automated Deep Hierarchy Traversal:** You no longer need to manually pick subjects or protocol folders one by one. Select any top/master directory (even across multiple nested protocol sets), and the crawler recursively identifies all subjects and scan series (`_N` or `_N.bin`).
* **Subject-Level Output Placement (`SubX_analysis/`):** Analysis outputs (`timeseries.csv` and `timeseries.png`) are now automatically placed **directly beside each subject folder**, preserving clean anatomical dataset organization.
* **Preserved Raw Output Cache:** Intermediate `_out` segmentation directories are preserved and respected, preventing unnecessary re-segmentation across runs.
* **Unattended Overnight Execution:** Includes robust per-subject error recovery (`try/catch`), systemic failure circuit-breakers, and auto-skip logic for previously completed subjects.

```text
Master_Study_Root/
├── Subject_01/
│   └── Protocol_A/
│       ├── scan_0.bin/            (contains raw B-scans)
│       ├── scan_0.bin_out/        (segmentation cache)
│       └── scan_1.bin/
├── Subject_01_analysis/           <-- [Generated directly beside Subject_01]
│   ├── timeseries.csv
│   └── timeseries.png
│
├── Subject_02/
│   └── Protocol_B/
│       └── scan_0.bin/
├── Subject_02_analysis/           <-- [Generated directly beside Subject_02]
│
├── batch_summary.csv              <-- [Overall batch execution report]
└── batch_log.txt                  <-- [Unattended execution log]
```

---

### 2. 🛡️ Robust & Spike-Free Epidermis (`end ED` / DEJ) Boundary Extraction
* **Regularized Dynamic Programming:** Resolved the severe vertical jitter and spike artifacts on the lower Epidermal boundary caused by low optical SNR and dermal scattering shadows at greater depths.
* **Dual-Stage Outlier Rejection:** Integrated an adaptive Hampel filter (with fallback to median filtering) coupled with Savitzky-Golay smoothing across both spatial B-scan columns and temporal time-series frames.
* **Physiological Thickness Constraint:** Mathematically enforces non-zero layer thickness ($z_{\text{ED}} \ge z_{\text{bot SC}} + \Delta$), ensuring the green boundary never errantly crosses or jumps through the Stratum Corneum.

---

### 3. 🖥️ Modern Responsive UI (Windows 10 & 11 Native)
* **Responsive `uigridlayout`:** Replaced legacy fixed absolute pixel positioning with a flexible grid layout that automatically adapts to window resizing and full-screen maximization.
* **High-DPI Scaling Friendly:** Native rendering and crisp text on High-DPI screens (100%, 125%, 150%, and 175% display scaling) using system-standard `Segoe UI` fonts.
* **Auto-Expanding Progress Console:** The live status terminal dynamically expands to utilize available screen real-estate, keeping long batch runs easily readable.

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
2. Double-click to launch immediately—no installation wizard required!

### Option B: Windows Setup Installer (Recommended for Clean Machines)
If you are distributing to another computer or do not have MATLAB Runtime installed:
1. Download **`OCTAnalyzer_OptimizedInstaller_Win.exe`** (~36.7 MB) below.
2. Run the installer wizard. It will automatically download and configure the free MathWorks MATLAB Runtime (R2025b) for you.
3. Launch **OCT Skin Layer Analyzer** directly from your Windows Start Menu or Desktop shortcut.

---

## 💻 System Requirements
* **Operating System:** Windows 10 (64-bit) or Windows 11.
* **Memory (RAM):** 8 GB minimum (16 GB recommended for high-volume 500-frame time series).
* **GPU (Optional):** NVIDIA GPU with $\ge$ 4 GB VRAM for accelerated neural network inference (CPU fallback supported).
* **Runtime:** MATLAB Runtime R2025b (v25.2).

---

## 📄 Source Code & Verification
* Commit: `d208bb8`
* Tag: `v2.1.0`
* Developed for skin biomechanics, dermatology, and optical coherence tomography (OCT) imaging research.
