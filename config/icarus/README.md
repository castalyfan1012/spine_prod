# Summary of ICARUS full chain configurations and their characteristics

The configurations below have been trained on a ICARUS MPV/MPR datasets. This summary is divided by training/validation dataset.

## Configurations for MPV/MPR v02

These weights have been trained/validated using the following files:
- Training set: `/sdf/data/neutrino/icarus/sim/mpvmpr_v2/train_file_list.txt`
- Test set: `/sdf/data/neutrino/icarus/sim/mpvmpr_v2/test_file_list.txt`

### July 19th 2024

```shell
icarus_full_chain_240719.cfg
icarus_full_chain_single_240719.cfg
icarus_full_chain_numi_240719.cfg
icarus_full_chain_data_240719.cfg
```

Description:
  - UResNet + PPN + gSPICE + GrapPAs (track + shower + interaction)
  - Class-weighted loss on PID predictions
  - The `*_single_*` declination works on single-cryostat simulations
  - The `*_numi_*` declination has a wider flash matching window (10 us)
  - The `*_data_*` declination is tailored for data (no labels)

Known issue(s):
  - No obvious issues
