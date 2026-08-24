# OCT Skin Layer Analyzer

[![MATLAB](https://img.shields.io/badge/MATLAB-R2024b%2B-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Release](https://img.shields.io/github/v/release/Corneliox/OCT_Analyzer?color=brightgreen)](https://github.com/Corneliox/OCT_Analyzer/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)]()
[![License](https://img.shields.io/badge/License-Academic-green.svg)]()

> **High-throughput, GPU-accelerated desktop application and automated analysis pipeline for skin optical coherence tomography (OCT) B-scan segmentation and dynamic thickness tracking.**

---

## 📸 Output & Visualizations

| Layer Segmentation & Boundary Tracking | Dynamic Time-Series Analysis |
| :---: | :---: |
| ![Segmentation Overview](docs/images/P04_result_picking.png) | ![Time Series Result](docs/images/P04_result_timeseries.png) |

| Stratum Corneum (SC) Layer | Epidermis (ED) Layer | Full Skin Thickness |
| :---: | :---: | :---: |
| ![SC Result](docs/images/P04_result_StratumCorneum_SC_.png) | ![ED Result](docs/images/P04_result_Epidermis_ED_.png) | ![Full Skin Result](docs/images/P04_result_FullSkin.png) |

---

## 📖 Overview

The **OCT Skin Layer Analyzer** is an automated pipeline designed for skin biomechanics, dermatology, and cosmetic research. It processes multi-frame OCT time-series sequences to accurately segment skin layers and dynamically track layer thickness changes over time (e.g., during mechanical stimulation, hydration, or topical treatments).

### Key Tracked Boundaries
1. 🔴 **Red Boundary (`top SC`):** Top surface of the **Stratum Corneum** (skin surface interface).
2. 🟡 **Yellow Boundary (`bot SC`):** Boundary between the **Stratum Corneum** and viable **Epidermis**.
3. 🟢 **Green Boundary (`end ED`):** Dermal-Epidermal Junction (**DEJ**) separating the **Epidermis** from the **Dermis**.

### Measured Quantitative Outputs:
* **Stratum Corneum (SC) Thickness** (mm / px)
* **Epidermis (ED) Thickness** (mm / px)
* **Total Skin Thickness** (mm / px)
* **Surface Displacement** (mm / px)

---

## ⚡ Performance Optimizations

This optimized release includes high-throughput algorithmic enhancements tuned for 4 GB VRAM GPUs:

* 🚀 **GPU Mini-Batching:** Groups incoming frames into multi-image batches (`BatchSize = 8`) to maximize GPU tensor core concurrency, dramatically lowering seconds-per-frame inference time.
* ⚡ **Vectorized Dynamic Programming (DP):** Eliminated nested pixel-by-pixel loops in the line-tracing algorithm. Replaced 512+ row iterations with single-instruction 1D min-convolution matrix shifts, reducing CPU pathfinding runtime by over **85%**.
* 🛡️ **Speckle-Preserving Preprocessing:** Uses a symmetric 2D median filter (`medfilt2`) on the dominant red color channel, stripping high-frequency OCT speckle noise without blurring sharp structural layer boundaries.

---

## 🔄 Pipeline Architecture

```mermaid
flowchart TD
    A[Raw OCT B-Scans] --> B[Preprocessing: Red Channel + Median Filter + 50% Crop]
    B --> C[U-Net Variant A: ResNet-18 Deep Segmentation]
    C --> D[Probability Maps: BG / SC / ED]
    D --> E[Vectorized Dynamic Programming Boundary Pathfinding]
    E --> F[Coordinate Extraction: top_sc, bot_sc, end_ed]
    F --> G[timeseries.csv & timeseries.png Time-Depth Overlays]
```

---

## 📥 Download & Installation

### Option 1: Standalone Installers (No MATLAB Required)
Pre-built packages are available on the [**Releases Page**](https://github.com/Corneliox/OCT_Analyzer/releases):

* **Windows:** Download and run `OCTAnalyzer_OptimizedInstaller.exe`.
* **Linux (Ubuntu / Debian / CentOS):** Download `OCTAnalyzer_Optimized_Linux_x86_64.tar.gz`, extract, and execute:
  ```bash
  tar -xzf OCTAnalyzer_Optimized_Linux_x86_64.tar.gz
  ./run_OCTAnalyzer_Optimized.sh <MATLAB_Runtime_Path>
  ```

---

### Option 2: Running in MATLAB (Cross-Platform: Windows, Linux, macOS)
1. Clone the repository:
   ```bash
   git clone https://github.com/Corneliox/OCT_Analyzer.git
   cd OCT_Analyzer
   ```
2. Open MATLAB and run the graphical interface:
   ```matlab
   OCTAnalyzerApp
   ```

---

## 📁 Repository Structure

```text
├── docs/images/                # Documentation figures and result screenshots
├── trained_variantA/
│   └── unet_variantA_*.mat     # Trained ResNet-18 U-Net deep learning weights
├── OCTAnalyzerApp.m            # Desktop Graphical User Interface (GUI)
├── batch_analyze_tree.m        # Recursive multi-condition directory batch processor
├── analyze_stimulation_run.m   # Time-series analysis, metrics computation, and PNG plotting
├── segment_new_images.m        # GPU-batched neural network inference engine
├── extract_boundaries_dp.m     # Vectorized dynamic programming boundary extractor
├── preprocess_image_only.m     # Denoising and image preparation filter
├── compile_oct_app_installer.m # Cross-platform standalone installer compiler script
└── .gitignore                  # Git exclude rules for outputs, logs, and temp binaries
```

---

## 📄 License & Attribution
Developed for OCT image processing and skin biomechanics research.
Available under the Academic Research License.
