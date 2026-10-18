---
project: Trinity Dynamic Channel Pipe
type: Documentation
file: README.md
tags:
  - Open_Source
  - Hardware_Emulation
  - Verilog_RTL
  - PAM-3
  - Verification_Stand
---

# Trinity Dynamic Channel Pipe Architecture
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23448044.svg)](https://doi.org)
### Open-Source Hardware Verification & Validation Stand: Real-Time Ternary Framing via Physical PAM-3 Logic

This repository contains the official C++ hardware emulation model and the **synthesizable Verilog RTL implementation** for the **Trinity Pipe** baseline transport architecture. It serves as a hardware-proven proof-of-concept for shifting streaming framing logic from energy-intensive software protocols directly onto physical semiconductor hardware.

The system processes data transmission through a ternary medium utilizing a **symmetric PAM-3 alphabet (\(T \in \{-1, 0, +1\}\))**. Inside the digital silicon domain (FPGA/ASIC), these physical states are mapped onto a standard 2-bit wide bus input `trit_in[1:0]`:
* **`2'b00` (TRIT_0):** Represents the physical level **`0`**. Used to accumulate binary patterns.
* **`2'b01` (TRIT_1):** Represents the physical level **`1`**. Used to accumulate binary patterns.
* **`2'b10` (TRIT_Z):** Represents the physical level **`-1`**. Acts as a strict, atomic, line-level frame delimiter.

---

## Technical Overview & Core Architecture

The Trinity Pipe architecture completely eliminates standard data link and network layer framing overheads (packet headers, start/stop sequences, and boundary escape characters):

1. **Strict Line-Level Framing (`TRIT_Z`):** Data block boundaries are enforced directly in physical wires. Every binary nibble mapped into the channel is strictly terminated by the `TRIT_Z` state (Z = -1 on the physical line, coded as `2'b10` in RTL). Upon detecting the arrival of a Z-pulse, the receiver hardware finalizes the sequence, evaluates its length, outputs the decoded value, and instantly resets its bit-counters with absolute zero look-ahead latency.
2. **Combinatorial Prefix-Free Token Mapping (`ENCODER_LUT`):** The input binary stream is processed as 4-bit nibbles (range `0x0` to `0xF`). The hardware maps them onto the ternary alphabet (`TRIT_0`, `TRIT_1`, `TRIT_Z`) using a deterministic lookup table:
   * **1-Trit Sequence (Fastest):** The value `0` maps directly to `{TRIT_Z}`, consuming exactly 1 clock cycle.
   * **2-Trit to 4-Trit Sequences:** Values `1` to `14` are translated as pure binary configurations cut off by a mandatory terminal Z-token (e.g., `0Z`, `1Z`, `00Z`, ..., `111Z`).
   * **5-Trit Sequence (Worst-Case):** The lowest frequency value `15` is translated as `0000Z`, causing a brief 5-tact dilation. 
   
   The statistical distribution ensures that high-entropy data inherently achieves compaction because short codes (`0`, `1`, `2`) balance out the worst-case extension.

3. **Stream Determinism:** The decoding engine is stateless between tokens. It scans incoming trits sequentially until it strikes a `TRIT_Z` marker. The numeric value is recovered based entirely on the bit pattern accumulated before the boundary pulse. This enables optimal ASIC/FPGA integration, requiring only a basic 3-bit accumulator and an edge-triggered Z-detector.
4. **Fault Isolation & Watchdog Protection:** Because the `TRIT_Z` marker acts as a physical wall, line noise or transient bit flips inside the channel are strictly confined to the current active nibble. The Verilog RTL implementation features an embedded hardware watchdog. If a line glitch or channel corruption causes the incoming sequence to exceed 4 bits without striking a terminal Z-pulse, the core instantly raises a `frame_error` flag, flushes internal registers, and safely awaits the next valid `TRIT_Z` packet marker to force immediate resynchronization.

---

## System Efficiency Constants (High-Entropy Profile)

When validated against maximum-entropy blocks where classical static compression tools reach their absolute mathematical limits (highly compressed archives, encrypted payloads, dense media streams), the Trinity Pipe architecture maintains rock-solid physical baselines:
* **`Dynamic Data Reduction` (Time/Tact Saving):** ~15.6% physical channel compaction inherently achieved via asymmetric symbol distribution.
* **`Virtual Throughput Gain` (Effective Bandwidth Boost):** +18.5% effective bandwidth expansion across the physical conductor relative to the base source clock frequency.
* **`Dynamic Energy Conservation`:** By reducing the average number of physical line transitions per transmitted nibble below the standard binary baseline (4 bits = 4 transitions), the architecture significantly minimizes the dynamic switching capacitance (\(C_{pd}\)), lowering thermal dissipation and line drive power.

---

## Verification & Hardware Validation Stand

The repository provides a dual-layer verification ecosystem to validate the protocol mathematically and structurally.

### 1. C++ High-Level Emulation Model
Used to evaluate data compaction ratios over large raw binary payloads.
* **Compilation:** Requires a standard C++17 compliant compiler.
  ```bash
  mkdir build && cd build
  cmake -DCMAKE_BUILD_TYPE=Release ..
  make
  ```
* **Execution:** Place any raw binary file into the root execution directory and rename it explicitly to **`test.bin`**. The stand executes 5 consecutive validation passes over the payload to record processing speeds.

### 2. Verilog RTL & Constrained Random Testbench
The core digital logic is implemented in synthesizable Verilog-2001 (`trinity_pipe_decoder.v`), making it ready for FPGA deployment or ASIC synthesis. 
To guarantee absolute robustness, the repository includes an automated **Constrained Random Verification (CRV)** stand (`tb_trinity_random.v`) featuring an online scoreboard checker. The testbench continuously streams high-density random payloads packed back-to-back with zero bus-idling latency to match the idealized C++ streaming conditions.
* **Simulation via Icarus Verilog:**
  ```bash
  iverilog -o trinity_sim tb_trinity_random.v trinity_pipe_decoder.v
  vvp trinity_sim
  ```
The RTL core achieves **100% bit-accurate decoding** under continuous random stress-testing, proving perfect algorithmic alignment between the high-level C++ model and hardware-level silicon primitives.

---
<img width="1493" height="831" alt="trinity_random_dump" src="https://github.com/user-attachments/assets/bf8a1350-4743-4fa1-beaa-6fb7f56614b0" />

## ⚠️ Legal Status & Commercial Restrictions (Dual-Licensing)

The source code in this repository is published under the **GNU GPLv3** license and is open exclusively for non-commercial use, academic research, and public independent auditing.

Integrating, copying, or implementing the core logical principles of this algorithm into closed commercial or proprietary products (including microprocessor architectures, memory controllers, networking hardware firmware, DBMS, and HFT platforms) is **strictly prohibited** under the GPLv3 terms. Commercial deployment of the Trinity Pipe technology is permissible **solely upon executing a Private Commercial Agreement** with the copyright holder.
