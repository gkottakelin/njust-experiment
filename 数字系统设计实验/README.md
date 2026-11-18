# 数字系统设计实验

本实验基于 EGO1 FPGA 开发板和外接 AD/DA 模块，使用 Verilog 实现分频、动态显示、DDS 正弦信号产生、输入信号测频及两路数字移频。六项功能集成在同一顶层，通过拨码开关选择，切换时不需要重新下载或复位。

## 实验内容

| 实验 | 功能 | 实现概要 |
| --- | --- | --- |
| 实验 1 | 时钟分频 | 将 100 MHz 主时钟分频，输出 10 MHz 和 1 kHz 信号。 |
| 实验 2 | 数码管动态显示 | 扫描显示学号或根据拨码控制字计算的频率设置值。 |
| 实验 3 | DDS 信号产生 | 使用 8 位相位累加器和正弦查找表，经 DAC 输出正弦波。 |
| 实验 4 | 频率测量 | 对 ADC 输入进行调理、周期事件检测和整周期计时，结果由数码管显示。 |
| 实验 5A | 频率下移 500 kHz | 输入样本与 500 kHz 本振混频，经 81 抽头低通 FIR 提取差频。 |
| 实验 5B | 频率下移 100 kHz | 输入样本与 100 kHz 本振混频，经 401 抽头低通 FIR 提取差频。 |

实验 4 的任务输入频率范围为 100 Hz～2 MHz；实验 5A、5B 的任务输入频率范围为 500～600 kHz。

## 环境与接口

- FPGA：EGO1 开发板，XC7A35T-1CSG324。
- 软件：Vivado；现有工程由 Vivado 2025.2 创建。
- AD/DA：MS9280 ADC、MS9708 DAC；P3 接收模拟输入，P4 输出模拟信号。
- 板上 100 MHz 主时钟；J2、J3 分别观察 10 MHz 和 1 kHz 分频输出。

## 工程结构

```text
数字系统设计实验/
├── combined_experiments/         # 六项功能的综合工程
│   ├── rtl/                      # Verilog 源码和正、余弦查找表
│   ├── sim/                      # 仿真测试文件
│   ├── constraints/              # 引脚与时序约束
│   ├── scripts/                  # 建工程、构建、仿真与分析脚本
│   └── vivado/                   # Vivado 工程文件
├── experiment_1_divider/         # 分频独立工程
├── dds_display/                  # 动态显示与 DDS 独立工程
├── experiment_4_frequency_meter/ # 测频独立工程
├── experiment_5a_shift_500khz/  # 下移 500 kHz 独立工程
├── experiment_5b_shift_100khz/  # 下移 100 kHz 独立工程
├── project_1/                    # Verilog 练习工程
└── EGo1.xdc                     # EGO1 引脚约束参考
```

## 运行综合工程

1. 在 Vivado 中打开 [combined_experiments.xpr](combined_experiments/vivado/combined_experiments.xpr)。工程记录了原环境的路径；若移动到其他电脑后文件路径失效，可在 `combined_experiments` 目录执行 `vivado -mode batch -source scripts/create_project.tcl` 重新创建工程。
2. 执行综合、实现并生成 bitstream，再下载到开发板。
3. 接好 AD/DA 模块和测试仪器，按下表设置 DIP。DDS 使用 SW7～SW0 设置频率控制字。

| DIP7→DIP0 | 功能 |
| --- | --- |
| `0000 0000` | 数码管显示检查 |
| `0000 0001` | 实验 1：分频 |
| `0000 0010` | 实验 2：动态显示 |
| `0000 0100` | 实验 3：DDS |
| `0000 1000` | 实验 4：频率测量 |
| `0001 0000` | 实验 5A：下移 500 kHz |
| `0001 0001` | 实验 5B：下移 100 kHz |

综合工程的仿真脚本位于 `combined_experiments/scripts/simulate.ps1`，运行时需要将 `-VivadoBin` 指向本机 Vivado 的 `bin` 目录。约束文件 [ego1_combined.xdc](combined_experiments/constraints/ego1_combined.xdc) 包含综合工程的引脚和时序约束。
