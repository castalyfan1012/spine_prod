# Summary of SBND full chain configurations and their characteristics

The configurations below have been trained on SBND MPV/MPR datasets. This summary is divided by training/validation dataset.

## Configurations for MPV/MPR v02

These weights have been trained/validated using the following files:
- Training set: `/sdf/data/neutrino/sbnd/simulation/mpvmpr_v01/train.list`
- Test set: `/sdf/data/neutrino/sbnd/simulation/mpvmpr_v01/test.list`

### July 20th 2024

```shell
sbnd_full_chain_240720.cfg
sbnd_full_chain_data_240720.cfg
```

Description:
  - UResNet + PPN + gSPICE + GrapPAs (track + shower + interaction)
  - Class-weighted loss on PID predictions
  - The `*_data_*` declination is tailored for data (no labels)

Known issue(s):
  - The shower start point prediction of electron showers is problematic due to the way PPN labeling is trained
  - Flashes but no flash matching
