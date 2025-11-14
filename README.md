# Vivado FFT and IFFT Project

## Introduction

這是michael找到的網站程式碼，主要功能是如下流程

```text
ADC -> ASYN_FIFO -> FFT -> IFFT -> SYN_FIFO
```

## Copy File

```text
copy_fft_ifft/adc_iq_cail.v
copy_fft_ifft/cail_fft_ifft.v
copy_fft_ifft/cail_testbench.v
```

這三個檔案分別代表的功能是:

- adc_iq_cail.v: ADC和ASYN_FIFO的頂層交互介面
- cail_fft_ifft.v: FFT和IFFT的頂層交互介面
- cail_testbench.v: 測試程式碼，用於模擬ADC和ASYN_FIFO的輸入，以及FFT和IFFT的輸出

## Website

[CSDN 作者文章連結](https://blog.csdn.net/2301_80127702/article/details/149437989)
