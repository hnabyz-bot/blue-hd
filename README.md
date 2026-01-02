# Blue 100um FPGA Development

Xilinx Artix-7 FPGA 개발 프로젝트

## 📋 Hardware Specification
- **FPGA**: Xilinx Artix-7 XC7A35T-FGG484-1
- **Board**: Blue 100um Custom Board
- **Tool**: Xilinx Vivado

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/hnabyz-bot/blue-hd.git
cd blue-hd
```

### 2. Create Vivado Project
```bash
# Method 1: GUI mode
vivado -mode gui -source create_project.tcl

# Method 2: Batch mode (no GUI)
vivado -mode batch -source create_project.tcl
```

프로젝트는 `./build/blue_hd.xpr`에 생성됩니다.

### 3. Open & Build
```bash
# 프로젝트 열기
vivado ./build/blue_hd.xpr

# 또는 Vivado GUI에서 직접 열기
```

## 📁 Directory Structure
```
blue-hd/
├── source/
│   ├── hdl/          # Verilog/VHDL 소스 파일
│   ├── ip/           # Xilinx IP 코어
│   └── constrs/      # 제약 조건 파일 (XDC)
├── simulation/
│   └── tb_src/       # 테스트벤치
├── build/            # Vivado 프로젝트 (gitignore)
├── output/           # 시뮬레이션 출력 (gitignore)
├── reports/          # 합성/구현 리포트 (gitignore)
├── doc/              # 문서
└── create_project.tcl # 프로젝트 생성 스크립트
```

## 📝 Development Notes
- 중요한 제약 파일: `source/constrs/cyan_hd_top.xdc`
- HDL 파일은 `source/hdl/`에 추가
- 시뮬레이션은 `simulation/tb_src/`에 추가

## 🔧 Workflow
1. HDL 소스 작성 → `source/hdl/`
2. 제약 조건 수정 → `source/constrs/cyan_hd_top.xdc`
3. Vivado에서 Synthesis → Implementation → Generate Bitstream
4. 결과물: `build/blue_hd.runs/impl_1/*.bit`

## 📚 Documentation
상세 문서는 [doc/](doc/) 폴더 참조

