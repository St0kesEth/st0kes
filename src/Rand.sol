// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// A standard normal from twelve summed 21-bit uniforms, packed into one keccak.
library Rand {
    function normal(uint256 seed, uint256 p, uint256 t) internal pure returns (int256 z) {
        assembly ("memory-safe") {
            mstore(0x00, seed)
            mstore(0x20, or(shl(32, p), t))
            let h := keccak256(0x00, 0x40)
            let m := 0x1FFFFF
            let s := and(h, m)
            s := add(s, and(shr(21, h), m))    s := add(s, and(shr(42, h), m))
            s := add(s, and(shr(63, h), m))    s := add(s, and(shr(84, h), m))
            s := add(s, and(shr(105, h), m))   s := add(s, and(shr(126, h), m))
            s := add(s, and(shr(147, h), m))   s := add(s, and(shr(168, h), m))
            s := add(s, and(shr(189, h), m))   s := add(s, and(shr(210, h), m))
            s := add(s, and(shr(231, h), m))
            z := sdiv(mul(sub(s, mul(6, m)), 1000000000000000000), shl(21, 1))
        }
    }
}
