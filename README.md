# GarbleChip: Area-Efficient Sequential Garbled Circuit Hardware Accelerator Based on a SHA-256 Core for Privacy-Preserving Computation on the DE10-Nano SoC

[![Hackathon Chip 2026](https://img.shields.io/badge/Hackathon-Chip%202026%20(Peruri)-blue.svg)](https://chip.peruri.co.id)
[![Target Platform](https://img.shields.io/badge/Platform-Terasic%20DE10--Nano%20(Cyclone%20V)-orange.svg)](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1046)
[![Verilog Standard](https://img.shields.io/badge/Verilog-Universal%201995%2F2001%2F2005-green.svg)]()
[![Status](https://img.shields.io/badge/Verification-100%25%20Passed-brightgreen.svg)]()

> **Kategori Lomba:** Track 02 — Hardware Cryptography Accelerator  
> **Platform Target:** Terasic DE10-Nano (Intel Cyclone V SoC 5CSEBA6U23I7) & Sandbox Chip Merah Putih Peruri  
> **Institusi:** Departemen Teknik Elektro, Fakultas Teknik, Universitas Indonesia, Depok (2026)  
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

## 📌 1. Latar Belakang & Ringkasan Ide (Executive Summary)

### 1.1. Problem Statement
Kebutuhan komputasi kolaboratif tanpa membuka data rahasia masing-masing pihak (*privacy-preserving computation*) meningkat pesat, seperti verifikasi PIN terdistribusi tanpa kebocoran kredensial. *Secure Two-Party Computation* (2PC) berbasis **Yao's Garbled Circuits (GC)** adalah solusi terpercaya. Namun, evaluasi GC pada perangkat lunak membebani CPU secara masif. Arsitektur hardware konvensional rentan terhadap *memory explosion* karena memuat seluruh gerbang logika kombinasi sekaligus (*combinational netlist*), menghabiskan gigabytes RAM.

### 1.2. Proposed Solution: GarbleChip
GarbleChip mengadopsi pendekatan **Sequential Circuit Garbling** (terinspirasi dari konsep TinyGarble):
1. **Finite State Machine with Datapath (FSMD):** Algoritma dikonversi menjadi FSMD kompak. Memori FPGA hanya menyimpan label kawat yang sedang aktif (*cut-width*), dan register D Flip-Flop membawa label kawat antar siklus clock tanpa beban kriptografi tambahan.
2. **Sliding Wire Window Architecture:** Scratchpad RAM on-chip hanya menyimpan *live wires*, menjaga memori tetap statis (hanya beberapa kilobyte BRAM M10K) tanpa terpengaruh kedalaman sirkuit.
3. **Hardware SHA-256 PRF Engine:** Menggunakan SHA-256 untuk evaluasi Half-Gates. Input 160-bit (label kawat 128-bit + Gate ID 32-bit) muat dalam tepat **1 blok kompresi 512-bit** standar NIST FIPS 180-4, beroperasi tepat **64 siklus clock** per dekripsi gerbang AND.
4. **Free-XOR Unit (0 Siklus):** Gerbang XOR dievaluasi seketika pada jalur kombinasional tanpa komputasi hash kriptografis menggunakan teknik Kolesnikov & Schneider.
5. **HPS-FPGA Co-Design (DE10-Nano):** ARM Cortex-A9 (HPS) bertindak sebagai Garbler yang menyiapkan dan mengalirkan data sirkuit, sedangkan FPGA Fabric bertindak sebagai Hardware Evaluator berkecepatan tinggi melalui antarmuka Avalon-MM.

---

## 🏗️ 2. Arsitektur Sistem & Modul RTL

```
                         [ ARM Cortex-A9 HPS / Avalon-MM Stream ]
                                            |
                                            v
+===================================================================================+
|                                GARBLECHIP IP CORE                                 |
|                                                                                   |
|   +--------------------------+              +---------------------------------+   |
|   |                          |  wire read   |  sliding_wire_window_ram.v      |   |
|   |  garble_gate_fsm.v       |------------->|  (Dual-Port 128-bit Scratchpad) |   |
|   |  Sequential Controller   |              +---------------------------------+   |
|   |                          |                               |                    |
|   |  - OP_LOAD (Wire Reg)    |                               | 128-bit label      |
|   |  - OP_XOR  (Free-XOR)    |                               v                    |
|   |  - OP_AND  (Half-Gates)  |              +---------------------------------+   |
|   |  - OP_FIN  (PIN Verify)  |              | free_xor_unit.v                 |   |
|   +--------------------------+              | (0-Cycle Combinational Logic)   |   |
|               |                             +---------------------------------+   |
|               | 512-bit block                                |                    |
|               v                                              | 128-bit label      |
|   +----------------------------------------------------+     |                    |
|   | sha256_core_iterative.v (NIST FIPS 180-4)          |<----+                    |
|   | - 64 Siklus Iteratif Datapath                      |                          |
|   | - Message Schedule In-Place Rotation               |                          |
|   | - sha256_k_constants.v (ROM K0..K63)               |                          |
|   +----------------------------------------------------+                          |
|                                                                                   |
+===================================================================================+
                                            |
                                            v
                           [ Status Match (LED DE10-Nano) ]
```

### Rincian Modul RTL (Sesuai Proposal Resmi Bagian 3.1):
1. **`sha256_core_iterative.v`:** Diadaptasi dari baseline lomba (32-bit single-round datapath). Merotasi jadwal pesan secara in-place tanpa unrolling. Beroperasi tepat 64 siklus clock per dekripsi gerbang AND.
2. **`garble_gate_fsm.v`:** Pengendali sekuensial yang mengelola bypass gerbang XOR (0-siklus), mengeksekusi operasi PRF/SHA-256 untuk gerbang AND, dan mengorkestrasi transfer label D-Flip-Flop (*state transfer*) untuk siklus $t+1$.
3. **`sliding_wire_window_ram.v`:** Memori cache BRAM M10K yang menyimpan label kawat aktif berdasarkan jangkauan *cut-width*. Memastikan kebutuhan memori tetap statis dan terisolasi dari total kedalaman sirkuit.
4. **`avalon_stream_rx.v`:** Antarmuka sinkronisasi DMA dengan domain clock HPS (ARM Cortex-A9).
5. **`desain.v`:** Berkas mandiri (*single-file*) terintegrasi yang disesuaikan secara khusus untuk Web Simulator Sandbox Peruri.

---

## 📁 3. Struktur Direktori Repositori

Sesuai ketentuan Sandbox Peruri, direktori diatur rapi menjadi **/src** dan **/test** (hanya **1 testbench tunggal** di `/test`):

```text
peruri-hackathon/
├── src/                                   # Berkas RTL Desain Perangkat Keras
│   ├── desain.v                           # [SANDBOX PERURI] Desain tunggal lengkap (Siap Upload)
│   ├── garblechip_top.v                   # Top-Level IP Core (Modular)
│   ├── avalon_stream_rx.v                 # Antarmuka Avalon-MM Slave HPS-FPGA
│   ├── garble_gate_fsm.v                  # FSM Controller Evaluator Sirkuit
│   ├── sha256_core_iterative.v            # Core Iteratif SHA-256 512-bit (64 Siklus)
│   ├── sha256_k_constants.v               # ROM Konstanta NIST K0..K63
│   ├── sliding_wire_window_ram.v          # Scratchpad RAM Label Kawat 128-bit
│   └── free_xor_unit.v                    # Unit Evaluasi Free-XOR (0 Siklus)
│
├── test/                                  # Berkas Testbench Pengujian
│   └── tb.v                               # [SANDBOX PERURI] SATU-SATUNYA TESTBENCH (Siap Upload)
│
├── python/                                # Golden Model & Generator Vektor Uji
│   ├── sha256_ref.py                      # Model referensi SHA-256 NIST FIPS 180-4
│   ├── garbler_pin.py                     # Golden model Garbler & Evaluator (MPC)
│   ├── generate_vectors.py                # Generator berkas instruksi sirkuit hex
│   ├── rtl_simulator.py                   # Simulator siklus akurat perilaku RTL
│   ├── test_vector_match.hex              # Vektor uji PIN MATCH (Alice == Bob)
│   └── test_vector_mismatch.hex           # Vektor uji PIN MISMATCH (Alice != Bob)
│
├── PERURI.md                              # Proposal Resmi Tim (Hackathon Chip 2026)
├── PRE_PROPOSAL_HACKATHON_CHIP_2026.md    # Naskah Pra-Proposal Teknis
└── README.md                              # Dokumentasi Resmi Proyek
```

---

## ⚡ 4. Estimasi Penggunaan Sumber Daya FPGA (Terasic DE10-Nano)

Tabel berikut diambil langsung dari **Proposal Resmi Tim Bagian 3.1**:

| Komponen Sumber Daya | Estimasi Penggunaan | Kapasitas DE10-Nano (Cyclone V) | Utilisasi (%) |
| :---: | :---: | :---: | :---: |
| **Logic Elements / LUT** | **~2,350 ALM** | 110,000 LEs / 41,910 ALMs | **< 6%** |
| **Registers / Flip-Flops (FF)** | **~2,650 FF** | 415,000 | **< 1%** |
| **Block RAM (M10K)** | **8 M10K (80 Kbits)** | 5,570 Kbits | **1.4%** |
| **DSP Blocks** | **0 DSP** | 112 DSP | **0%** |

### Target Metrik Keberhasilan:
- **Akurasi Dekripsi:** 100% *bit-exact* fungsional terhadap model referensi.
- **Konsumsi BRAM:** Murni statis dibatasi oleh *cut-width* kawat aktif sirkuit.
- **Efisiensi Throughput:** Minimal **15x lebih cepat** dibandingkan eksekusi perangkat lunak murni pada ARM Cortex-A9.

---

## 🚀 5. Panduan Langsung Masuk Sandbox Peruri (chip.peruri.co.id)

Platform simulator Peruri mewajibkan berkas desain berada di `Folder src/` dan berkas testbench di `Folder test/`.

### Langkah Pengujian di Sandbox:
1. **Buka Simulator Peruri:** Buka [chip.peruri.co.id/simulator](https://chip.peruri.co.id).
2. **Salin Kode Desain:**
   - Buka berkas `desain.v` pada **`Folder src/`**.
   - Salin dan tempel seluruh isi dari [`src/desain.v`](src/desain.v).
3. **Salin Kode Testbench:**
   - Buka berkas `tb.v` pada **`Folder test/`**.
   - Salin dan tempel seluruh isi dari [`test/tb.v`](test/tb.v).
4. **Jalankan Sintesis:**
   - Klik **`Jalankan sintesis`** &rarr; Desain akan tersintesis mulus (status hijau, 0 error).
5. **Jalankan Simulasi:**
   - Klik **`Jalankan simulasi`** &rarr; Hasil verifikasi private PIN match dan waveform VCD langsung ditampilkan.

---

## 🧪 6. Simulasi Perangkat Lunak (Python Golden Model)

```bash
# 1. Jalankan verifikasi matematika MPC Garbler & Evaluator
python python/garbler_pin.py

# 2. Generate ulang vektor instruksi uji
python python/generate_vectors.py

# 3. Jalankan simulasi siklus akurat RTL
python python/rtl_simulator.py
```
*Hasil:* Seluruh pengujian 100% BIT-EXACT PASSED (3.201 siklus clock, latensi 64.02 µs pada 50 MHz).
