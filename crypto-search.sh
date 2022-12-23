#!/bin/bash

# Exclude these dependencies that we will check later
EXCLUDE_DIRS="openssl tss-esapi"

# Exclude already checked dependencies that are not used for crypto
CHECKED_DEPS="ahash hashbrown picky-asn1"

INCLUDE_EXTS="*.rs *.c *.cpp *.h"

# The commented list below contains all the keywords tried
#KEYWORDS="aes dsa eddsa ecdsa 3des rsa chacha 25519 sha1 sign encrypt decrypt crypto hash digest private_key public_key privkey pubkey random rng rand symmetric asymmetric"
#
# sha1, digest, hash: only find usages of hash algorithms, which are not
#                   necessarily crypto. Removed for now
#
# random, rand, rng: generates many matches. Probably deserves a separate
#                    investigation. Removed for now
#
# sign, symmetric, asymmetric: too many false positives. Removed for now
#
# 3des, pubkey, eddsa, ecdsa: No occurrences. Removed
#
# privkey: Few occurences, irrelevant. Removed
#
# 25519: false positives only. Removed
KEYWORDS="aes dsa rsa chacha encrypt decrypt crypto private_key public_key openssl tls ssl"

# These prohibited prefixes and suffixes are used to reduce false positives on search
PROHIBITED_PREFIX="un|as|de|ar|ve"
PROHIBITED_SUFFIX="ed|ing|er|al|um|ificant|ificance|ifying|ble|fe|pi|ttempt|glia|ssert|nd|mple|tmon|map|om|y|ess|en|eep|iteral|ast|egacy|oc|ife|e|ve|tate"

# Filter matches with the words on the list below
# test: ignore test files
# example: ignore example files
# apple, freebsd, android, solaris, windows, netbsd, schannel: ignore files used for other systems
PROHIBITED_WORDS="test|examples|apple|freebsd|android|solaris|windows|netbsd|schannel"

xargs=""
for s in $EXCLUDE_DIRS $CHECKED_DEPS; do
    xargs+=" --exclude-dir $s*"
done

for i in $INCLUDE_EXTS; do
    xargs+=" --include $i"
done

OUTDIR="/tmp/crypto-search"
rm -rf $OUTDIR
mkdir -p $OUTDIR

files=""
found=""
for w in $KEYWORDS; do
    found_out="$OUTDIR/$w-found.txt"
    files_out="$OUTDIR/$w-files.txt"
    grep $xargs -rni -P "(?<!($PROHIBITED_PREFIX))$w(?!($PROHIBITED_SUFFIX))" vendor | grep -v -P "$PROHIBITED_WORDS" > $found_out
    found+=" $found_out"
    echo "$w: $(cat $found_out | wc -l) occurrences"
    grep $xargs -rnil -P "(?<!($PROHIBITED_PREFIX))$w(?!($PROHIBITED_SUFFIX))" vendor | grep -v -P "$PROHIBITED_WORDS" > $files_out
    files+=" $files_out"
done

# Store a list of all files with any found crypto
cat $files | sort | uniq > $OUTDIR/all-files.txt
cat $found | sort | uniq > $OUTDIR/all-found.txt

deps_with_crypto="/tmp/crypto-search/deps-with-crypto.txt"
# Extract the list of dependencies where any occurrence of a keyword was found
cat $OUTDIR/all-files.txt | sed -e 's/^[^\/]*\/\([^\/]*\)\/.*/\1/g' | sort | uniq > $deps_with_crypto

rm -rf $OUTDIR/deps
mkdir -p $OUTDIR/deps

# For each dependency that has any occurrence, create a separate file to store
# the matching lines
# Also write the number of occurrences per dependency in a file, sorted by the
# number of occurrences
for i in $(cat $deps_with_crypto); do
    grep "vendor/$i/" "$OUTDIR/all-found.txt" >> "$OUTDIR/deps/$i-found.txt"
    echo "$(cat $OUTDIR/deps/$i-found.txt | wc -l) $i" >> "$OUTDIR/deps-occurrences.txt"
done
sort -n -o "$OUTDIR/deps-occurrences.txt" "$OUTDIR/deps-occurrences.txt"
