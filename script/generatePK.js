/* eslint-disable @typescript-eslint/restrict-plus-operands */
/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/*
 * alt_bn_128 curve in JavaScript
 * Referenced https://github.com/AztecProtocol/aztec-crypto-js/blob/master/bn128/bn128.js
 */
import crypto from 'crypto';
import { keccak256 } from '@ethersproject/keccak256';
import { defaultAbiCoder } from '@ethersproject/abi';
import BN from 'bn.js';
import EC from 'elliptic';
// AltBn128 field properties
const P = new BN('21888242871839275222246405745257275088696311157297823662689037894645226208583', 10);
const N = new BN('21888242871839275222246405745257275088548364400416034343698204186575808495617', 10);
const A = new BN('5472060717959818805561601436314318772174077789324455915672259473661306552146', 10);
const G = [new BN(1, 10), new BN(2, 10)];
// Convenience Numbers
const bnOne = new BN('1', 10);
const bnTwo = new BN('2', 10);
const bnThree = new BN('3', 10);
// AltBn128 Object
const bn128 = {};
// ECC Curve
bn128.curve = new EC.curve.short({
    a: '0',
    b: '3',
    p: P,
    n: N,
    gRed: false,
    // @ts-expect-error -- FIXME
    g: G,
});
/**
 *  BN.js reduction context for bn128 curve group's prime modulus.
 */
bn128.groupReduction = BN.red(bn128.curve.n);
/**
 * Gets a random Scalar.
 */
bn128.randomScalar = () => {
    return new BN(crypto.randomBytes(32), 16).toRed(bn128.groupReduction);
};
/**
 * Gets a random Point on curve.
 */
bn128.randomPoint = () => {
    const recurse = () => {
        const x = new BN(crypto.randomBytes(32), 16).toRed(bn128.curve.red);
        const y2 = x.redSqr().redMul(x).redIAdd(bn128.curve.b);
        const y = y2.redSqrt();
        if (y.redSqr().redSub(y2).cmp(bn128.curve.a)) {
            return recurse();
        }
        return [x, y];
    };
    return recurse();
};
/**
 *  Returns (beta, y) given x
 *
 *  Beta is used to calculate if the Point exists on the curve
 */
bn128.evalCurve = (x) => {
    const beta = x.mul(x).mod(P).mul(x).mod(P).add(bnThree).mod(P);
    const y = powmod(beta, A, P);
    return [beta, y];
};
/**
 *  Calculates a Point given a Scalar
 */
bn128.scalarToPoint = (_x) => {
    let x = _x.mod(N);
    let beta, y, yP;
    // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
    while (true) {
        [beta, y] = bn128.evalCurve(x);
        yP = y.mul(y).mod(P);
        if (beta.cmp(yP) === 0) {
            return [x, y];
        }
        x = x.add(bnOne).mod(N);
    }
};
/**
 *  ECC addition operation
 */
bn128.ecAdd = (point1, point2) => {
    const p1 = bn128.curve.point(point1[0], point1[1]);
    const p2 = bn128.curve.point(point2[0], point2[1]);
    const fp = p1.add(p2);
    return [fp.getX(), fp.getY()];
};
/**
 * ECC multiplication operation
 */
bn128.ecMul = (p, s) => {
    const fp = bn128.curve.point(p[0], p[1]).mul(s);
    return [fp.getX(), fp.getY()];
};
/**
 * ECC multiplication operation for G
 */
bn128.ecMulG = (s) => {
    return bn128.ecMul(G, s);
};
/**
 * Ring signature generation
 */
bn128.ringSign = (message, publicKeys, secretKey, secretKeyIdx) => {
    const keyCount = publicKeys.length;
    let c = Array(keyCount).fill(new BN(0, 10));
    let s = Array(keyCount).fill(new BN(0, 10));
    // Step 1
    let h = h2(serialize(publicKeys));
    let yTilde = bn128.ecMul(h, secretKey);
    // Step 2
    let u = bn128.randomScalar();
    c[(secretKeyIdx + 1) % keyCount] = h1(serialize([
        publicKeys,
        yTilde,
        message,
        bn128.ecMul(G, u),
        bn128.ecMul(h, u),
    ]));
    // Step 3
    const indexes = Array(keyCount)
        .fill(0)
        .map((_, idx) => idx)
        .slice(secretKeyIdx + 1, keyCount)
        .concat(Array(secretKeyIdx)
        .fill(0)
        .map((_x, _idx) => _idx));
    let z1, z2;
    indexes.forEach((i) => {
        s[i] = bn128.randomScalar();
        z1 = bn128.ecAdd(bn128.ecMul(G, s[i]), bn128.ecMul(publicKeys[i], c[i]));
        z2 = bn128.ecAdd(bn128.ecMul(h, s[i]), bn128.ecMul(yTilde, c[i]));
        c[(i + 1) % keyCount] = h1(serialize([publicKeys, yTilde, message, z1, z2]));
    });
    // Step 4
    const sci = secretKey.mul(c[secretKeyIdx]).mod(N);
    s[secretKeyIdx] = u.sub(sci);
    // JavaScript negative modulo bug -_-
    // @ts-expect-error
    if (s[secretKeyIdx] < 0) {
        s[secretKeyIdx] = s[secretKeyIdx].add(N);
    }
    s[secretKeyIdx] = s[secretKeyIdx].mod(N);
    return [c[0], s, yTilde];
};
/**
 *  Ring signature verification
 */
bn128.ringVerify = (message, publicKeys, signature) => {
    const keyCount = publicKeys.length;
    const [c0, s, yTilde] = signature;
    let c = c0.clone();
    // Step 1
    const h = h2(serialize(publicKeys));
    let z1, z2;
    for (let i = 0; i < keyCount; i++) {
        z1 = bn128.ecAdd(bn128.ecMul(G, s[i]), bn128.ecMul(publicKeys[i], c));
        z2 = bn128.ecAdd(bn128.ecMul(h, s[i]), bn128.ecMul(yTilde, c));
        if (i < keyCount - 1) {
            c = h1(serialize([publicKeys, yTilde, message, z1, z2]));
        }
    }
    return c0.cmp(h1(serialize([publicKeys, yTilde, message, z1, z2]))) === 0;
};
/* Helper Functions */
/**
 *  Efficient powmod implementation.
 *
 *  Reference: https://gist.github.com/HarryR/a6d56a97ba7f1a4ebc43a40ca0f34044#file-longsigh-py-L26
 *  Returns (a^b) % n
 */
const powmod = (a, b, n) => {
    let c = new BN('0', 10);
    let f = new BN('1', 10);
    // @ts-expect-error
    let k = new BN(parseInt(Math.log(b) / Math.log(2)), 10);
    let shiftedK;
    // @ts-expect-error
    while (k >= 0) {
        c = c.mul(bnTwo);
        f = f.mul(f).mod(n);
        // @ts-expect-error
        shiftedK = new BN('1' + '0'.repeat(k), 2);
        // @ts-expect-error
        if (b.and(shiftedK) > 0) {
            c = c.add(bnOne);
            f = f.mul(a).mod(n);
        }
        k = k.sub(bnOne);
    }
    return f;
};
/**
 * Returns a Scalar repreesntation of the hash of the input.
 */
const h1 = (s) => {
    // Want to be compatible with the solidity implementation
    // which prepends "0x" by default
    if (s.indexOf('0x') !== 0) {
        s = '0x' + s;
    }
    const h = keccak256(s).slice(2); // Remove the "0x"
    const b = new BN(h, 16);
    return b.mod(N);
};
/**
 * Returns ECC Point of the Scalar representation of the hash
 * of the input.
 */
const h2 = (hexStr) => {
    // Note: hexStr should be a string in hexadecimal format!
    return bn128.scalarToPoint(h1(hexStr));
};
/**
 * Serializes the inputs into a hex string
 */
const serialize = (arr) => {
    if (!Array.isArray(arr)) {
        // eslint-disable-next-line no-throw-literal
        throw 'arr should be of type array';
    }
    return arr.reduce((acc, x) => {
        if (typeof x === 'string') {
            acc = acc + Buffer.from(x).toString('hex');
        }
        else if (Array.isArray(x)) {
            acc = acc + serialize(x);
        }
        else if (Buffer.isBuffer(x)) {
            acc = acc + x.toString('hex');
        }
        else if (x.getX !== undefined && x.getY !== undefined) {
            // Point
            acc = acc + x.getX().toString(16).padStart(64, '0');
            acc = acc + x.getY().toString(16).padStart(64, '0');
        }
        else if (x.toString !== undefined) {
            acc = acc + x.toString(16).padStart(64, '0');
        }
        return acc;
    }, '');
};

export { bn128, powmod, h1, h2, serialize };



/**
 * (2)
 */

import { hexlify } from '@ethersproject/bytes';
import { randomBytes } from '@ethersproject/random';
import { BigNumber } from 'ethers';

function getDepositPKForTargetAddress(targetAddress) {
  const randomSk = hexlify(randomBytes(32));
  const stealthSk = h1(serialize([randomSk, targetAddress]));

  return (bn128.ecMulG(stealthSk)).map((x) => '0x' + x.toString(16));
}

function encodeToAbi(rawData) {
    const properlyFormattedData = [
      BigNumber.from(rawData[0]),
      BigNumber.from(rawData[1])
    ];

  
    const encodedData = defaultAbiCoder.encode(
      ['uint256', 'uint256'],
      properlyFormattedData,
    );
    return encodedData;
  }
  
  const rawData = getDepositPKForTargetAddress('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
  const abiEncoded = encodeToAbi(rawData);
  
console.log(process.argv);

  process.stdout.write(abiEncoded);