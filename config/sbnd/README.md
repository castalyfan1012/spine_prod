# Summary of SBND full chain configurations and their characteristics

The configurations below have been trained on SBND MPV/MPR datasets. This summary is divided by training/validation dataset.

## Configurations for MPV/MPR v01

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

### August 14th 2024

```shell
sbnd_full_chain_240814.cfg
sbnd_full_chain_data_240814.cfg
```

Description:
  - UResNet + PPN + gSPICE + GrapPAs (track + shower + interaction)
  - Class-weighted loss on PID predictions
  - The `*_data_*` declination is tailored for data (no labels)

Known issue(s):
  - Resolves the issue with the PPN target in the previous set of weights
  - Removed PPN-based end point predictions
  - No other known issue

### September 18th 2024

```shell
sbnd_full_chain_240918.cfg
sbnd_full_chain_data_240918.cfg
```

Description:
  - UResNet + PPN + gSPICE + GrapPAs (track + shower + interaction)
  - Class-weighted loss on PID predictions
  - The `*_data_*` declination is tailored for data (no labels)
  - This is the first configuration which **includes flash matching**

Known issue(s):
  - Resolves the issue with the PPN target in the previous set of weights
  - Removed PPN-based end point predictions
  - No other known issue
