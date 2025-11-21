# Vivado FFT and IFFT Project

## Introduction

這是michael找到的網站程式碼，主要功能是如下流程

```text
ADC -> ASYN_FIFO -> FFT -> IFFT -> SYN_FIFO
```

## Copy File

```text
src/adc_iq_cail.v
src/cail_fft_ifft.v
src/cail_testbench.v
```

這三個檔案分別代表的功能是:

- adc_iq_cail.v: ADC和ASYN_FIFO的頂層交互介面
- cail_fft_ifft.v: FFT和IFFT的頂層交互介面
- cail_testbench.v: 測試程式碼，用於模擬ADC和ASYN_FIFO的輸入，以及FFT和IFFT的輸出
  - 這邊會使用dds_compiler 來產生sin cos的訊號(100MHz)，asyn fifo接收100MHz之後，會以300MHz的方式給cail_fft_ifft

## Website

[CSDN 作者文章連結](https://blog.csdn.net/2301_80127702/article/details/149437989)

## Result
- 20251121 目前有將整段程式碼完成復刻，測試結果會覺得作者寫得很奇怪，testbench也動不起來，所以可能還需要重構頂層模組。
