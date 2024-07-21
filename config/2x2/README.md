# Summary of 2x2 full chain configurations and their characteristics

The configurations below have been trained on a 2x2 MPV/MPR datasets. This summary is divided by training/validation dataset.

## Configurations for MPV/MPR v01

These weights have been trained/validated using the following files:
- Training set: `/sdf/data/neutrino/2x2/sim/mpvmpr_v1/train_file_list.txt`
- Test set: `/sdf/data/neutrino/2x2/sim/mpvmpr_v1/test_file_list.txt`

### July 19th 2024

```shell
2x2_full_chain_240719.cfg
```

Description:
  - UResNet + PPN + gSPICE + GrapPAs (track + shower + interaction)

Known issue(s):
  - Module 2 packets are simply wrong (performance in that module is terrible, may affect others)
