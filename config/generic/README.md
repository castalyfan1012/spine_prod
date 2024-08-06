# Summary of Generic full chain configurations and their characteristics

The configurations below have been trained on generic datasets, i.e datasets which do not include any detector simulation. This summary is divided by training/validation dataset.

## Configurations for MPV/MPR v04

These weights have been trained/validated using the following files:
- Training set: `/sdf/data/neutrino/generic/mpvmpr_2020_01_v04/train.root`
- Test set: `/sdf/data/neutrino/generic/mpvmpr_2020_01_v04/test.root`

### July 18th 2024

```shell
generic_full_chain_240718.cfg
```

Description:
  - UResNet + PPN + gSPICE + GrapPAs (track + shower + interaction)

Known issue(s):
  - The shower start point prediction of electron showers is problematic due to the way PPN labeling is trained

### August 5th 2024

```shell
generic_full_chain_240805.cfg
```

Description:
  - UResNet + PPN + gSPICE + GrapPAs (track + shower + interaction)
  - Updates since the previous iteration:
    - Removed end-point prediction from PPN (not used)
    - Restricted the PPN mask to voxels within the particle cluster (improve semantic + PPN)
    - Switched from kNN to radius graph for Graph-SPICE
    - Increased the width of the GrapPA-inter MLP from 64 to 128

Known issue(s):
  - Nothing obvious
