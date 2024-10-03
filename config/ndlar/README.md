# Summary of ND-LAr full chain configurations and their characteristics

The configurations below have been trained on ND-LAr MPV/MPR datasets. This summary is divided by training/validation dataset.

## Frankenstein configurations

These configurations have been trained using 2x2 and are not expected to work properly. These configurations are to be exclusively used to benchmark SPINE's resource usage at ND-LAr but are not to be used to benchmark reconstruction performance or produce physics results.

### August 19th 2024

```shell
ndlar_full_chain_flash_240819.cfg
```

Description:
  - UResNet + PPN + gSPICE + GrapPAs (track + shower + interaction)
  - Includes flash parsing

Known issue(s):
  - This set of weights is not appropriate for ND-LAr
