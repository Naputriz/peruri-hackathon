# GarbleChip: Area-Efficient Sequential Garbled Circuit Hardware Accelerator Based on a SHA-256 Core for Privacy-Preserving Computation on the DE10-Nano SoC

[![Hackathon Chip 2026](https://img.shields.io/badge/Hackathon-Chip%202026%20(Peruri)-blue.svg)](https://chip.peruri.co.id)
[![Target Platform](https://img.shields.io/badge/Platform-Terasic%20DE10--Nano%20(Cyclone%20V)-orange.svg)](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1046)
[![Verilog Standard](https://img.shields.io/badge/Verilog-Universal%201995%2F2001%2F2005-green.svg)]()
[![Status](https://img.shields.io/badge/Verification-100%25%20Passed-brightgreen.svg)]()

> **Kategori Lomba:** Track 02 — Hardware Cryptography Accelerator  
> **Platform Target:** Terasic DE10-Nano (Intel Cyclone V SoC 5CSEBA6U23I7) & Sandbox Chip Merah Putih Peruri  
> **Institusi:** Departemen Teknik Elektro, Fakultas Teknik, Universitas Indonesia (2026)  
> **Studi Kasus:** Private PIN Verification via Secure 2-Party Computation (2PC / MPC)

---

## 👥 Tim Pengembang (Universitas Indonesia)

| Nama Anggota | Institusi | Kontak |
|---|---|---|
| **Carlsson Khovis** | Universitas Indonesia | `carlkho99@gmail.com` |
| **Khalisa Zahra Maulana** | Universitas Indonesia | `khalisazhrm@gmail.com` |
| **Nabil Putra Nurfariz** | Universitas Indonesia | `naputrizwastaken@gmail.com` |
| **Raja Avicenna Al-Kindi Vijasa** | Universitas Indonesia | `rajasossial@gmai.com` |

---

## 📌 1. Latar Belakang & Ringkasan Ide

Komputasi multi-pihak aman (*Secure Multi-Party Computation* / MPC) memungkinkan dua entitas (misalnya: Bank dan Nasabah, atau Server Identitas PERURI dan Mesin EDC / Smart Terminal) memproses data bersama tanpa mengekspos data rahasia masing-masing. Protokol paling teruji untuk keperluan ini adalah **Yao's Garbled Circuits (GC)**.

Namun, evaluasi sirkuit garbled di perangkat lunak (*software*) memiliki hambatan performa kritis (*cryptographic bottleneck*):
- Setiap gerbang logika non-XOR (seperti AND) membutuhkan komputasi hash kriptografis berulang.
- Arsitektur konvensional mengalami *memory explosion* karena memuat seluruh kombinasi netlist (gigabytes RAM).

### 💡 Solusi yang Diusulkan: GarbleChip
GarbleChip mengadopsi pendekatan **Sequential Circuit Garbling** (terinspirasi dari konsep TinyGarble):
1. **Finite State Machine with Datapath (FSMD)**: Sirkuit disekuensialisasi sehingga memori on-chip FPGA hanya perlu menyimpan label kawat yang sedang aktif (*cut-width*).
2. **Sliding Wire Window Scratchpad**: Menjaga kebutuhan BRAM hanya beberapa kilobyte (<3.5 KB) alih-alih gigabytes.
3. **Hardware SHA-256 PRF Engine**: Mesin hashing iteratif 512-bit (64 siklus) hemat area sesuai standar NIST FIPS 180-4. Input PRF (128-bit wire label + 32-bit Gate ID = 160-bit) muat dalam tepat **1 blok 512-bit**, mengeliminasi overhead multi-block hashing.
4. **Free-XOR Unit (0-Cycle Latency)**: Gerbang XOR dievaluasi seketika pada jalur kombinasional tanpa komputasi kriptografis menggunakan teknik Kolesnikov & Schneider.
5. **Avalon-MM Streaming RX Bridge**: Antarmuka streaming berkecepatan tinggi yang menghubungkan ARM Cortex-A9 (HPS) dan FPGA Fabric pada DE10-Nano.

---

## 🏗️ 2. Arsitektur Sistem

```
                         [ ARM Cortex-A9 HPS / Avalon-MM Stream ]
                                            |
                                            v
+===================================================================================+
|                                GARBLECHIP IP CORE                                 |
|                                                                                   |
|   +--------------------------+              +---------------------------------+   |
|   |                          |  wire read   |  Sliding Wire Window RAM        |   |
|   |  Garble Gate FSM         |------------->|  (Dual-Port 128-bit Scratchpad) |   |
|   |  Controller              |              +---------------------------------+   |
|   |                          |                               |                    |
|   |  - OP_LOAD (Wire Reg)    |                               | 128-bit label      |
|   |  - OP_XOR  (Free-XOR)    |                               v                    |
|   |  - OP_AND  (Half-Gates)  |              +---------------------------------+   |
|   |  - OP_FIN  (PIN Verify)  |              | Free-XOR Evaluation Unit        |   |
|   +--------------------------+              | (0-Cycle Combinational)         |   |
|               |                             +---------------------------------+   |
|               | 512-bit block                                |                    |
|               v                                              | 128-bit label      |
|   +----------------------------------------------------+     |                    |
|   | Iterative SHA-256 Core (NIST FIPS 180-4)           |<----+                    |
|   | - 64 Siklus Iteratif                               |                          |
|   | - Bit-slicing Sigma / Gamma (Hemat Area ALM)       |                          |
|   | - ROM Konstanta K (64 x 32-bit)                    |                          |
|   +----------------------------------------------------+                          |
|                                                                                   |
+===================================================================================+
                                            |
                                            v
                           [ Status Match (LED DE10-Nano) ]
```

---

## 📁 3. Struktur Direktori Repositori

Struktur repositori telah distandarisasi ke format **`/src`** dan **`/test`** agar siap digunakan langsung di Web Sandbox Peruri (`chip.peruri.co.id/simulator`) maupun Quartus Prime / ModelSim:

```text
peruri-hackathon/
├── src/                                   # Kode Desain Verilog (Hardware RTL)
│   ├── desain.v                           # [SANDBOX PERURI] File desain mandiri lengkap
│   ├── garblechip_top.v                   # Top-level IP Core (Modular)
│   ├── avalon_stream_rx.v                 # Avalon-MM Slave Interface (HPS-FPGA Bridge)
│   ├── garble_gate_fsm.v                  # FSM Controller Evaluasi Sirkuit
│   ├── sha256_core_iterative.v            # SHA-256 Iterative Engine 512-bit (64 Siklus)
│   ├── sha256_k_constants.v               # ROM Konstanta NIST K0..K63
│   ├── sliding_wire_window_ram.v          # Scratchpad RAM Label Kawat 128-bit
│   └── free_xor_unit.v                    # Unit Evaluasi Free-XOR (0-Cycle)
│
├── test/                                  # Testbench & Vektor Pengujian
│   ├── tb.v                               # [SANDBOX PERURI] Testbench mandiri lengkap
│   ├── tb_garblechip_top.v                # Testbench modular membaca berkas hex
│   ├── tb_garblechip_top_inline.v         # Testbench modular mandiri (inline stimulus)
│   ├── tb_sha256_core.v                   # Testbench verifikasi NIST SHA-256 Core
│   ├── test_vector_match.hex              # Vektor uji PIN MATCH (Alice == Bob)
│   └── test_vector_mismatch.hex           # Vektor uji PIN MISMATCH (Alice != Bob)
│
├── python/                                # Software Stack & Golden Model
│   ├── sha256_ref.py                      # Model referensi SHA-256 FIPS 180-4
│   ├── garbler_pin.py                     # Golden model Garbler & Evaluator (MPC)
│   ├── generate_vectors.py                # Generator vektor uji instruksi hex
│   └── rtl_simulator.py                   # Simulator siklus akurat perilaku RTL
│
├── PERURI.md                              # Dokumen proposal lengkap tim
├── PRE_PROPOSAL_HACKATHON_CHIP_2026.md    # Dokumen referensi proposal teknis
└── README.md                              # Dokumentasi resmi proyek
```

---

## ⚡ 4. Spesifikasi Performa & Estimasi Sumber Daya

| Parameter | Spesifikasi | Keterangan |
|---|---|---|
| **Frekuensi Clock Target** | 50 MHz | Clock bawaan osilator DE10-Nano |
| **Latensi Free-XOR Gate** | **0 Siklus** (0 ns) | Dievaluasi pada jalur kombinasional |
| **Latensi Half-Gates AND** | **132 Siklus** (2.64 µs) | 2 kali SHA-256 (64 siklus) + 4 siklus FSM |
| **Evaluasi PIN 24-bit Penuh** | **3,201 Siklus** (64.02 µs) | 24 gerbang AND + 47 gerbang XOR |
| **Kebutuhan Sel Logika (ALMs)** | **~242 Cells** | Sangat hemat (<1% dari 41.910 ALMs Cyclone V) |
| **Kebutuhan Memori On-Chip** | **34.816 bit** (~3.5 KB) | BRAM M10K (Sliding Wire RAM + K ROM) |

---

## 🚀 5. Panduan Simulasi di Sandbox Peruri (chip.peruri.co.id)

Platform sandbox Peruri menggunakan backend simulator berbasis Icarus Verilog dengan struktur direktori `/src` dan `/test`. Berkas di repositori ini dirancang 100% kompatibel tanpa error:

### Langkah Penggunaan:
1. **Buka Simulator Peruri:** Masuk ke menu simulator sirkuit di [chip.peruri.co.id](https://chip.peruri.co.id).
2. **Berkas Desain (`/src`):**
   - Buka berkas `src/desain.v` pada editor sandbox (atau buat jika belum ada).
   - Salin dan tempel seluruh isi dari [`src/desain.v`](src/desain.v) repositori ini.
3. **Berkas Testbench (`/test`):**
   - Buka berkas `test/tb.v` pada editor sandbox (atau buat jika belum ada).
   - Salin dan tempel seluruh isi dari [`test/tb.v`](test/tb.v) repositori ini.
4. **Jalankan Sintesis:**
   - Klik tombol **`Jalankan sintesis`**. Desain akan selesai disintesis dengan status sukses.
5. **Jalankan Simulasi:**
   - Klik tombol **`Jalankan simulasi`**. Hasil pengujian verifikasi PIN dan waveform VCD interaktif akan langsung ditampilkan.

---

## 🧪 6. Simulasi Software & Verifikasi Mandiri

### A. Uji Golden Model Python & Simulator RTL Siklus-Akurat
```bash
# Uji model referensi Garbler dan Evaluator (Half-Gates + Free-XOR)
python python/garbler_pin.py

# Generate vektor uji hex terbaru
python python/generate_vectors.py

# Uji simulator siklus akurat RTL
python python/rtl_simulator.py
```
*Hasil:* 100% Bit-exact match dengan spesifikasi sirkuit garbled dan latensi 3.201 siklus.

### B. Simulasi Verilog Menggunakan Icarus Verilog
```bash
# Simulasi paket modular mandiri
iverilog -o sim_garblechip src/*.v test/tb_garblechip_top_inline.v
vvp sim_garblechip

# Atau simulasi paket sandbox tunggal
iverilog -o sim_sandbox src/desain.v test/tb.v
vvp sim_sandbox
```
