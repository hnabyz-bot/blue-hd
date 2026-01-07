# How to Run Simulation

## ⚠️ Important Note

**Batch mode simulation currently fails** with "Broken pipe" error.
**Please use Vivado GUI** for running simulation.

## ✅ Recommended Method: Vivado GUI

### Step 1: Open Project
```
1. Launch Vivado 2024.2
2. File → Open Project
3. Navigate to: vivado_project/cyan_hd.xpr
4. Click "OK"
```

### Step 2: Verify Simulation Files
```
In Sources window:
├─ Simulation Sources
│  └─ sim_1
│     └─ tb_afe2256_spi.sv (Top module)
└─ Design Sources
   ├─ afe2256_spi_pkg.sv
   └─ afe2256_spi_controller.sv
```

If `tb_afe2256_spi.sv` is NOT visible, run:
```tcl
# In Vivado TCL Console:
source scripts/setup_simulation.tcl
```

### Step 3: Run Behavioral Simulation
```
1. Flow Navigator (left panel)
2. Click on SIMULATION section
3. Click "Run Simulation" dropdown
4. Select "Run Behavioral Simulation"
5. Wait for compilation (1-2 minutes)
```

### Step 4: Run Simulation
Once the simulation window opens:

**Option A: Run All (Automatic)**
```tcl
# In TCL Console at bottom:
run all
```

**Option B: Run Specific Time**
```tcl
# Run for 100 microseconds:
run 100us
```

### Step 5: View Results

**Console Output** (TCL Console):
```
========================================
AFE2256 SPI Controller Testbench
========================================

[TEST 1] Single Register Write
  ✓ PASS: Captured data = 0x10ABCD

[TEST 2] Reset Register Write
  ✓ PASS: Captured data = 0x000001

[TEST 3] TRIM_LOAD Register Write
  ✓ PASS: Captured data = 0x300002

[TEST 4] Multiple Consecutive Writes
  Write 1: Addr=0x10, Data=0x1000
    ✓ PASS: Captured = 0x101000
  Write 2: Addr=0x11, Data=0x1001
    ✓ PASS: Captured = 0x111001
  [... 3 more writes ...]

[TEST 5] SPI Timing Verification
  Measured SCK period: 100.0 ns (Expected: 100 ns)
  ✓ PASS: SCK frequency within tolerance

[TEST 6] Full Initialization Sequence (10 registers)
  Init[ 0]: Addr=0x00, Data=0x0001, Delay=100 us
    ✓ Verified: 0x000001
  Init[ 1]: Addr=0x30, Data=0x0002, Delay=100 us
    ✓ Verified: 0x300002
  [... 8 more registers ...]

========================================
Test Summary
========================================
Total Tests:  6
Passed:       6
Failed:       0
Status:       ✓ ALL TESTS PASSED
========================================
```

**Waveform Viewer**:
```
Key signals to observe:
- clk                  : 100 MHz system clock
- rst_n                : Active-low reset
- spi_sck              : 10 MHz SPI clock
- spi_sen_n[0]         : SPI chip select (active low)
- spi_sdi              : SPI data out (24-bit)
- busy/done            : Transaction status
- captured_data[23:0]  : Captured SPI data
```

### Step 6: View Waveforms (Optional)
```
1. In Simulation window, click "Zoom Fit" toolbar button
2. Find signals in "Scope" window:
   - tb_afe2256_spi
     - dut (afe2256_spi_controller instance)
3. Add signals to waveform:
   - Right-click signal → Add to Wave Window
```

## 🔧 Troubleshooting

### Issue 1: "Testbench not found in simulation sources"

**Solution:**
```tcl
# In Vivado TCL Console:
cd D:/workspace/github-space/blue-hd
source scripts/setup_simulation.tcl
```

### Issue 2: "Syntax errors in testbench"

**Solution:**
```bash
# Make sure you have the latest version:
git pull
# or check that tb_afe2256_spi.sv has 'automatic' keywords
```

### Issue 3: "Simulation runs but no output"

**Check:**
- TCL Console (View → Tcl Console)
- Simulation runtime (should run at least 100us)

### Issue 4: "Waveform window is empty"

**Solution:**
```tcl
# In TCL Console during simulation:
log_wave -recursive *
restart
run 100us
```

## 📊 Expected Test Coverage

| Test Case | Purpose | Pass Criteria |
|-----------|---------|---------------|
| Test 1 | Single Register Write | Data captured correctly |
| Test 2 | Reset Register | RESET command sent |
| Test 3 | TRIM_LOAD Register | Calibration command sent |
| Test 4 | Multiple Writes (5×) | All 5 transactions pass |
| Test 5 | SPI Timing | 10 MHz ±10% frequency |
| Test 6 | Init Sequence (10 regs) | All registers verified |

**Total:** 6 test cases, all must PASS

## 🚫 Known Issues

### Batch Mode Fails
```bash
# ❌ This DOES NOT work:
vivado -mode batch -source scripts/run_sim.tcl

# ERROR: Spawn failed: Broken pipe
```

**Root Cause:** xvlog compilation fails in batch mode (environment issue)

**Workaround:** Use Vivado GUI as described above

## 📝 Files Involved

```
simulation/
├── tb_src/
│   └── tb_afe2256_spi.sv          # Main testbench (385 lines)
├── README.md                       # Simulation overview
├── SIMULATION_VERIFICATION_REPORT.md  # Detailed report
├── HOW_TO_RUN_SIMULATION.md        # This file
└── verify_testbench.py             # Static analysis tool

source/hdl/afe2256/
├── afe2256_spi_pkg.sv              # SPI package definitions
└── afe2256_spi_controller.sv       # DUT (Design Under Test)

scripts/
├── setup_simulation.tcl            # Add TB to project
└── run_sim.tcl                     # Batch mode script (broken)

vivado_project/
└── cyan_hd.xpr                     # Vivado project file
```

## ✅ Verification Checklist

Before running simulation:
- [ ] Vivado project opens without errors
- [ ] tb_afe2256_spi.sv visible in sim_1 fileset
- [ ] Top module set to `tb_afe2256_spi`
- [ ] afe2256_spi_pkg.sv and afe2256_spi_controller.sv compiled

After running simulation:
- [ ] All 6 tests execute
- [ ] All 6 tests PASS
- [ ] Test summary shows 0 failures
- [ ] SPI timing within tolerance (±10%)
- [ ] No syntax or runtime errors

---

**Last Updated:** 2026-01-07
**Status:** Testbench ready, GUI-only execution
**Contact:** See SIMULATION_VERIFICATION_REPORT.md for details
