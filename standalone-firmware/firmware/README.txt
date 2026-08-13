Official Ubiquiti mFi mPower stock firmware (last release): MF.v2.1.11.bin
Same image for 1 / 3 / 6-port mPower (M2M) from 2.1.x onward.

This file ships in the git clone:
  standalone-firmware\firmware\MF.v2.1.11.bin

Flash from local (device AP 192.168.2.20, no internet needed):
  .\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -StockBin .\firmware\MF.v2.1.11.bin -KeepToken
  .\deploy.ps1 -Target 192.168.2.20 -UpgradeStock -KeepToken

-UpgradeStock uses the local file first.
Download only if the file is missing (GitHub, then Ubiquiti CDN):
  https://github.com/mlteknoloji/ubnt_mPOWER/raw/main/standalone-firmware/firmware/MF.v2.1.11.bin
  https://dl.ubnt.com/mfi/2.1.11/firmware/M2M/firmware.bin
