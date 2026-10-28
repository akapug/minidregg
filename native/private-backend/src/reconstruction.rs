//! The GF(2^128) reference field the protocols share.
use crate::codec::bad;
use std::io::Result;
/// GF(2^128), reduction x^128+x^7+x^2+x+1. This reference arithmetic is
/// functional, not a constant-time implementation for online secret computation.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Field(pub u128);
impl zeroize::Zeroize for Field {
    fn zeroize(&mut self) {
        self.0.zeroize();
    }
}
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
/// The Lagrange basis weight of node `k` at `t` over `xs`: the product over
/// j != k of (t - x_j) / (x_k - x_j). The field has characteristic 2, so
/// subtraction is addition. Refuses (rather than panics) on a repeated node.
pub fn lagrange(xs: &[Field], k: usize, t: Field) -> Result<Field> {
    let (mut num, mut den) = (Field(1), Field(1));
    for (j, x) in xs.iter().enumerate() {
        if j != k {
            num = num.mul(t.add(*x));
            den = den.mul(xs[k].add(*x));
        }
    }
    Ok(num.mul(den.inv()?))
}
fn nodes<V>(points: &[(u16, V)]) -> Vec<Field> {
    points.iter().map(|(h, _)| Field(*h as u128 + 1)).collect()
}
/// The vector-valued interpolation at `at` of the points `(holder, values)`
/// placed at x = holder + 1, each of `count` components.
pub fn interpolate_at<V: AsRef<[Field]>>(
    points: &[(u16, V)],
    at: Field,
    count: usize,
) -> Result<Vec<Field>> {
    let xs = nodes(points);
    let mut out = vec![Field(0); count];
    for (i, (_, values)) in points.iter().enumerate() {
        let values = values.as_ref();
        if values.len() != count {
            return Err(bad("point vector"));
        }
        let weight = lagrange(&xs, i, at)?;
        for (o, v) in out.iter_mut().zip(values) {
            *o = o.add(weight.mul(*v));
        }
    }
    Ok(out)
}
/// The coefficient vectors (lowest degree first), one per component, of the
/// polynomials through the points `(holder, values)` placed at x = holder + 1.
pub fn polynomial<V: AsRef<[Field]>>(
    points: &[(u16, V)],
    count: usize,
) -> Result<Vec<Vec<Field>>> {
    let xs = nodes(points);
    let mut out = vec![vec![Field(0); points.len()]; count];
    for (i, (_, values)) in points.iter().enumerate() {
        let values = values.as_ref();
        if values.len() != count {
            return Err(bad("polynomial vector"));
        }
        let mut basis = vec![Field(1)];
        let mut denominator = Field(1);
        for (j, xj) in xs.iter().enumerate() {
            if i != j {
                denominator = denominator.mul(xs[i].add(*xj));
                let mut next = vec![Field(0); basis.len() + 1];
                for (k, c) in basis.iter().enumerate() {
                    next[k] = next[k].add(c.mul(*xj));
                    next[k + 1] = next[k + 1].add(*c);
                }
                basis = next;
            }
        }
        let inverse = denominator.inv()?;
        for (row, value) in out.iter_mut().zip(values) {
            let scale = value.mul(inverse);
            for (slot, c) in row.iter_mut().zip(&basis) {
                *slot = slot.add(c.mul(scale));
            }
        }
    }
    Ok(out)
}
