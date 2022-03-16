The official code for the paper **CipherDAug: Ciphertext based Data Augmentation for Neural Machine Translation** published at ACL 2022 main conference.


# Generating ciphertexts from plaintext

The simplest example to generate ciphertexts based on the [python script](cipher/encipher.py) would be
```
python cipher/encipher.py -i  path/to/inoput-file --keys a-key-value \
    --char-dict-path path/to/store/char-dictionary/necessary > output/path/and/filename
```

For intended usage and ease of generting named data files, look at the bash script `encipher.sh`. This script is for IWSLT14 De-En but can easily be changed to other lang pairs.
```
bash encipher.sh -s de -t en -x src
```
the `-x` denotes the (src/tgt) side to encipher and we recommend using `-x src` only. Note that `-x tgt` hasn't been tested since the initial phases of the project.

# CipherDAug fork of FairSeq

[Our adaptation](fairseq-cipherdaug) of [FairSeq](https://github.com/pytorch/fairseq) is crucial for the working of this codebase. More details on that [here](fairseq-cipherdaug/README.md).
