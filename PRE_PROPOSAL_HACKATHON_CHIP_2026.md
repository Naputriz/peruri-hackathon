# PRE-PROPOSAL: HACKATHON CHIP 2026
**Kategori:** IC Chip Design & FPGA Implementation  
**Topik:** 02 - Hardware Cryptography Accelerator  
**Target Platform:** Terasic DE10-Nano (Intel Cyclone V SoC 5CSEBA6U23I7)  

---

## 1. Identitas Tim & Proyek

* **Judul Desain Chip:**  
  **GarbleChip: Akselerator Hardware Yao's Garbled Circuit Hemat Area Berbasis Core SHA-256 untuk Privacy-Preserving Computation pada SoC DE10-Nano**
* **Nama Tim:** [Nama Tim Anda]
* **Anggota Tim (4 Orang):**
  1. **Ketua / Lead RTL & Architect:** [Nama Ketua] — *Top-Level Architecture, GC Controller & Datapath RTL*
  2. **Anggota 1 / Crypto RTL Engineer:** [Nama Anggota 1] — *Compact SHA-256 PRF Core & Hashing Datapath*
  3. **Anggota 2 / Software & HPS Engineer:** [Nama Anggota 2] — *HPS (ARM Cortex-A9) Driver, Protocol 2PC & Garbler SW*
  4. **Anggota 3 / Verification & Demo Lead:** [Nama Anggota 3] — *Testbench, Quartus Synthesis, SignalTap & Board Bring-Up*
* **Dosen Pembimbing:** [Nama Dosen & Gelar] — [Institusi / Universitas]

---

## 2. Ringkasan Ide (Executive Summary)

### Masalah yang Diangkat
Kebutuhan komputasi kolaboratif antar-institusi tanpa saling membuka data rahasia (*privacy-preserving computation*) meningkat pesat—misalnya verifikasi PIN/kredensial tanpa membocorkan master hash, pencocokan *blacklist* perbankan, atau analisis rekam medis antar-rumah sakit. Teknik kriptografi **Secure Two-Party Computation (2PC)** melalui **Yao's Garbled Circuits (GC)** adalah solusi klasik terbaik: satu pihak mengacak fungsi logika menjadi sirkuit terenkripsi, dan pihak lain mengevaluasinya secara "buta" (*blind evaluation*) sehingga hanya hasil akhir yang terungkap.

Namun, metode ini memiliki kelemahan praktis: setiap sirkuit logika terdiri dari ribuan hingga jutaan gerbang, dan evaluasi setiap gerbang non-XOR membutuhkan **operasi fungsi hash/kriptografi**. Hal ini menjadikan fungsi hash sebagai *bottleneck* utama seluruh protokol. Pada perangkat lunak (CPU/ARM), komputasi ini menyebabkan beban prosesor tinggi dan konsumsi daya boros—kendala serius bagi perangkat *edge/embedded* tempat data sensitif dikumpulkan. Sementara itu, akselerator perangkat keras khusus untuk evaluasi gerbang terenkripsi masih sangat langka dan umumnya bersifat tertutup (*proprietary*).

### Solusi yang Ditawarkan (GarbleChip)
Alih-alih merancang mesin kriptografi asing dari nol, kami memanfaatkan fondasi yang terbukti andal dan menjadi *reference baseline* kompetisi ini: **Core SHA-256**. 
SHA-256 sangat ideal untuk skema garbling karena input hash pada evaluasi gerbang (label kawat 128-bit + identitas gerbang / Gate ID) berukuran $\le 288$ bit. Ukuran ini **pas dalam tepat satu blok kompresi 512-bit SHA-256** tanpa memerlukan *multi-block chaining*. 

Dengan demikian:
1. Satu gerbang AND terenkripsi dievaluasi dalam **tepat 1 operasi hash tunggal (64 siklus clock)**.
2. Gerbang XOR memiliki biaya komputasi **nol siklus (0-cycle)** berkat teknik **Free-XOR**.
3. Core SHA-256 dibungkus dengan kontroler FSM kompak yang menyusun blok input, memilih baris tabel terenkripsi, dan menghasilkan label kawat output.

Hasilnya adalah **GarbleChip**: sebuah *garbled-gate evaluator* mandiri yang kompak, hemat area, memanfaatkan logika teruji, dan mudah diverifikasi.

### Implementasi pada DE10-Nano: Pemisahan Tegas IP Core vs Host Testbed
Menjawab perdebatan arsitektur *standalone chip* vs *SoC*:
* **GarbleChip IP Core (100% Murni Hardware RTL di FPGA Fabric):**  
  Seluruh logika evaluasi sirkuit, FSM *gate scheduling*, pohon *Free-XOR*, dan *engine* SHA-256 diimplementasikan **murni di register-transfer level (Verilog/SystemVerilog synthesizable)**. Modul ini adalah *standalone IP core* yang dapat langsung dilepas dan di-tapeout ke silikon ASIC (misal SkyWater 130nm) tanpa ketergantungan pada CPU/firmware apapun.
* **ARM Cortex-A9 (HPS) Hanya Sebagai "Host Testbed / Simulator Pihak Luar":**  
  Prosesor ARM **TIDAK** menjalankan komputasi evaluasi sirkuit. ARM hanya difungsikan sebagai simulator pihak luar (Server Alice / Pihak Garbler) yang mengirimkan aliran paket data terenkripsi melalui bus standar (Avalon-MM/FIFO) untuk keperluan demonstrasi live *Two-Party Computation* (2PC) pada satu board.

### Batasan Klaim Teknis (*Scope Boundaries*)
Kami mengedepankan **kredibilitas ilmiah dan kejujuran teknik**:
* **Yang Kami Klaim:** Desain akselerator *hardware evaluator* gerbang terenkripsi mandiri yang hemat area, berakurasi 100%, terverifikasi secara matematis, terukur secara nyata di FPGA DE10-Nano, dan membuktikan percepatan komputasi signifikan berkat teknik *Free-XOR* dan *Single-Block SHA-256*.
* **Yang Tidak Kami Klaim:** Kami tidak mengklaim implementasi *production-grade garbler* di hardware (karena pembentukan sirkuit acak membutuhkan generator entropi TRNG bersertifikasi dan bandwidth transmisi yang berada di luar cakupan akselerator evaluator ini).

---

## 3. Latar Belakang & Rumusan Masalah

### Latar Belakang
*Secure Multi-Party Computation* (MPC) kini menjadi fondasi regulasi privasi data modern (seperti UU PDP di Indonesia dan GDPR). Dalam infrastruktur *security printing* dan identitas digital nasional (ekosistem PERURI), verifikasi PIN/biometrik pada terminal *smartcard/reader* konvensional menuntut kepercayaan mutlak pada server. Dengan Yao's Garbled Circuit, verifikasi dapat berlangsung secara *Zero-Trust*: pembuktian kesetaraan PIN dilakukan tanpa server mengetahui PIN pengguna, dan tanpa pengguna mengetahui referensi server.

### Rumusan Masalah & Tantangan Desain
1. **Kompleksitas Komputasi Hash:** Bagaimana meminimalkan overhead komputasi hash pada setiap gerbang sirkuit agar efisien dieksekusi di edge hardware?
2. **Efisiensi Area Silikon:** Bagaimana merancang arsitektur SHA-256 dan kontroler evaluasi gerbang dengan konsumsi logika $<10\%$ ALM DE10-Nano (memenuhi kriteria modul kecil dan hemat area referensi TT07)?
3. **Penyelarasan Dataflow HPS-FPGA:** Bagaimana merancang protokol *streaming* paket gerbang dari prosesor ARM ke fabric FPGA tanpa menyebabkan *pipeline stall*?

---

## 4. Proposed Chip Design & Arsitektur Sistem

### 4.1 Diagram Blok Arsitektur GarbleChip

```
+---------------------------------------------------------------------------------------+
|                                    DE10-Nano SoC                                      |
|                                                                                       |
|  +---------------------------------------------------------------------------------+  |
|  |                     HPS: ARM Cortex-A9 (Garbler / Alice Role)                   |  |
|  |  - Boolean Circuit Netlist Generator (PIN Verification / Equality Comparator)   |  |
|  |  - Software Garbler: Generate Garbled Tables (GT) & Wire Labels                 |  |
|  |  - Streaming Driver (C Linux / Avalon Interconnect)                            |  |
|  +---------------------------------------------------------------------------------+  |
|                                           |                                           |
|                                           | Avalon-MM / FIFO Bus (Streaming Packets)  |
|                                           v                                           |
|  +---------------------------------------------------------------------------------+  |
|  |                     FPGA FABRIC: GarbleChip (Evaluator Core)                    |  |
|  |                                                                                 |  |
|  |  +------------------------+      +-----------------------+                      |  |
|  |  |   Stream FIFO Buffer   | ---> |   GarbleChip FSM      |                      |  |
|  |  |  (Opcode, W_in, Table) |      |   Gate Controller     |                      |  |
|  |  +------------------------+      +-----------------------+                      |  |
|  |                                     |                 |                         |  |
|  |             +-----------------------+                 v                         |  |
|  |             | (XOR: 0-cycle)                +-------------------+               |  |
|  |             v                               | Wire Label RAM    | (M10K BRAM)   |  |
|  |     [ Free-XOR Unit ]                       | Internal Labels   |               |  |
|  |             |                               +-------------------+               |  |
|  |             |                                         |                         |  |
|  |             | (AND: Half-Gate PRF)                    v                         |  |
|  |             +------------> +-------------------------------------+              |  |
|  |                            | Area-Optimized SHA-256 Engine       |              |  |
|  |                            | - 1 Blok 512-bit (Single Iterative) |              |  |
|  |                            | - 64 Putaran Kompresi (64 clk)      |              |  |
|  |                            +-------------------------------------+              |  |
|  |                                               |                                 |  |
|  |                                               v                                 |  |
|  |                                    +----------------------+                     |  |
|  |                                    | Output Decode & Auth |                     |  |
|  |                                    | (VALID / INVALID)    |                     |  |
|  |                                    +----------------------+                     |  |
|  |                                               |                                 |  |
|  +-----------------------------------------------|---------------------------------+  |
|                                                  v                                    |
|                                         LEDs / Seven-Segment                          |
+---------------------------------------------------------------------------------------+
```

### 4.2 Analisis Teknis Efisiensi SHA-256 1-Blok
Salah satu inovasi kunci perancangan kami adalah **keselarasan dimensi data**:
* Input evaluasi gerbang terenkripsi:
  $$\text{Block Data} = W_{\text{input}} \ (128\text{ bit}) \parallel \text{Gate ID} \ (32\text{ bit}) = 160\text{ bit}$$
* Sesuai spesifikasi padding NIST SHA-256: pesan $\le 447$ bit dapat dipadatkan secara lengkap ke dalam **tepat satu blok 512-bit**.
* **Keuntungan Hardware:** Desain tidak membutuhkan *context switching*, memori *buffer* multi-blok, maupun penyimpanan *intermediate state* $H^{(i-1)}$. Datapath kompresi dapat langsung di-reset dan dijalankan secara mandiri dalam 64 siklus putaran per evaluasi gerbang AND.

### 4.3 Penjelasan Matematika Free-XOR & Konversi Sirkuit (Jawaban Kerumitan Math)
Banyak desainer khawatir bahwa *"matematika Yao's GC itu rumit"*. Faktanya, **seluruh kerumitan matematika Free-XOR berada pada sisi perangkat lunak Garbler (Alice)**, sedangkan pada **sisi akselerator hardware Evaluator (Bob), logikanya sangat sederhana dan instan**:

1. **Prinsip Free-XOR (Kolesnikov & Schneider, 2008):**
   * Garbler memilih sebuah *global random offset* $\Delta \in \{0, 1\}^{128}$ dengan LSB $\Delta[0] = 1$.
   * Untuk setiap kawat $i$, sepasang label didefinisikan sebagai:
     $$W_i^1 = W_i^0 \oplus \Delta$$
   * Untuk gerbang logika XOR dengan input kawat $A, B$ dan output $C$:
     $$W_C = W_A \oplus W_B$$
   * **Implementasi Hardware RTL:** Hanya membutuhkan satu baris gerbang logika kombinasional:
     ```verilog
     assign wire_label_out = wire_label_a ^ wire_label_b; // 0-cycle / 1-cycle latency!
     ```
     Tidak ada pemanggilan SHA-256, tidak ada ciphertext yang dikirim, dan tidak ada memori tabel yang dibaca!
2. **Konversi Sirkuit PIN Verification (Memaksimalkan XOR, Meminimalkan AND):**
   * Untuk memverifikasi kesamaan PIN 24-bit (setara 6 digit desimal: $A[23:0]$ vs $B[23:0]$):
     * **Tahap 1: Bitwise Equality ($A_i == B_i$):**
       Dinyatakan sebagai gerbang XNOR: $EQ_i = \text{NOT}(A_i \oplus B_i)$.  
       Di bawah skema Free-XOR, negasi (NOT) dan XOR bernilai **GRATIS (0 biaya hash/tabel)**! Sebanyak 24 gerbang XNOR selesai dalam $0\text{ cycle}$ kripto.
     * **Tahap 2: Penggabungan Keseluruhan (`MATCH` = $\bigwedge_{i=0}^{23} EQ_i$):**
       Dihubungkan menggunakan pohon gerbang AND biner (*binary AND-tree*) yang membutuhkan tepat:
       $$\text{Jumlah Gerbang AND} = 24 - 1 = 23\text{ gerbang}$$
   * **Hasil Latensi Hardware Riil:**
     * Total gerbang yang membutuhkan enkripsi hash: **hanya 23 gerbang AND**.
     * Total waktu komputasi hardware: $23 \times 64\text{ siklus} = 1.472\text{ clock cycles}$.
     * Pada frekuensi kerja clock 50 MHz di DE10-Nano, verifikasi PIN privat selesai dalam **$29,44\ \mu\text{s}$**!

### 4.4 Rincian Modul RTL Verilog

1. **`sha256_core_iterative.v` (Crypto Engine):**
   * Mengadaptasi konsep baseline TT07 SHA-256 dengan datapath 32-bit *single-round*.
   * Menghemat area register dengan memutar *message schedule* $W_t$ dan *working variables* $(A, B, C, D, E, F, G, H)$ menggunakan *shift-register array* tanpa unrolling.
2. **`garble_gate_fsm.v` (Controller):**
   * Mendekode tipe instruksi gerbang.
   * Untuk gerbang XOR: menghitung $W_C = W_A \oplus W_B$ dalam 1 siklus tanpa konsumsi SHA-256.
   * Untuk gerbang AND: mengambil baris tabel yang ditentukan oleh *point-and-permute bit*, memicu SHA-256, dan mendekripsi label keluaran $W_C = T_{\text{sel}} \oplus \text{SHA256}(W_A \parallel \text{Gate\_ID})$.
3. **`wire_scratchpad_ram.v`:**
   * Memori penyimpanan label kawat perantara berbasis BRAM dual-port M10K (kapasitas 512 entri $\times$ 128-bit) untuk efisiensi transfer data internal.
4. **`avalon_stream_rx.v`:**
   * Antarmuka penghubung Avalon-MM / FIFO antara ARM HPS dan core akselerator FPGA.

### 4.5 Estimasi Penggunaan Resource FPGA (DE10-Nano)

Target kapasitas DE10-Nano (Cyclone V 5CSEBA6U23I7): **41.910 ALMs / 110.000 LEs**, **5.570 Kbits BRAM**, **112 DSPs**.

| Modul RTL | ALM / LUTs | Dedicated Registers | Block Memory (M10K) | DSP Blocks |
|---|---|---|---|---|
| `sha256_core_iterative` | ~1.350 ALMs | ~1.500 FF | 0 | 0 |
| `garble_gate_fsm` | ~550 ALMs | ~600 FF | 0 | 0 |
| `wire_scratchpad_ram` | ~200 ALMs | ~250 FF | 8 M10K (80 Kbits) | 0 |
| `avalon_stream_rx` & Bus | ~250 ALMs | ~300 FF | 0 | 0 |
| **Total Sistem GarbleChip** | **~2.350 ALMs (5.6%)** | **~2.650 FF (<1%)** | **8 M10K (1.4%)** | **0 DSP (0%)** |

> **Analisis:** Menggunakan kurang dari 6% ALM membuktikan GarbleChip sangat hemat area, meninggalkan ruang sisa yang melimpah jika nantinya ingin diparalelkan (*multi-core evaluator*) atau di-porting ke silikon ASIC Tiny Tapeout (SkyWater 130nm).

### 4.6 Perangkat Lunak & Tools
* **ModelSim / Verilator:** Simulasi logika fungsi dan verifikasi sinyal RTL.
* **Intel Quartus Prime Lite 21.1:** Sintesis, Fitting, STA (TimeQuest), dan pemrograman bitstream.
* **Platform Designer (Qsys):** Desain integrasi bus sistem HPS-to-FPGA.
* **Python 3 & C/GCC:** Pustaka Golden Model, simulator sirkuit 2PC, dan aplikasi HPS Linux.

---

## 5. Strategi Eksekusi Terstruktur (*Step-by-Step Methodology*)

Untuk memastikan keberhasilan implementasi dalam batas waktu hackathon yang ketat, proyek dieksekusi dengan pendekatan inkremental bertahap di mana setiap langkah diverifikasi sebelum melangkah ke tahap berikutnya:

```
[Tahap 1: Golden Model]   -->  [Tahap 2: SHA Core RTL]   -->  [Tahap 3: Gate Evaluator]
(Python Reference & Hash)      (Verilog 64-Cycle Match)       (FSM & Free-XOR Unit)
                                                                       |
[Tahap 5: Metrik & Skala] <--  [Tahap 4: Board Bring-Up] <-------------+
(Benchmarking vs ARM SW)       (DE10-Nano HPS-FPGA Demo)
```

1. **Tahap 1 — Golden Model (Python Reference):**
   * Menulis model referensi SHA-256 dan protokol Garbler/Evaluator 1-gerbang dalam Python.
   * Memvalidasi hasil hash terhadap pustaka standar `hashlib` untuk memastikan presisi matematis 100%.
2. **Tahap 2 — Hardware Core (Verilog SHA-256):**
   * Mengembangkan modul Verilog SHA-256 iteratif (1 putaran per clock).
   * Membuktikan kesesuaian output RTL terhadap Golden Model Python melalui testbench otomatis (100% *bit-exact*).
3. **Tahap 3 — Evaluator Logic & FSM:**
   * Membangun kontroler sirkuit dan logika *Free-XOR* serta *Half-Gates* di sekitar core SHA-256.
   * Menguji seluruh kombinasi input truth table dan *corner cases* gerbang secara simulatif.
4. **Tahap 4 — Board Implementation (DE10-Nano Bring-Up):**
   * Mengimplementasikan interaksi nyata dua pihak pada board: ARM HPS bertindak sebagai *Garbler* dan FPGA Fabric sebagai *Evaluator*.
   * Menjalankan studi kasus nyata: **Private PIN Authentication** (membuktikan kesamaan PIN tanpa membuka nilai PIN).
5. **Tahap 5 — Pengukuran Metrik & Penskalaan:**
   * Mengukur angka riil dari Quartus dan hardware: utilisasi resource, konsumsi daya, latensi per gerbang, dan *speedup* terhadap komputasi murni software pada prosesor ARM.
   * Menunjukkan potensi penskalaan throughput (*multi-engine replication*).

---

## 6. Rencana Pengujian & Metrik Keberhasilan

### Skenario Uji: *Private PIN Authentication*
* **Pihak 1 (Server / HPS ARM):** Menyimpan PIN referensi terdaftar $PIN_{\text{ref}}$ (misal 6 digit / 24-bit).
* **Pihak 2 (User / FPGA Fabric):** Memiliki PIN input rahasia $PIN_{\text{user}}$.
* **Sirkuit Logika:** Sirkuit komparator kesetaraan bit (24 gerbang XNOR + 23 gerbang AND).
* **Hasil:** Menghasilkan 1 bit status: `MATCH` (LED Hijau) atau `INVALID` (LED Merah) tanpa kedua pihak pernah saling melihat nilai *plaintext*.

### Metrik Keberhasilan Target
* **Fungsional:** 100% akurasi deteksi kecocokan PIN pada seluruh uji sampel corner-case.
* **Latensi:** Waktu evaluasi sirkuit PIN 24-bit selesai dalam $< 1.600$ clock cycles ($< 32\ \mu\text{s}$ pada clock 50 MHz).
* **Throughput Speedup:** Mencapai percepatan komputasi gerbang sedikitnya $15\times$ dibanding evaluasi software di ARM Cortex-A9.
* **Efisiensi Area:** Konsumsi logika hardware $< 7\%$ total ALMs DE10-Nano.

---

## 7. Pembagian Peran Tim (4 Anggota)

| No | Anggota & Peran | Keahlian Utama | Tanggung Jawab & Luaran Spesifik |
|---|---|---|---|
| **1** | **Ketua Tim**<br>*(Lead RTL & System Architect)* | Arsitektur Digital, SystemVerilog, FSM | • Perancangan arsitektur top-level GarbleChip.<br>• Implementasi `garble_gate_fsm` (Free-XOR & Half-Gates).<br>• Manajemen antarmuka BRAM kawat label & integrasi sistem. |
| **2** | **Anggota 1**<br>*(Crypto RTL Engineer)* | Kriptografi Hardware, Optimasi Datapath | • Pengembangan `sha256_core_iterative` hemat area.<br>• Optimasi kompresi 1-blok 512-bit & padding PRF.<br>• Pembuatan testbench RTL mandiri berbasis vektor NIST. |
| **3** | **Anggota 2**<br>*(Software & HPS Co-Design)* | C/Python, Embedded Linux, MPC | • Pengembangan Golden Model referensi Python.<br>• Implementasi software Garbler (Alice) di ARM HPS.<br>• Driver pengiriman data stream HPS-to-FPGA via Avalon bus. |
| **4** | **Anggota 3**<br>*(Verification & Demo Lead)* | ModelSim, Quartus STA, Board Bring-Up | • Testbench otomatis end-to-end co-simulation.<br>• Kompilasi Quartus Prime & analisis timing/resource.<br>• Verifikasi SignalTap II on-board & pembuatan video demo live. |

---

## 8. Jadwal Eksekusi Bootcamp (3 Hari)

| Hari | Fokus Kegiatan | Target Deliverables |
|---|---|---|
| **Hari 1** | **Model Referensi & Core RTL** | • Python Golden Model selesai & tervalidasi `hashlib`.<br>• RTL SHA-256 iteratif selesai dan lolos simulasi testbench NIST.<br>• Spesifikasi antarmuka bus dataflow HPS-FPGA disepakati. |
| **Hari 2** | **Integrasi GC Evaluator & Qsys** | • Penggabungan FSM Evaluator dengan core SHA-256.<br>• Konfigurasi sistem Platform Designer (Qsys) untuk DE10-Nano.<br>• Software Garbler di HPS berhasil streaming paket gerbang ke FPGA. |
| **Hari 3** | **Hardware Bring-Up & Demo Live** | • Bitstream berjalan stabil pada DE10-Nano.<br>• Verifikasi eksekusi gerbang via SignalTap II Logic Analyzer.<br>• Pengambilan data konsumsi resource & speedup vs software.<br>• Dokumentasi teknis final dan video demonstrasi live (LED PIN Match). |

---

## 9. Referensi
1. A. C. Yao, *"How to generate and exchange secrets,"* Proc. 27th Annu. Symp. Found. Comput. Sci. (FOCS), 1986.
2. V. Kolesnikov and T. Schneider, *"Improved Garbled Circuit: Free XOR Gates and Applications,"* ICALP, 2008.
3. S. Zahur, M. Rosulek, and D. Evans, *"Two Halves Make a Whole: Reducing Data Transfer in Garbled Circuits using Half Gates,"* EUROCRYPT, 2015.
4. M. Bellare, V. T. Hoang, and P. Rogaway, *"Foundations of Garbled Circuits,"* ACM CCS, 2012.
5. Tiny Tapeout 07 (TT07) Reference Datasheet, Project `0718: tiny sha256` by xenia dragon, Dec 2025.
6. E. Songhori et al., *"TinyGarble: Highly Compressed and Scalable Sequential Garbled Circuits,"* IEEE S&P (Oakland), 2015.
