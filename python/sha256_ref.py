"""
Golden Model: SHA-256 Reference Implementation (Single-Block 512-bit)
Sesuai standar NIST FIPS 180-4.
Dioptimalkan untuk verifikasi hardware 64-siklus putaran kompresi.
"""

import hashlib
import struct

# Initial Hash Values (H0..H7)
H_INIT = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
]

# Round Constants (K0..K63)
K_CONSTANTS = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
]

def rotr(x: int, n: int) -> int:
    return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF

def ch(x: int, y: int, z: int) -> int:
    return (x & y) ^ (~x & z)

def maj(x: int, y: int, z: int) -> int:
    return (x & y) ^ (x & z) ^ (y & z)

def sigma0(x: int) -> int:
    return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22)

def sigma1(x: int) -> int:
    return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25)

def gamma0(x: int) -> int:
    return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3)

def gamma1(x: int) -> int:
    return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10)

def pad_single_block(data: bytes) -> bytes:
    """Pad pesan agar tepat 1 blok 512-bit (64 bytes).
    Hanya valid untuk data berukuran <= 55 bytes (440 bits).
    Garbled Circuit label (128-bit) + Gate ID (32-bit) = 20 bytes (160 bits).
    """
    assert len(data) <= 55, f"Data terlalu panjang ({len(data)} bytes) untuk 1 blok SHA-256!"
    bit_len = len(data) * 8
    padded = data + b'\x80'
    padded += b'\x00' * (56 - len(padded))
    padded += struct.pack('>Q', bit_len)
    assert len(padded) == 64
    return padded

def sha256_compress_single_block(block_512: bytes):
    """
    Simulasi kompresi 64-siklus putaran yang merefleksikan hardware RTL.
    Mengembalikan: (digest 256-bit bytes, list_of_round_states untuk testbench)
    """
    assert len(block_512) == 64
    
    # 1. Message schedule expansion W[0..63]
    w = list(struct.unpack('>16I', block_512)) + [0] * 48
    for t in range(16, 64):
        s0 = gamma0(w[t - 15])
        s1 = gamma1(w[t - 2])
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF
    
    # 2. Register kerja A..H
    a, b, c, d, e, f, g, h = H_INIT
    round_states = []
    
    # 3. 64 Putaran Kompresi (1 putaran per siklus clock)
    for t in range(64):
        t1 = (h + sigma1(e) + ch(e, f, g) + K_CONSTANTS[t] + w[t]) & 0xFFFFFFFF
        t2 = (sigma0(a) + maj(a, b, c)) & 0xFFFFFFFF
        h = g
        g = f
        f = e
        e = (d + t1) & 0xFFFFFFFF
        d = c
        c = b
        b = a
        a = (t1 + t2) & 0xFFFFFFFF
        round_states.append((a, b, c, d, e, f, g, h))
    
    # 4. Final addition
    final_h = [
        (H_INIT[0] + a) & 0xFFFFFFFF,
        (H_INIT[1] + b) & 0xFFFFFFFF,
        (H_INIT[2] + c) & 0xFFFFFFFF,
        (H_INIT[3] + d) & 0xFFFFFFFF,
        (H_INIT[4] + e) & 0xFFFFFFFF,
        (H_INIT[5] + f) & 0xFFFFFFFF,
        (H_INIT[6] + g) & 0xFFFFFFFF,
        (H_INIT[7] + h) & 0xFFFFFFFF,
    ]
    digest = struct.pack('>8I', *final_h)
    return digest, round_states, w

def test_sha256_golden_model():
    """Uji coba Golden Model terhadap berbagai payload dan cocokkan dengan hashlib."""
    test_cases = [
        b"abc",
        b"",
        b"GarbleChip 2026",
        # Simulasi label kawat (16 bytes) + gate id (4 bytes) = 20 bytes
        b"\xaa" * 16 + struct.pack('>I', 42),
        b"\x00" * 20,
        b"\xff" * 20
    ]
    
    print("=== Testing Golden Model SHA-256 Single-Block ===")
    for idx, tc in enumerate(test_cases):
        padded = pad_single_block(tc)
        digest, _, _ = sha256_compress_single_block(padded)
        expected = hashlib.sha256(tc).digest()
        assert digest == expected, f"Mismatch pada kasus {idx}: {digest.hex()} vs {expected.hex()}"
        print(f"Case {idx + 1} ({len(tc)} bytes) MATCH! Hash: {digest.hex()[:16]}...")
    
    print(">>> 100% Vektor Teruji Sempurna dan Identik dengan hashlib! <<<\n")

if __name__ == "__main__":
    test_sha256_golden_model()
