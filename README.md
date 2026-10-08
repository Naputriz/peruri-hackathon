# GarbleChip: Hardware Cryptography Accelerator for Yao's Garbled Circuits

[![Hackathon Chip 2026](https://img.shields.io/badge/Hackathon-Chip%202026%20(Peruri)-blue.svg)](https://chip.peruri.co.id)
[![Target Platform](https://img.shields.io/badge/Platform-Terasic%20DE10--Nano%20(Cyclone%20V)-orange.svg)](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1046)
[![Verilog Standard](https://img.shields.io/badge/Verilog-Universal%201995%2F2001%2F2005-green.svg)]()
[![Status](https://img.shields.io/badge/Verification-100%25%20Passed-brightgreen.svg)]()

> **Kategori Lomba:** Track 02 — Hardware Cryptography Accelerator  
> **Platform Target:** Terasic DE10-Nano (Intel Cyclone V SoC 5CSEBA6U23I7) & Sandbox Chip Merah Putih  
> **Studi Kasus:** Private PIN Verification via Secure 2-Party Computation (2PC / MPC)

---

## 📌 1. Latar Belakang & Ringkasan Ide

Komputasi multi-pihak aman (*Secure Multi-Party Computation* / MPC) memungkinkan dua entitas (misal: Bank dan Nasabah, atau Rumah Sakit dan Lab) memproses data bersama tanpa mengekspos data mentah masing-masing. Protokol klasik paling dominan adalah **Yao's Garbled Circuits (GC)**.

Namun, evaluasi sirkuit garbled di perangkat lunak (*software*) memiliki hambatan performa kritis (*cryptographic bottleneck*):
Setiap gerbang logika non-XOR (seperti AND) membutuhkan komputasi hash kriptografis berulang. Pada prosesor edge konvensional, evaluasi ribuan gerbang logika menguras siklus clock CPU dan daya baterai.

**GarbleChip** menghadirkan akselerator hardware silikon khusus untuk mengevaluasi sirkuit garbled dengan efisiensi ekstrem:
1. **Free-XOR Unit (0-Cycle Latency)**: Gerbang XOR dievaluasi seketika tanpa komputasi kriptografis menggunakan teknik Kolesnikov & Schneider (2008).
2. **Half-Gates Garbled AND Evaluator**: Reduksi ukuran tabel garbled menjadi hanya 2 ciphertexts per gerbang AND menggunakan skema Zahur, Rosulek, & Evans (Eurocrypt 2015).
3. **Hardware SHA-256 PRF Engine**: Mesin hashing iteratif 512-bit (64 siklus) hemat area sesuai standar NIST FIPS 180-4.
4. **Dual-Port Scratchpad RAM**: Memori on-chip 128-bit berkecepatan tinggi untuk menyimpan *active wire labels*.

---

## 🏗️ 2. Arsitektur Sistem

```
                         [ Avalon FIFO / AXI Stream ]
                                     |
                                     v
+===========================================================================+
|                           GARBLECHIP TOP LEVEL                            |
|                                                                           |
|   +-----------------------+               +---------------------------+   |
|   |                       |  wire read    |    Scratchpad RAM         |   |
|   |  Garble Gate FSM      |-------------->|  (256 x 128-bit Labels)   |   |
|   |  Controller           |               +---------------------------+   |
|   |                       |                             |                 |
|   |  - OP_LOAD (Wire Reg) |                             | 128-bit         |
|   |  - OP_XOR  (0-Cycle)  |                             v                 |
|   |  - OP_AND  (Half-Gate)|               +---------------------------+   |
|   |  - OP_FIN  (Verify)   |               | Free-XOR Unit             |   |
|   +-----------------------+               | (0 Siklus Kombinasional)  |   |
|               |                           +---------------------------+   |
|               | 512-bit block                           |                 |
|               v                                         | 128-bit         |
|   +-----------------------------------------------+     |                 |
|   | SHA-256 Iterative Core (NIST FIPS 180-4)      |<----+                 |
|   | - 64 Siklus Iteratif                          |                       |
|   | - Bit-slicing Sigma/Gamma (Hemat Area)        |                       |
|   | - ROM Konstanta K (64 x 32-bit)               |                       |
|   +-----------------------------------------------+                       |
|                                                                           |
+===========================================================================+
                                     |
                                     v
                        [ Status Match (LED DE10-Nano) ]
```

---

## 📁 3. Struktur Direktori Repositori

```text
peruri-hackathon/
├── rtl/                               # Berkas RTL Verilog IP Core (Sintesis)
│   ├── garblechip_top.v               # Top-level IP Core
│   ├── garble_gate_fsm.v              # Controller FSM Evaluasi Sirkuit
│   ├── sha256_iterative_core.v        # Engine SHA-256 512-bit (64-cycle)
│   ├── sha256_k_constants.v           # ROM Konstanta NIST K0..K63
│   ├── free_xor_unit.v                # Unit Evaluasi Free-XOR (0-cycle)
│   └── wire_label_ram.v               # Scratchpad RAM Label Kawat 128-bit
│
├── tb/                                # Berkas Testbench & Vektor Uji
│   ├── tb_garblechip_top_inline.v     # Testbench mandiri (inline vectors)
│   ├── tb_garblechip_top.v            # Testbench end-to-end membaca file hex
│   ├── tb_sha256_core.v               # Testbench verifikasi NIST SHA-256
│   ├── test_vector_match.hex          # Vektor uji PIN MATCH
│   └── test_vector_mismatch.hex       # Vektor uji PIN MISMATCH
│
├── python/                            # Golden Model & Generator Vektor
│   ├── sha256_ref.py                  # Referensi SHA-256 1-blok
│   ├── garbler_pin.py                 # Golden Model Garbler & Evaluator
│   ├── generate_vectors.py            # Generator berkas uji testbench hex
│   └── rtl_simulator.py               # Cycle-accurate software emulator
│
├── sandbox/                           # Paket Berkas untuk Web Sandbox Peruri
│   ├── garblechip_design.v            # Desain lengkap mandiri untuk desain.v
│   ├── garblechip_testbench.v         # Testbench untuk folder test/
│   ├── garblechip_sandbox_package.v   # Paket lengkap terintegrasi
│   └── sha256_sandbox_package.v       # Paket uji mandiri modul SHA-256
│
├── PRE_PROPOSAL_HACKATHON_CHIP_2026.md # Dokumen pra-proposal lengkap tim
└── README.md
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
| **Kebutuhan Memori On-Chip** | **34.816 bit** (~3.5 KB) | BRAM M10K (Scratchpad RAM + K ROM) |

---

## 🚀 5. Panduan Simulasi & Pengujian

### A. Simulasi di Sandbox Web Peruri (chip.peruri.co.id)
1. Salin seluruh kode [garblechip_design.v](sandbox/garblechip_design.v) ke berkas `desain.v` di **Folder `src/`**.
2. Buat berkas baru di **Folder `test/`** bernama `test_garblechip.v`, lalu salin isi [garblechip_testbench.v](sandbox/garblechip_testbench.v).
3. Klik tombol **`Jalankan sintesis`** &rarr; Desain akan langsung tersintesis dengan status hijau.
4. Klik tombol **`Jalankan simulasi`** &rarr; Hasil verifikasi dan grafik gelombang interaktif langsung dapat diamati.

### B. Simulasi Mandiri (Python Golden Model)
Untuk memverifikasi kebenaran matematis kriptografi dan siklus eksekusi:
```bash
# Uji model referensi Garbler dan Evaluator (Half-Gates + Free-XOR)
python python/garbler_pin.py

# Uji simulator siklus akurat RTL
python python/rtl_simulator.py
```

### C. Simulasi Verilog (Icarus Verilog / ModelSim / QuestaSim)
```bash
# Kompilasi dengan Icarus Verilog
iverilog -o sim_garblechip rtl/*.v tb/tb_garblechip_top_inline.v
vvp sim_garblechip
```

---

## 👥 Tim Pengembang
- **Kategori:** IC Chip Design & FPGA Implementation
- **Target Event:** Hackathon Chip Merah Putih 2026 (PERURI)
