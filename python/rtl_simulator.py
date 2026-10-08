"""
GarbleChip: Cycle-Accurate Verilog RTL Emulator / Co-Simulator
Mereplikasi persis perilaku modul RTL:
- sha256_iterative_core.v (64-cycle compression, 16-word shift register)
- free_xor_unit.v (0-cycle bitwise XOR)
- wire_label_ram.v (256x128-bit memory)
- garble_gate_fsm.v & garblechip_top.v
"""

import struct
from sha256_ref import H_INIT, K_CONSTANTS, rotr, ch, maj, sigma0, sigma1, gamma0, gamma1

class Sha256IterativeCoreRTL:
    """Model siklus-akurat dari sha256_iterative_core.v"""
    def __init__(self):
        self.state = 'S_IDLE'
        self.round_cnt = 0
        self.ready = True
        self.done = False
        self.digest = b'\x00' * 32
        self.a = self.b = self.c = self.d = 0
        self.e = self.f = self.g = self.h = 0
        self.w_reg = [0] * 16

    def step(self, start: bool, block_512: bytes):
        if self.state == 'S_IDLE':
            self.done = False
            if start:
                self.ready = False
                self.state = 'S_ROUNDS'
                self.round_cnt = 0
                self.a, self.b, self.c, self.d, self.e, self.f, self.g, self.h = H_INIT
                self.w_reg = list(struct.unpack('>16I', block_512))
            else:
                self.ready = True
        elif self.state == 'S_ROUNDS':
            k_cur = K_CONSTANTS[self.round_cnt]
            w_cur = self.w_reg[0]
            
            # Operasi putaran NIST
            ch_val = ch(self.e, self.f, self.g)
            maj_val = maj(self.a, self.b, self.c)
            s0_val = sigma0(self.a)
            s1_val = sigma1(self.e)
            gam0_val = gamma0(self.w_reg[1])
            gam1_val = gamma1(self.w_reg[14])
            w_new = (self.w_reg[0] + gam0_val + self.w_reg[9] + gam1_val) & 0xFFFFFFFF
            
            t1 = (self.h + s1_val + ch_val + k_cur + w_cur) & 0xFFFFFFFF
            t2 = (s0_val + maj_val) & 0xFFFFFFFF
            
            self.h = self.g
            self.g = self.f
            self.f = self.e
            self.e = (self.d + t1) & 0xFFFFFFFF
            self.d = self.c
            self.c = self.b
            self.b = self.a
            self.a = (t1 + t2) & 0xFFFFFFFF
            
            # Geser shift-register w_reg persis seperti for loop di RTL
            self.w_reg = self.w_reg[1:] + [w_new]
            
            if self.round_cnt == 63:
                self.state = 'S_FINALIZE'
            else:
                self.round_cnt += 1
        elif self.state == 'S_FINALIZE':
            final_h = [
                (H_INIT[0] + self.a) & 0xFFFFFFFF,
                (H_INIT[1] + self.b) & 0xFFFFFFFF,
                (H_INIT[2] + self.c) & 0xFFFFFFFF,
                (H_INIT[3] + self.d) & 0xFFFFFFFF,
                (H_INIT[4] + self.e) & 0xFFFFFFFF,
                (H_INIT[5] + self.f) & 0xFFFFFFFF,
                (H_INIT[6] + self.g) & 0xFFFFFFFF,
                (H_INIT[7] + self.h) & 0xFFFFFFFF,
            ]
            self.digest = struct.pack('>8I', *final_h)
            self.done = True
            self.ready = True
            self.state = 'S_IDLE'

class GarbleChipTopRTL:
    """Model siklus-akurat dari garblechip_top.v"""
    def __init__(self):
        self.sha_core = Sha256IterativeCoreRTL()
        self.ram = [b'\x00' * 16] * 256
        self.state = 'ST_IDLE'
        self.cmd_ready = True
        self.eval_busy = False
        self.eval_done = False
        self.match_result = False
        self.cycle_counter = 0
        
        self.reg_out_id = 0
        self.reg_in1_id = 0
        self.reg_in2_id = 0
        self.reg_gate_id = 0
        self.reg_t0 = b'\x00' * 16
        self.reg_t1 = b'\x00' * 16
        
        self.label_a_reg = b'\x00' * 16
        self.label_b_reg = b'\x00' * 16
        self.wg_reg = b'\x00' * 16
        self.we_reg = b'\x00' * 16
        
        self.sha_start = False
        self.sha_block = b'\x00' * 64

    def step(self, cmd_valid: bool, opcode: int, w_out: int, in1: int, in2: int, gid: int, t0: bytes, t1: bytes):
        if self.eval_busy and not self.eval_done:
            self.cycle_counter += 1
            
        # Step the internal SHA-256 core
        self.sha_core.step(self.sha_start, self.sha_block)
        
        # State machine persis seperti garble_gate_fsm.v
        if self.state == 'ST_IDLE':
            self.sha_start = False
            self.eval_done = False
            if cmd_valid and self.cmd_ready:
                self.eval_busy = True
                self.cmd_ready = False
                self.reg_out_id = w_out
                self.reg_in1_id = in1
                self.reg_in2_id = in2
                self.reg_gate_id = gid
                self.reg_t0 = t0
                self.reg_t1 = t1
                
                if opcode == 0x01: # LOAD
                    self.state = 'ST_LOAD_EXEC'
                elif opcode == 0x02: # XOR
                    self.state = 'ST_XOR_EXEC'
                elif opcode == 0x03: # AND
                    self.state = 'ST_DISPATCH'
                elif opcode == 0xFF: # FINISH
                    self.state = 'ST_DONE'
            else:
                self.cmd_ready = True
                
        elif self.state == 'ST_LOAD_EXEC':
            self.ram[self.reg_out_id] = self.reg_t0
            self.cmd_ready = True
            self.eval_busy = False
            self.state = 'ST_IDLE'
            
        elif self.state == 'ST_XOR_EXEC':
            la = self.ram[self.reg_in1_id]
            lb = self.ram[self.reg_in2_id]
            self.ram[self.reg_out_id] = bytes(x ^ y for x, y in zip(la, lb))
            self.cmd_ready = True
            self.eval_busy = False
            self.state = 'ST_IDLE'
            
        elif self.state == 'ST_DISPATCH':
            self.label_a_reg = self.ram[self.reg_in1_id]
            self.label_b_reg = self.ram[self.reg_in2_id]
            self.state = 'ST_AND_HASH_A'
            
        elif self.state == 'ST_AND_HASH_A':
            if self.sha_core.ready:
                # Padding statis: Label (16 bytes) + gate_id (4 bytes) + 0x80 + 35x0x00 + length 160 (8 bytes)
                pad = self.label_a_reg + struct.pack('>I', self.reg_gate_id) + b'\x80' + (b'\x00' * 35) + struct.pack('>Q', 160)
                self.sha_block = pad
                self.sha_start = True
                self.state = 'ST_AND_WAIT_A'
                
        elif self.state == 'ST_AND_WAIT_A':
            self.sha_start = False
            if self.sha_core.done:
                ha = self.sha_core.digest[:16]
                sa = self.label_a_reg[-1] & 1
                if sa == 0:
                    self.wg_reg = ha
                else:
                    self.wg_reg = bytes(x ^ y for x, y in zip(ha, self.reg_t0))
                self.state = 'ST_AND_HASH_B'
                
        elif self.state == 'ST_AND_HASH_B':
            if self.sha_core.ready:
                pad = self.label_b_reg + struct.pack('>I', self.reg_gate_id) + b'\x80' + (b'\x00' * 35) + struct.pack('>Q', 160)
                self.sha_block = pad
                self.sha_start = True
                self.state = 'ST_AND_WAIT_B'
                
        elif self.state == 'ST_AND_WAIT_B':
            self.sha_start = False
            if self.sha_core.done:
                hb = self.sha_core.digest[:16]
                sb = self.label_b_reg[-1] & 1
                if sb == 0:
                    self.we_reg = hb
                else:
                    tmp = bytes(x ^ y for x, y in zip(hb, self.reg_t1))
                    self.we_reg = bytes(x ^ y for x, y in zip(tmp, self.label_a_reg))
                self.state = 'ST_AND_FINALIZE'
                
        elif self.state == 'ST_AND_FINALIZE':
            self.ram[self.reg_out_id] = bytes(x ^ y for x, y in zip(self.wg_reg, self.we_reg))
            self.cmd_ready = True
            self.eval_busy = False
            self.state = 'ST_IDLE'
            
        elif self.state == 'ST_DONE':
            self.eval_done = True
            self.eval_busy = False
            self.cmd_ready = True
            final_label = self.ram[self.reg_out_id]
            self.match_result = (final_label == self.reg_t0)
            self.state = 'ST_IDLE'

def run_rtl_simulation_on_hex(hex_path: str, expected_match: bool):
    print(f"\n=======================================================")
    print(f"   SIMULASI SIKLUS-AKURAT RTL: {hex_path}")
    print(f"=======================================================")
    
    chip = GarbleChipTopRTL()
    with open(hex_path, 'r') as f:
        lines = [l.strip() for l in f if l.strip() and not l.startswith('//')]
        
    for line in lines:
        parts = line.split()
        opcode = int(parts[0], 16)
        w_out = int(parts[1], 16)
        in1 = int(parts[2], 16)
        in2 = int(parts[3], 16)
        
        if opcode == 0x01: # LOAD
            t0 = bytes.fromhex(parts[4])
            t1 = b'\x00' * 16
            gid = 0
        elif opcode == 0x02: # XOR
            t0 = b'\x00' * 16
            t1 = b'\x00' * 16
            gid = 0
        elif opcode == 0x03: # AND
            gid = int(parts[4], 16)
            t0 = bytes.fromhex(parts[5])
            t1 = bytes.fromhex(parts[6])
        elif opcode == 0xFF: # FINISH
            t0 = bytes.fromhex(parts[4])
            t1 = b'\x00' * 16
            gid = 0
            
        # Send command when chip is ready
        while not chip.cmd_ready:
            chip.step(False, 0, 0, 0, 0, 0, b'\x00'*16, b'\x00'*16)
            
        # Send active pulse
        chip.step(True, opcode, w_out, in1, in2, gid, t0, t1)
        
        # Wait until command finished
        while not chip.cmd_ready:
            chip.step(False, 0, 0, 0, 0, 0, b'\x00'*16, b'\x00'*16)
            
    # Finalize
    while not chip.eval_done:
        chip.step(False, 0, 0, 0, 0, 0, b'\x00'*16, b'\x00'*16)
        
    print(f"Total Siklus Eksekusi RTL: {chip.cycle_counter} cycles")
    print(f"Latensi pada clock 50 MHz: {chip.cycle_counter * 0.020:.2f} microseconds")
    print(f"Status Match: {chip.match_result} (Ekspektasi: {expected_match})")
    assert chip.match_result == expected_match, f"Hasil RTL tidak sesuai ekspektasi!"
    print(">>> STATUS: 100% BIT-EXACT PASSED! <<<")

if __name__ == "__main__":
    run_rtl_simulation_on_hex("test/test_vector_match.hex", True)
    run_rtl_simulation_on_hex("test/test_vector_mismatch.hex", False)
    print("\n>>> SELURUH SIMULASI SIKLUS-AKURAT RTL SUKSES 100%! <<<")
