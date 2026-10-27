//! The GF(2^128) reference field the protocols share.
use crate::codec::bad;
use std::io::Result;
/// GF(2^128), reduction x^128+x^7+x^2+x+1. This reference arithmetic is
/// functional, not a constant-time implementation for online secret computation.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Field(pub u128);
impl Field {
    pub fn add(self, b: Self) -> Self {
        Self(self.0 ^ b.0)
    }
    pub fn mul(self, b: Self) -> Self {
        let (mut a, mut b, mut z) = (self.0, b.0, 0u128);
        for _ in 0..128 {
            if b & 1 != 0 {
                z ^= a;
            }
            let high = a >> 127;
            a <<= 1;
            if high != 0 {
                a ^= 0x87;
            }
            b >>= 1;
        }
        Self(z)
    }
    pub fn inv(self) -> Result<Self> {
        if self.0 == 0 {
            return Err(bad("zero inverse"));
        }
        let mut x = Self(1);
        let mut a = self;
        let mut e = u128::MAX - 1;
        while e > 0 {
            if e & 1 != 0 {
                x = x.mul(a);
            }
            a = a.mul(a);
            e >>= 1;
        }
        Ok(x)
    }
}
