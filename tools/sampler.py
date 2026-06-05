"""How many hashes to build one normal draw?

Twelve uniforms summed gives an approximate standard normal (Irwin-Hall).
The obvious wiring takes two hashes; twelve 21-bit fields fit in one keccak
output. This script generates the sample and inspects the moments."""
import hashlib, statistics as st
def uniforms_two(seed, i):
    a = int.from_bytes(hashlib.sha256(f"{seed}:{i}:0".encode()).digest(), "big")
    b = int.from_bytes(hashlib.sha256(f"{seed}:{i}:1".encode()).digest(), "big")
    us = []
    m = (1 << 21) - 1
    for j in range(6):
        us.append(((a >> (j*21)) & m) / (1 << 21))
        us.append(((b >> (j*21)) & m) / (1 << 21))
    return us
def uniforms_one(seed, i):
    h = int.from_bytes(hashlib.sha256(f"{seed}:{i}".encode()).digest(), "big")
    m = (1 << 21) - 1
    return [((h >> (j*21)) & m) / (1 << 21) for j in range(12)]
def moments(fn):
    xs = [sum(fn(0, i)) - 6 for i in range(50000)]
    return st.mean(xs), st.pstdev(xs)
print("two hashes:", moments(uniforms_two))
print("one hash:  ", moments(uniforms_one))
