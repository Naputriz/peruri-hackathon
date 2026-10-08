"""
GarbleChip: Generator Test Vector untuk Testbench Verilog RTL
Menghasilkan berkas hex dan konfigurasi sirkuit untuk simulasi hardware.
"""

import struct
from garbler_pin import Garbler, Evaluator, xor_bytes

def generate_pin_vectors(pin_alice: int, pin_bob: int, filename: str, bit_width: int = 24):
    garbler = Garbler()
    
    wires_alice = [garbler.new_wire() for _ in range(bit_width)]
    wires_bob = [garbler.new_wire() for _ in range(bit_width)]
    
    # 24 Bitwise XNOR
    wires_eq = []
    for i in range(bit_width):
        w_xnor = garbler.garble_xnor(wires_alice[i], wires_bob[i])
        wires_eq.append(w_xnor)
        
    # AND Tree (23 AND gates)
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
        
    out_wire = current_level[0]
    
    # Wire input labels
    labels_alice = [wires_alice[i].w1 if ((pin_alice >> i) & 1) else wires_alice[i].w0 for i in range(bit_width)]
    labels_bob = [wires_bob[i].w1 if ((pin_bob >> i) & 1) else wires_bob[i].w0 for i in range(bit_width)]
    
    # Format stream instruksi untuk hardware:
    # Opcode format (32-bit):
    # [31:24] = OPCODE: 0x01: LOAD_WIRE, 0x02: EVAL_XOR, 0x03: EVAL_AND, 0xFF: FINISH
    # [23:16] = WIRE_OUT / TARGET ID
    # [15:8]  = WIRE_IN1 ID
    # [7:0]   = WIRE_IN2 ID
    
    instructions = []
    
    # 1. Load initial input wire labels (24 Alice + 24 Bob)
    for i in range(bit_width):
        instructions.append(('LOAD_WIRE', wires_alice[i].wire_id, labels_alice[i]))
    for i in range(bit_width):
        instructions.append(('LOAD_WIRE', wires_bob[i].wire_id, labels_bob[i]))
        
    # 2. XNOR gates
    for i in range(bit_width):
        instructions.append(('EVAL_XOR', wires_alice[i].wire_id, wires_bob[i].wire_id, wires_eq[i].wire_id))
        
    # 3. AND gates with Half-Gates tables
    for gid, in1, in2, out_id, tg, te in tables_and:
        instructions.append(('EVAL_AND', gid, in1, in2, out_id, tg, te))
        
    instructions.append(('FINISH', out_wire.wire_id, out_wire.w1)) # Expected match label
    
    with open(filename, 'w') as f:
        f.write(f"// GarbleChip Test Vector: Alice=0x{pin_alice:06X}, Bob=0x{pin_bob:06X}, Match={pin_alice == pin_bob}\n")
        f.write(f"// Total Instructions: {len(instructions)}\n")
        f.write(f"// Expected Output Label (True/Match): {out_wire.w1.hex()}\n")
        f.write(f"// Expected Output Label (False/Mismatch): {out_wire.w0.hex()}\n\n")
        
        for item in instructions:
            if item[0] == 'LOAD_WIRE':
                wid, label = item[1], item[2]
                f.write(f"01 {wid:02X} 00 00 {label.hex()}\n")
            elif item[0] == 'EVAL_XOR':
                in1, in2, out_id = item[1], item[2], item[3]
                f.write(f"02 {out_id:02X} {in1:02X} {in2:02X} {'00'*32}\n")
            elif item[0] == 'EVAL_AND':
                gid, in1, in2, out_id, tg, te = item[1], item[2], item[3], item[4], item[5], item[6]
                f.write(f"03 {out_id:02X} {in1:02X} {in2:02X} {gid:08X} {tg.hex()} {te.hex()}\n")
            elif item[0] == 'FINISH':
                out_id, exp_w1 = item[1], item[2]
                f.write(f"FF {out_id:02X} 00 00 {exp_w1.hex()}\n")
                
    print(f"Generated {filename}: {len(instructions)} instruksi sirkuit.")

if __name__ == "__main__":
    import os
    os.makedirs("test", exist_ok=True)
    generate_pin_vectors(0x123456, 0x123456, "test/test_vector_match.hex", bit_width=24)
    generate_pin_vectors(0x123456, 0x123457, "test/test_vector_mismatch.hex", bit_width=24)
    print("Test vectors berhasil digenerate di folder test/.")
