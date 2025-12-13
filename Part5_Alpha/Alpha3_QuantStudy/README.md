# Alpha3 - Layer-Sensitivity Mixed-Precision Quantization

## Description
This Alpha submission profiles **layer-wise activation quantization sensitivity** and then **automatically selects “safe” layers** for more aggressive quantization to achieve a strong **accuracy vs. compression/efficiency** tradeoff.

## Structure
- `software/` - Jupyter notebook with quantization analysis

## Contents
- `Project_Part4.ipynb` - Quantization study notebook containing:
  - Per-layer sensitivity analysis (e.g., switch one layer from 4-bit → 2-bit and measure accuracy drop)
  - A greedy mixed-precision search that picks layers to quantize under an accuracy-drop budget (ε)
  - Accuracy vs. bit-width tradeoffs and the resulting mixed-precision configuration

## How to Run
1. Open `software/Project_Part4.ipynb` in Jupyter Notebook or Google Colab
2. Run all cells to reproduce the quantization analysis

