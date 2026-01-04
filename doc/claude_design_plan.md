# Cyan HD FPGA 설계 계획서

**프로젝트**: Blue 100um FPGA Development
**타겟**: Xilinx Artix-7 XC7A35T-FGG484-1
**작성일**: 2026-01-04
**버전**: v1.0

---

## 📋 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [현재 상태](#2-현재-상태)
3. [설계 목표](#3-설계-목표)
4. [모듈 구조](#4-모듈-구조)
5. [단계별 구현 계획](#5-단계별-구현-계획)
6. [리소스 예산](#6-리소스-예산)
7. [타임라인](#7-타임라인)
8. [검증 전략](#8-검증-전략)
9. [위험 요소 및 대응](#9-위험-요소-및-대응)

---

## 1. 프로젝트 개요

### 1.1 시스템 목적
14채널 LVDS ADC 기반 이미지 센서 ROIC 제어 및 데이터 수집 시스템

### 1.2 주요 기능
- **14채널 LVDS ADC 인터페이스**: ROIC 데이터 수신 (12bit × 14ch)
- **MIPI CSI-2 출력**: 4-lane 고속 데이터 전송
- **SPI Slave**: CPU 제어 인터페이스
- **Gate Driver**: 행/열 스캔 타이밍 생성
- **I2C Master**: 외부 센서 설정

### 1.3 성능 요구사항
| 항목 | 사양 |
|------|------|
| ADC 샘플링 레이트 | 최대 100 MHz |
| LVDS 데이터 레이트 | 최대 1.25 Gbps/채널 |
| 프레임 레이트 | 30-60 fps |
| 해상도 | 1024 × 1024 (예상) |
| 클럭 정확도 | ±50 ppm |
| 전력 소비 | < 2W |

---

## 2. 현재 상태

### 2.1 완료된 항목 ✅
```
✅ doc/claude-agent-fpga.md (3,372줄)
   - FPGA 설계 가이드 완성
   - 모듈 템플릿 4개 제공
   - 검증 전략 수립

✅ source/constrs/cyan_hd_top.xdc (306줄)
   - 106개 핀 정의 완료
   - 14채널 LVDS 제약 조건
   - MIPI CSI-2 제약 조건

✅ source/hdl/cyan_hd_top.sv (587줄)
   - 최상위 모듈 완성
   - 인터페이스 정의 완료
   - 클럭/리셋 구조 확정
```

### 2.2 미완성 항목 ⬜
```
⬜ 하위 모듈 6개 (Placeholder 상태)
⬜ 테스트벤치 0개
⬜ IP 코어 미생성 (Clock Wizard)
⬜ 합성/구현 미실행
⬜ 타이밍 검증 미완료
```

---

## 3. 설계 목표

### 3.1 기술 목표
1. **타이밍 클로저**: WNS ≥ 0ns (모든 클럭 도메인)
2. **리소스 효율**: LUT < 70%, BRAM < 80%, DSP < 70%
3. **CDC 안전성**: 모든 클럭 도메인 크로싱에 CDC 프리미티브 사용
4. **검증 완성도**: 코드 커버리지 ≥ 95%
5. **모듈화**: 재사용 가능한 독립 모듈 설계

### 3.2 비기술 목표
1. **문서화**: 모든 모듈에 버전 헤더 포함
2. **재현성**: TCL 스크립트로 프로젝트 자동 생성
3. **유지보수성**: 명확한 네이밍 규칙 준수
4. **확장성**: MIPI, DDR3 등 추가 인터페이스 준비

---

## 4. 모듈 구조

### 4.1 계층 구조
```
cyan_hd_top (최상위)
├── clk_wiz_0 (Xilinx IP)
│   └── MMCM: 50MHz → 100/200/25 MHz
│
├── reset_sync (리셋 동기화)
│   └── 2-FF 동기화
│
├── lvds_adc_interface × 14 (ADC 수신기)
│   ├── IBUFDS (차동 입력 버퍼)
│   ├── IDELAYE2 (입력 지연 조정)
│   ├── ISERDESE2 (7:1 디시리얼라이저)
│   └── 클럭 복원 (DCLK 기반)
│
├── spi_slave_controller (CPU 제어)
│   ├── SPI 상태 머신
│   ├── 32bit 레지스터 맵 (8개)
│   └── MISO 출력 로직
│
├── gate_driver_controller (타이밍 생성)
│   ├── FSM (IDLE/INIT/RUN)
│   ├── STV 펄스 생성기
│   ├── CPV 펄스 생성기
│   └── 라인 카운터
│
├── data_processing_pipeline (데이터 처리)
│   ├── 14채널 병합
│   ├── 평균/필터링
│   ├── 라인 버퍼 (BRAM)
│   └── 프레임 버퍼 관리
│
├── i2c_master_controller (I2C 통신)
│   ├── 비트뱅잉 로직
│   ├── START/STOP 생성
│   └── ACK/NACK 처리
│
└── roic_spi_master (ROIC 설정)
    ├── SPI 마스터 FSM
    └── 설정 데이터 전송
```

### 4.2 모듈별 상세 스펙

#### 📌 Module 1: `lvds_adc_interface.sv`
**목적**: 단일 채널 LVDS ADC 데이터 수신

| 항목 | 사양 |
|------|------|
| 입력 | DCLK_P/N, FCLK_P/N, DOUT_P/N (차동) |
| 출력 | 12bit 병렬 데이터 + valid 신호 |
| 클럭 | 200 MHz (ISERDES), 100 MHz (병렬 출력) |
| 기능 | 7:1 디시리얼라이제이션, 클럭 복원 |
| 리소스 | ~200 LUT, ~150 FF per channel |
| 참조 | [claude-agent-fpga.md Section 26.2](claude-agent-fpga.md#262) |

**주요 로직**:
```verilog
IBUFDS → IDELAYE2 → ISERDESE2 (7:1) → 비트 정렬 → 12bit 병렬
```

---

#### 📌 Module 2: `spi_slave_controller.sv`
**목적**: CPU와 FPGA 간 제어 인터페이스

| 항목 | 사양 |
|------|------|
| 프로토콜 | SPI Mode 0 (CPOL=0, CPHA=0) |
| 데이터 폭 | 32bit |
| 레지스터 | 8개 (0x00-0x1C) |
| 속도 | 최대 25 MHz SPI 클럭 |
| 리소스 | ~500 LUT, ~300 FF |
| 참조 | [claude-agent-fpga.md Section 25.5.2](claude-agent-fpga.md#2552) |

**레지스터 맵**:
```
0x00: CTRL_REG0    [RW] - 전역 제어 (enable, reset, mode)
0x04: CTRL_REG1    [RW] - I2C/ROIC 설정
0x08: STATUS_REG0  [RO] - ADC 상태 (14ch valid flags)
0x0C: STATUS_REG1  [RO] - 클럭 lock, 에러 플래그
0x10: ADC_DATA_0   [RO] - ADC Ch0 최신 데이터
0x14: ADC_DATA_1   [RO] - ADC Ch1 최신 데이터
0x18: FRAME_COUNT  [RO] - 프레임 카운터
0x1C: ERROR_LOG    [RO] - 에러 로그
```

---

#### 📌 Module 3: `gate_driver_controller.sv`
**목적**: ROIC 행/열 스캔 타이밍 생성

| 항목 | 사양 |
|------|------|
| 클럭 | 25 MHz |
| 출력 | STV, CPV, OE 신호 |
| 타이밍 | 프로그래머블 (SPI 설정 가능) |
| 리소스 | ~300 LUT, ~200 FF |
| 참조 | [claude-agent-fpga.md Section 25.5.4](claude-agent-fpga.md#2554) |

**타이밍 파라미터** (예시):
```
STV_WIDTH   = 4us     (100 cycles @ 25MHz)
CPV_PERIOD  = 25us    (625 cycles, 40 kHz)
LINE_COUNT  = 1024    (1024 lines per frame)
FRAME_RATE  = 30 fps
```

---

#### 📌 Module 4: `data_processing_pipeline.sv`
**목적**: 14채널 ADC 데이터 처리 및 이미지 재구성

| 항목 | 사양 |
|------|------|
| 입력 | 14ch × 12bit ADC 데이터 |
| 출력 | 32bit 처리된 픽셀 데이터 |
| 기능 | 평균, 필터링, 라인 버퍼링 |
| 리소스 | ~4,000 LUT, ~3,000 FF, 20 BRAM |
| 참조 | 사용자 정의 알고리즘 |

**처리 파이프라인**:
```
14ch ADC → 채널 병합 → 평균 → FIR 필터 → 라인 버퍼 (BRAM) → 출력
```

---

#### 📌 Module 5: `i2c_master_controller.sv`
**목적**: 외부 센서 I2C 통신

| 항목 | 사양 |
|------|------|
| 속도 | 100 kHz (표준 모드) |
| 방식 | 비트뱅잉 (GPIO 기반) |
| 기능 | 7bit 주소, 8bit 데이터 |
| 리소스 | ~200 LUT, ~150 FF |
| 참조 | 표준 I2C 프로토콜 |

---

#### 📌 Module 6: `roic_spi_master.sv`
**목적**: ROIC 설정 레지스터 제어

| 항목 | 사양 |
|------|------|
| 프로토콜 | SPI Mode 0 |
| 속도 | 10 MHz |
| 데이터 | 16bit 명령 + 데이터 |
| 리소스 | ~200 LUT, ~100 FF |
| 참조 | ROIC 데이터시트 |

---

## 5. 단계별 구현 계획

### Phase 1: 핵심 인프라 구축 (우선순위: P0)
**목표**: 최소 동작 가능한 시스템 구현

#### Step 1.1: Clock Wizard IP 생성
**소요 시간**: 10분
**담당**: Vivado IP Catalog

```tcl
# TCL 스크립트
create_ip -name clk_wiz -vendor xilinx.com -library ip \
  -module_name clk_wiz_0

set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {50.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {200.000} \
  CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {25.000} \
  CONFIG.USE_LOCKED {true} \
  CONFIG.USE_RESET {true} \
  CONFIG.RESET_TYPE {ACTIVE_LOW} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]
```

**산출물**: `source/ip/clk_wiz_0/`

---

#### Step 1.2: LVDS ADC Interface 구현
**소요 시간**: 2-3시간
**난이도**: ⭐⭐⭐ 높음

**구현 내용**:
1. IBUFDS 인스턴스 (차동 입력 버퍼)
2. IDELAYE2 (입력 지연 조정, 타이밍 맞춤용)
3. ISERDESE2 (7:1 디시리얼라이저)
4. 비트 정렬 로직
5. 클럭 도메인 크로싱 (200MHz → 100MHz)

**검증 방법**:
- 테스트벤치로 LVDS 시뮬레이션
- 실제 ROIC 없이 테스트 패턴 생성기 사용

**산출물**:
- `source/hdl/lvds_adc_interface.sv` (~250줄)
- `simulation/tb_src/tb_lvds_adc_interface.sv` (~200줄)

**위험 요소**:
- ⚠️ ISERDES 타이밍 설정 복잡
- ⚠️ 비트 정렬 알고리즘 검증 필요

---

#### Step 1.3: SPI Slave Controller 구현
**소요 시간**: 1-2시간
**난이도**: ⭐⭐ 중간

**구현 내용**:
1. SPI 상태 머신 (IDLE/ADDR/DATA/DONE)
2. 8개 32bit 레지스터
3. MISO 출력 로직 (MSB first)
4. 클럭 도메인 크로싱 (SCLK → 100MHz)

**레지스터 동작**:
```verilog
// 쓰기 예시
CPU: SSB=0, SCLK=toggle, MOSI=[addr:8][data:24]
FPGA: ctrl_reg0 <= mosi_data

// 읽기 예시
CPU: SSB=0, SCLK=toggle, MOSI=[addr:8]
FPGA: MISO <= status_reg0[31:0] (MSB first)
```

**산출물**:
- `source/hdl/spi_slave_controller.sv` (~300줄)
- `simulation/tb_src/tb_spi_slave.sv` (~250줄)

---

#### Step 1.4: Gate Driver Controller 구현
**소요 시간**: 1시간
**난이도**: ⭐⭐ 중간

**구현 내용**:
1. FSM (IDLE/WAIT_TRIGGER/ACTIVE)
2. STV 펄스 생성기
3. CPV 펄스 생성기 (프로그래머블 주기)
4. 라인 카운터 (0-1023)
5. 프레임 완료 인터럽트

**타이밍 다이어그램**:
```
STV:  ▁▁▁▁▁▔▔▔▔▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁ (4us 펄스)
CPV:  ▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔▁▔ (25us 주기, 40kHz)
OE:   ▁▁▁▁▁▁▁▁▁▁▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔ (스캔 중 High)
```

**산출물**:
- `source/hdl/gate_driver_controller.sv` (~200줄)
- `simulation/tb_src/tb_gate_driver.sv` (~150줄)

---

### Phase 2: 데이터 처리 파이프라인 (우선순위: P1)
**목표**: 14채널 ADC 데이터 → 이미지 데이터 변환

#### Step 2.1: 기본 데이터 병합
**소요 시간**: 1시간

**구현 내용**:
```verilog
// 14채널 → 1개 픽셀 (평균값)
pixel_data = (adc_data[0] + adc_data[1] + ... + adc_data[13]) / 14;
```

#### Step 2.2: 라인 버퍼 추가
**소요 시간**: 1시간

**구현 내용**:
- BRAM 기반 라인 버퍼 (1024 × 32bit)
- Ping-pong 버퍼 (2개 교대 사용)

#### Step 2.3: FIR 필터 추가 (선택)
**소요 시간**: 2시간

**구현 내용**:
- 3탭 또는 5탭 FIR 필터
- DSP48 슬라이스 사용

**산출물**:
- `source/hdl/data_processing_pipeline.sv` (~400줄)
- `simulation/tb_src/tb_data_pipeline.sv` (~200줄)

---

### Phase 3: 추가 인터페이스 (우선순위: P2)

#### Step 3.1: I2C Master 구현
**소요 시간**: 1시간
**난이도**: ⭐ 낮음

**산출물**:
- `source/hdl/i2c_master_controller.sv` (~200줄)

#### Step 3.2: ROIC SPI Master 구현
**소요 시간**: 1시간
**난이도**: ⭐ 낮음

**산출물**:
- `source/hdl/roic_spi_master.sv` (~150줄)

---

### Phase 4: 통합 및 검증 (우선순위: P0)

#### Step 4.1: 합성 (Synthesis)
```tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
report_utilization -file reports/utilization_post_synth.rpt
```

**예상 리소스 사용량**:
| 항목 | 사용 | 총량 | 비율 |
|------|------|------|------|
| LUT | 8,000 | 20,800 | 38% |
| FF | 5,800 | 41,600 | 14% |
| BRAM | 20 | 50 | 40% |
| DSP | 16 | 90 | 18% |

---

#### Step 4.2: 구현 (Implementation)
```tcl
launch_runs impl_1
wait_on_run impl_1
open_run impl_1
report_timing_summary -file reports/timing_summary.rpt
```

**타이밍 목표**:
- WNS (Worst Negative Slack) ≥ 0ns
- TNS (Total Negative Slack) = 0ns
- WHS (Worst Hold Slack) ≥ 0ns

---

#### Step 4.3: 비트스트림 생성
```tcl
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

**산출물**:
- `build/blue_hd.runs/impl_1/cyan_hd_top.bit`

---

## 6. 리소스 예산

### 6.1 모듈별 리소스 할당

| 모듈 | LUT | FF | BRAM | DSP | 우선순위 |
|------|-----|----|----|-----|---------|
| clk_wiz_0 (IP) | 200 | 50 | 0 | 0 | P0 |
| reset_sync | 10 | 10 | 0 | 0 | P0 |
| lvds_adc_interface ×14 | 2,800 | 2,100 | 0 | 0 | P0 |
| spi_slave_controller | 500 | 300 | 0 | 0 | P0 |
| gate_driver_controller | 300 | 200 | 0 | 0 | P1 |
| data_processing_pipeline | 4,000 | 3,000 | 20 | 16 | P1 |
| i2c_master_controller | 200 | 150 | 0 | 0 | P2 |
| roic_spi_master | 200 | 100 | 0 | 0 | P2 |
| **합계** | **8,210** | **5,910** | **20** | **16** | - |
| **예산 대비** | **39%** | **14%** | **40%** | **18%** | - |

✅ **모든 리소스 예산 내 수용 가능**

### 6.2 예약 리소스
- 20% LUT 예약 (라우팅, 최적화)
- 10 BRAM 예약 (미래 확장)
- 20 DSP 예약 (추가 필터)

---

## 7. 타임라인

### 7.1 전체 일정
```
Week 1 (Day 1-2): Phase 1 구현
├── Day 1: Clock IP + LVDS ADC
└── Day 2: SPI Slave + Gate Driver

Week 1 (Day 3-4): Phase 2 구현
├── Day 3: Data Processing Pipeline
└── Day 4: 통합 테스트

Week 2 (Day 5-7): Phase 3-4 구현
├── Day 5: I2C + ROIC SPI
├── Day 6: 합성 + 구현
└── Day 7: 타이밍 최적화 + 비트스트림
```

### 7.2 마일스톤
- ✅ **M0**: 계획서 완성 (현재)
- 🔲 **M1**: Phase 1 완료 (Day 2)
- 🔲 **M2**: Phase 2 완료 (Day 4)
- 🔲 **M3**: 합성 성공 (Day 6)
- 🔲 **M4**: 타이밍 클로저 (Day 7)

---

## 8. 검증 전략

### 8.1 모듈별 검증 레벨

#### Level 1: 단위 테스트 (Unit Test)
각 모듈에 전용 테스트벤치 작성

**커버리지 목표**:
- Statement Coverage: 100%
- Branch Coverage: 100%
- Toggle Coverage: >95%

**테스트 항목 예시** (`lvds_adc_interface`):
```
✓ LVDS 차동 신호 수신
✓ 7:1 디시리얼라이제이션 정확도
✓ 클럭 복원 안정성
✓ FCLK 동기화
✓ 리셋 동작
```

---

#### Level 2: 통합 테스트 (Integration Test)
모듈 간 인터페이스 검증

**테스트 항목**:
```
✓ LVDS ADC → Data Pipeline 연결
✓ SPI Slave → 제어 레지스터 동작
✓ Gate Driver → ROIC 타이밍
✓ Clock Domain Crossing 안전성
```

---

#### Level 3: 시스템 테스트 (System Test)
전체 시스템 end-to-end 검증

**테스트 시나리오**:
1. 파워온 → 클럭 lock → 리셋 해제
2. SPI로 설정 레지스터 쓰기
3. Gate Driver 시작
4. 14채널 ADC 데이터 수집
5. Data Pipeline 처리
6. 프레임 완료 인터럽트

---

### 8.2 시뮬레이션 도구

**Vivado Simulator (XSIM)**:
```bash
# 컴파일
xvlog source/hdl/*.sv
xvlog simulation/tb_src/*.sv

# 시뮬레이션
xelab -debug typical tb_cyan_hd_top
xsim tb_cyan_hd_top -runall
```

**ModelSim/Questa** (선택):
```bash
vlog source/hdl/*.sv
vsim -voptargs=+acc work.tb_cyan_hd_top
run -all
```

---

### 8.3 하드웨어 검증

#### Step 1: JTAG 프로그래밍
```bash
# Vivado Hardware Manager
open_hw_manager
connect_hw_server
open_hw_target
program_hw_devices [get_hw_devices xc7a35t_0]
```

#### Step 2: ILA (Integrated Logic Analyzer) 삽입
```verilog
// 디버그 신호 마킹
(* mark_debug = "true" *) wire [11:0] adc_data_ch0;
(* mark_debug = "true" *) wire adc_valid_ch0;
```

#### Step 3: 실시간 관찰
- ILA로 ADC 데이터 파형 확인
- VIO로 제어 레지스터 수동 조작
- 프레임 레이트 측정

---

## 9. 위험 요소 및 대응

### 9.1 기술적 위험

#### ⚠️ Risk 1: LVDS 타이밍 불안정
**발생 확률**: 중간 (40%)
**영향**: 높음 (ADC 데이터 손실)

**대응 방안**:
1. IDELAYE2로 지연 조정 (0-31 탭)
2. 비트슬립 알고리즘 추가
3. 실제 ROIC 파형 캡처 후 조정

---

#### ⚠️ Risk 2: 타이밍 클로저 실패
**발생 확률**: 낮음 (20%)
**영향**: 높음 (동작 불가)

**대응 방안**:
1. 파이프라인 단계 추가
2. 클럭 주파수 낮춤 (200MHz → 150MHz)
3. PBLOCK으로 플로어플래닝

---

#### ⚠️ Risk 3: 리소스 초과
**발생 확률**: 낮음 (10%)
**영향**: 중간 (기능 축소)

**대응 방안**:
1. Data Pipeline 간소화 (평균만 수행)
2. DSP 대신 LUT 사용
3. BRAM 크기 축소

---

### 9.2 일정 위험

#### ⚠️ Risk 4: 구현 지연
**발생 확률**: 중간 (30%)

**대응 방안**:
- Phase 2 (Data Pipeline) 선택적 구현
- Phase 3 (I2C/ROIC SPI) 후순위로 연기
- 최소 동작 버전 우선 완성 (Phase 1만)

---

## 10. 부록

### 10.1 참고 문서
1. [claude-agent-fpga.md](claude-agent-fpga.md) - FPGA 설계 가이드
2. [cyan_hd_top.xdc](../source/constrs/cyan_hd_top.xdc) - 핀 제약 조건
3. UG471 - 7 Series SelectIO User Guide
4. UG949 - UltraFast Design Methodology Guide

### 10.2 용어 정의
- **ROIC**: Readout Integrated Circuit (읽기 전용 집적회로)
- **LVDS**: Low-Voltage Differential Signaling
- **ISERDES**: Input Serializer/Deserializer
- **CDC**: Clock Domain Crossing
- **WNS**: Worst Negative Slack (최악 음수 여유)

### 10.3 버전 이력
| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|-----------|--------|
| v1.0 | 2026-01-04 | 초안 작성 | Claude AI |

---

**문서 끝**
