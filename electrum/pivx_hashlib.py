#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import bitcoin
import hashlib

from constants import WIF_PREFIX, MAGIC_BYTE, TESTNET_WIF_PREFIX, TESTNET_MAGIC_BYTE
from pivx_b58 import b58encode, b58decode

def double_sha256(data):
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()



def single_sha256(data):
    return hashlib.sha256(data).digest()



def generate_privkey(isTestnet=False):
    """
    Based on Andreas Antonopolous work from 'Mastering Bitcoin'.
    """
    base58_secret = TESTNET_WIF_PREFIX if isTestnet else WIF_PREFIX
    valid = False
    privkey = 0
    while not valid:
        privkey = bitcoin.random_key()
        decoded_private_key = bitcoin.decode_privkey(privkey, 'hex')
        valid = 0 < decoded_private_key < bitcoin.N
    data = bytes([base58_secret]) + bytes.fromhex(privkey)
    checksum = bitcoin.bin_dbl_sha256(data)[0:4]
    return b58encode(data + checksum)



def pubkey_to_address(pubkey, isTestnet=False):
    pubkey_bin = bytes.fromhex(pubkey)
    pkey_hash = bitcoin.bin_hash160(pubkey_bin)
    return pubkeyhash_to_address(pkey_hash, isTestnet)



def pubkeyhash_to_address(pkey_hash, isTestnet=False):
    base58_pubkey = TESTNET_MAGIC_BYTE if isTestnet else MAGIC_BYTE
    data = bytes([base58_pubkey]) + pkey_hash
    checksum = bitcoin.bin_dbl_sha256(data)[0:4]
    return b58encode(data + checksum)




def wif_to_privkey(string):
    wif_compressed = 52 == len(string)
    pvkeyencoded = b58decode(string).hex()
    wifversion = pvkeyencoded[:2]
    checksum = pvkeyencoded[-8:]
    vs = bytes.fromhex(pvkeyencoded[:-8])
    check = double_sha256(vs)[0:4]

    if (wifversion == WIF_PREFIX.to_bytes(1, byteorder='big').hex() and checksum == check.hex()) \
    or (wifversion == TESTNET_WIF_PREFIX.to_bytes(1, byteorder='big').hex() and checksum == check.hex()):

        if wif_compressed:
            privkey = pvkeyencoded[2:-10]

        else:
            privkey = pvkeyencoded[2:-8]

        return privkey

    else:
        return None
