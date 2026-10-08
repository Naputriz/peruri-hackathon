"""
GarbleChip: Yao's Garbled Circuit Simulator & PIN Verification Generator
Mengimplementasikan Half-Gates (Zahur et al., 2015) & Free-XOR (Kolesnikov & Schneider, 2008)
dengan SHA-256 PRF (1-blok 512-bit).
"""

import os
import struct
from typing import List, Tuple, Dict
from sha256_ref import pad_single_block, sha256_compress_single_block

def xor_bytes(a: bytes, b: bytes) -> bytes:
    return bytes(x ^ y for x, y in zip(a, b))

def prf_hash(wire_label: bytes, gate_id: int) -> bytes:
    """
    Fungsi PRF SHA-256 untuk gerbang:
    Input = wire_label (16 bytes / 128 bit) + gate_id (4 bytes / 32 bit big-endian) = 20 bytes (160 bit).
    Pas dalam tepat 1 blok 512-bit SHA-256.
    Output: 16 bytes pertama (128 bit) dari SHA-256 digest.
    """
    assert len(wire_label) == 16
    payload = wire_label + struct.pack('>I', gate_id)
    padded = pad_single_block(payload)
    digest, _, _ = sha256_compress_single_block(padded)
    return digest[:16]

class Wire:
    """Representasi Kawat Logika dengan Free-XOR."""
    def __init__(self, wire_id: int, w0: bytes, delta: bytes):
        self.wire_id = wire_id
        self.w0 = w0  # Label untuk nilai boolean 0 (16 bytes)
        self.w1 = xor_bytes(w0, delta)  # Label untuk nilai boolean 1
        # Pointer bit (Point-and-permute): LSB dari byte terakhir
        self.p0 = self.w0[-1] & 1
        self.p1 = self.w1[-1] & 1
        assert self.p0 ^ self.p1 == 1, "LSB delta harus 1 agar p0 != p1!"

class Garbler:
    """Pihak Alice (Circuit Generator)."""
    def __init__(self):
        # Bangun random offset Delta 128-bit dengan LSB = 1 (Free-XOR)
        random_16 = os.urandom(16)
        self.delta = random_16[:-1] + bytes([random_16[-1] | 1])
        self.wires: Dict[int, Wire] = {}
        self.next_wire_id = 0

    def new_wire(self) -> Wire:
        wid = self.next_wire_id
        self.next_wire_id += 1
        # Buat w0 dengan bit LSB bebas
        w0_raw = os.urandom(16)
        wire = Wire(wid, w0_raw, self.delta)
        self.wires[wid] = wire
        return wire

    def garble_xor(self, wire_a: Wire, wire_b: Wire) -> Wire:
        """Free-XOR: Biaya komputasi & tabel = 0!"""
        wid = self.next_wire_id
        self.next_wire_id += 1
        w0 = xor_bytes(wire_a.w0, wire_b.w0)
        wire_c = Wire(wid, w0, self.delta)
        self.wires[wid] = wire_c
        return wire_c

    def garble_xnor(self, wire_a: Wire, wire_b: Wire) -> Wire:
        """Free-XNOR: Free-XOR dilanjutkan inversi NOT (juga gratis)."""
        wire_xor = self.garble_xor(wire_a, wire_b)
        wid = self.next_wire_id
        self.next_wire_id += 1
        wire_c = Wire(wid, wire_xor.w1, self.delta)
        self.wires[wid] = wire_c
        return wire_c

    def garble_and_half_gates(self, wire_a: Wire, wire_b: Wire, gate_id: int) -> Tuple[Wire, bytes, bytes]:
        """
        Half-Gates AND (Zahur, Rosulek, Evans 2015).
        Tepat 2 ciphertext (TG, TE).
        """
        wid = self.next_wire_id
        self.next_wire_id += 1
        
        pa = wire_a.p0
        pb = wire_b.p0
        
        ha0 = prf_hash(wire_a.w0, gate_id)
        ha1 = prf_hash(wire_a.w1, gate_id)
        hb0 = prf_hash(wire_b.w0, gate_id)
        hb1 = prf_hash(wire_b.w1, gate_id)
        
        # Garbler Half-Gate
        tg = xor_bytes(ha0, ha1)
        if pb == 1:
            tg = xor_bytes(tg, self.delta)
        wg0 = ha0 if pa == 0 else xor_bytes(ha0, tg)
        
        # Evaluator Half-Gate
        te = xor_bytes(hb0, hb1)
        te = xor_bytes(te, wire_a.w0)
        we0 = hb0 if pb == 0 else xor_bytes(hb0, xor_bytes(te, wire_a.w0))
        
        # Output label c0 = wg0 ^ we0
        wc0 = xor_bytes(wg0, we0)
        wire_c = Wire(wid, wc0, self.delta)
        self.wires[wid] = wire_c
        
        return wire_c, tg, te

class Evaluator:
    """Pihak Bob (Hardware Core Accelerator GarbleChip)."""
    @staticmethod
    def eval_xor(label_a: bytes, label_b: bytes) -> bytes:
        """0-cycle / instant bitwise XOR."""
        return xor_bytes(label_a, label_b)

    @staticmethod
    def eval_and_half_gates(label_a: bytes, label_b: bytes, tg: bytes, te: bytes, gate_id: int) -> bytes:
        """
        Evaluasi Half-Gate AND di hardware:
        WG = H(A) ^ (sa * TG)
        WE = H(B) ^ (sb * (TE ^ A))
        WC = WG ^ WE
        """
        sa = label_a[-1] & 1
        sb = label_b[-1] & 1
        
        ha = prf_hash(label_a, gate_id)
        wg = ha if sa == 0 else xor_bytes(ha, tg)
        
        hb = prf_hash(label_b, gate_id)
        if sb == 0:
            we = hb
        else:
            we = xor_bytes(hb, te)
            we = xor_bytes(we, label_a)
            
        return xor_bytes(wg, we)

def test_single_gates():
    """Uji coba kebenaran evaluasi gerbang tunggal XOR dan AND."""
    print("=== Testing Single-Gate Garbler & Evaluator ===")
    garbler = Garbler()
    evaluator = Evaluator()
    
    # 1. Test AND Gate
    for a_val in [0, 1]:
        for b_val in [0, 1]:
            wa = garbler.new_wire()
            wb = garbler.new_wire()
            wc, tg, te = garbler.garble_and_half_gates(wa, wb, gate_id=101)
            
            label_a = wa.w1 if a_val else wa.w0
            label_b = wb.w1 if b_val else wb.w0
            
            eval_label = evaluator.eval_and_half_gates(label_a, label_b, tg, te, gate_id=101)
            expected_val = a_val & b_val
            expected_label = wc.w1 if expected_val else wc.w0
            
            assert eval_label == expected_label, f"AND failed for ({a_val}, {b_val})"
            print(f"AND Gate ({a_val} & {b_val} = {expected_val}): OK! Label match.")
            
    # 2. Test XOR Gate
    for a_val in [0, 1]:
        for b_val in [0, 1]:
            wa = garbler.new_wire()
            wb = garbler.new_wire()
            wc = garbler.garble_xor(wa, wb)
            
            label_a = wa.w1 if a_val else wa.w0
            label_b = wb.w1 if b_val else wb.w0
            
            eval_label = evaluator.eval_xor(label_a, label_b)
            expected_val = a_val ^ b_val
            expected_label = wc.w1 if expected_val else wc.w0
            
            assert eval_label == expected_label, f"XOR failed for ({a_val}, {b_val})"
            print(f"XOR Gate ({a_val} ^ {b_val} = {expected_val}): OK! Free-XOR match.")
            
    print(">>> Seluruh Gerbang Tunggal Lolos Verifikasi 100%! <<<\n")

def run_private_pin_verification(pin_alice: int, pin_bob: int, bit_width: int = 24):
    """
    Simulasi lengkap 2PC Private PIN Authentication:
    Alice (Server) memegang PIN referensi pin_alice.
    Bob (User/Token) memegang PIN input pin_bob.
    Hasil: MATCH (1) jika sama, FAIL (0) jika beda.
    """
    garbler = Garbler()
    evaluator = Evaluator()
    
    # 1. Inisialisasi kawat input untuk Alice dan Bob
    wires_alice = [garbler.new_wire() for _ in range(bit_width)]
    wires_bob = [garbler.new_wire() for _ in range(bit_width)]
    
    # 2. Garbler membangun rangkaian Equality:
    # Bitwise XNOR (Free-XOR, 0 cost)
    wires_eq = []
    for i in range(bit_width):
        w_xnor = garbler.garble_xnor(wires_alice[i], wires_bob[i])
        wires_eq.append(w_xnor)
        
    # AND Tree (23 gerbang AND Half-Gates)
    gate_id = 1
    current_level = wires_eq
    tables_and = []
    
    while len(current_level) > 1:
        next_level = []
        for i in range(0, len(current_level), 2):
            if i + 1 < len(current_level):
                w_out, tg, te = garbler.garble_and_half_gates(current_level[i], current_level[i+1], gate_id)
                tables_and.append((gate_id, current_level[i].wire_id, current_level[i+1].wire_id, w_out.wire_id, tg, te))
                gate_id += 1
                next_level.append(w_out)
            else:
                next_level.append(current_level[i])
        current_level = next_level
        
    output_wire = current_level[0]
    
    # 3. Distribusi Token Input
    labels_alice = []
    for i in range(bit_width):
        bit_a = (pin_alice >> i) & 1
        labels_alice.append(wires_alice[i].w1 if bit_a else wires_alice[i].w0)
        
    labels_bob = []
    for i in range(bit_width):
        bit_b = (pin_bob >> i) & 1
        labels_bob.append(wires_bob[i].w1 if bit_b else wires_bob[i].w0)
        
    # 4. Evaluator (GarbleChip) Mengevaluasi di Hardware:
    evaluated_wires: Dict[int, bytes] = {}
    for i in range(bit_width):
        evaluated_wires[wires_alice[i].wire_id] = labels_alice[i]
        evaluated_wires[wires_bob[i].wire_id] = labels_bob[i]
        
    # Evaluasi 24 Free-XNOR
    for i in range(bit_width):
        la = evaluated_wires[wires_alice[i].wire_id]
        lb = evaluated_wires[wires_bob[i].wire_id]
        lxor = evaluator.eval_xor(la, lb)
        evaluated_wires[wires_eq[i].wire_id] = lxor
        
    # Evaluasi 23 Half-Gates AND
    for gid, in1, in2, out_id, tg, te in tables_and:
        la = evaluated_wires[in1]
        lb = evaluated_wires[in2]
        lout = evaluator.eval_and_half_gates(la, lb, tg, te, gid)
        evaluated_wires[out_id] = lout
        
    final_label = evaluated_wires[output_wire.wire_id]
    
    # Output wire: jika PIN cocok, nilainya True (w1)
    is_match = (final_label == output_wire.w1)
    expected_match = (pin_alice == pin_bob)
    assert is_match == expected_match, f"PIN Verification mismatch! Got {is_match}, expected {expected_match}"
    
    return is_match

if __name__ == "__main__":
    test_single_gates()
    
    print("=== Testing 24-bit Private PIN Verification (Golden Model) ===")
    test_pins = [
        (123456, 123456, True),      # Match identik
        (123456, 123457, False),     # Beda 1 bit terakhir
        (999999, 999999, True),      # Match 6 digit besar
        (0xABCDEF, 0x123456, False), # Acak beda
        (0x000000, 0x000000, True),  # Zero match
    ]
    
    for pa, pb, expected in test_pins:
        result = run_private_pin_verification(pa, pb, bit_width=24)
        status = "MATCH" if result else "MISMATCH"
        print(f"Alice PIN: {pa:06X} | Bob PIN: {pb:06X} -> {status} (Expected: {'MATCH' if expected else 'MISMATCH'}) - PASSED!")
        
    print("\n>>> Seluruh Skenario Verifikasi PIN 24-bit Sukses 100%! <<<")
