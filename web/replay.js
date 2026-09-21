// The contract's walk in JavaScript, so a browser can replay a quote to the wei
// from the spot, variance and seed the quote returned. tools/replay.py is the
// same arithmetic in Python; test/Live.fork.t.sol wrote the numbers both are
// checked against. Division of a negative number truncates toward zero, as in
// the EVM; every other division is of non-negative numbers and floors.
const ONE = 10n ** 18n, MASK = 0x1FFFFFn, E = 2718281828459045235n;

const sdiv = (a, b) => { const q = (a < 0n ? -a : a) / (b < 0n ? -b : b); return (a >= 0n) === (b > 0n) ? q : -q; };

function normal(k256, seed, p, t) {
  const buf = new Uint8Array(64);
  let s = seed; for (let i = 31; i >= 0; i--) { buf[i] = Number(s & 0xFFn); s >>= 8n; }
  let v = (BigInt(p) << 32n) | BigInt(t); for (let i = 63; i >= 32; i--) { buf[i] = Number(v & 0xFFn); v >>= 8n; }
  const h = BigInt("0x" + k256(buf));
  let sum = 0n; for (let i = 0; i < 12; i++) sum += (h >> BigInt(21 * i)) & MASK;
  return sdiv((sum - 6n * MASK) * ONE, 1n << 21n);
}

function isqrt(x) { if (x === 0n) return 0n; let y = x, k = (x >> 1n) + 1n; while (k < y) { y = k; k = (x / k + k) >> 1n; } return y; }
const root = (x) => (x ? isqrt(x * ONE) : 0n);
function warm(x, g) { if (x === 0n) return 0n; const n = x * ONE; let y = g || x; for (let i = 0; i < 5; i++) y = (y + n / y) >> 1n; return y; }
function exp_(x) {
  if (x < -40n * ONE) return 0n;
  const ax = x < 0n ? -x : x, n = ax / ONE, fr = ax % ONE;
  let term = ONE, ef = ONE;
  for (let i = 1n; i <= 12n; i++) { term = term * fr / (ONE * i); ef += term; if (term === 0n) break; }
  let en = ONE; for (let i = 0n; i < n; i++) en = en * E / ONE;
  const r = en * ef / ONE;
  return x < 0n ? ONE * ONE / r : r;
}

/** Replays the at-the-money average-price call. k256 maps bytes to a hex digest. */
export function replay(k256, { spot, varStep, omega, alpha, beta, seed, steps, every, paths }) {
  const sd0 = root(varStep), marks = BigInt(Math.floor(steps / every));
  const pays = [], series = [];
  for (let p = 0; p < paths; p++) {
    let v = varStep, sd = sd0, logS = 0n, acc = 0n; const path = [];
    for (let t = 0; t < steps; t++) {
      const r = sdiv(sd * normal(k256, seed, p, t), ONE);
      logS += r - v / 2n;
      v = omega + alpha * sdiv(r * r, ONE) / ONE + beta * v / ONE;
      sd = warm(v, sd);
      const e = exp_(logS);
      path.push(Number(spot * e / ONE) / 1e18);
      if ((t + 1) % every === 0) acc += e;
    }
    const avg = spot * (acc / marks) / ONE;
    pays.push(avg > spot ? avg - spot : 0n); series.push(path);
  }
  const n = BigInt(paths); let sum = 0n, e2 = 0n;
  for (const x of pays) { sum += x; e2 += x * x; }
  const mean = sum / n, m2 = mean * mean; e2 /= n;
  const vr = e2 > m2 ? (e2 - m2) * n / (n - 1n) : 0n;
  return { mean, se: isqrt(vr / n), series, pays };
}
