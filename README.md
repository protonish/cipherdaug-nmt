The official code for our ACL 2022 long paper [CipherDAug: Ciphertext based Data Augmentation for Neural Machine Translation](https://arxiv.org/pdf/2204.00665.pdf).

## Data Prep, Ciphertexts and more
All example scripts are based the IWSLT14 De:arrow_right:En. All the bash scripts are sufficiently annotated for reference. 

You can find the data in the `data` directory. Run the following to unpack the original source-target parallel data.
```
tar -xvzf de-en.tar.gz
```
The compressed tar file `dex-en.tar.gz` contains the ciphertext files from the experiments for reference. Rather than directly unpacking it, follow the procedure below to reproduce/recreate the data.

### Generating ciphertexts from plaintext

The simplest way to generate ciphertexts based on the [python script](cipher/encipher.py) for any input text is
```bash
python cipher/encipher.py -i  path/to/inoput-file --keys a-key-value \
    --char-dict-path path/to/store/char-dictionary/necessary > output/path/and/filename
```

Now, for intended usage and ease of generating named data files, look at the bash script `encipher.sh`. This script is for IWSLT14 De-En but can easily be changed to other lang pairs.
```
bash encipher.sh -s de -t en -x src
```
the `-x` denotes the (src/tgt) side to encipher and we recommend using `-x src` only. Note that `-x tgt` has been removed since the initial phases of the project.

Inside the bash file, you can set the exact keys and splits (train/valid/test) for the ROT-*k* you want. These keys will form the filenames of the enciphered versions of the source.
```bash
KEYS=(1 2 3 4 5) # filenames as {key: suffix} dict := {1: de1, 2: de2, 3: de3, N: deN} etc.
SPLITS=("train" "valid" "test")
```

***Note:*** This will script will produce enciphered version of the relevant data in a directory named `dex-en` (for args -s de -t en -x src). 

### Preprocessing
Note that our preprocessing is slightly different from the standard preprocessing from the [fairseq example](https://github.com/pytorch/fairseq/blob/main/examples/translation/prepare-iwslt14.sh) -- (1) we use sentencepice instead of subword-nmt, and (2) we do NOT use moses to tokenize the data (we do 'clean' it with moses though) as it messes with the process of generating ciphertexts.

For creating parallel data, learning and applying BPEs on all relevant files at once, use the `multi_preprocessing.sh`
```
# bash multi_preprocessing.sh [src] [srcx-tgt]
bash multi_preprocessing.sh de dex-en
```

Then use `multi_binarize.sh` to generate joint multilingual dictionary and binary files for fairseq to use
```
bash multi_binarize.sh
```
## Training and Evaluation based on FairSeq-CipherDAug

[Our adaptation](https://github.com/protonish/fairseq-cipherdaug) of [FairSeq](https://github.com/pytorch/fairseq) is crucial for the working of this codebase. More details on the changes [here](https://github.com/protonish/fairseq-cipherdaug/blob/main/README.md).

### Example training script

`train_cipherdaug.sh` comes loaded with all relevant details to set hyperparameters and start training 
```
bash train_cipherdaug.sh
```

### Example evaluation script

This script generates translations and calculates both multibleu and sacreBLEU scores.
```
# bash gen_and_bleu.sh [split] [src] [tgt]
# split : train/valid/test
# src : de/de1/de2 ; tgt en

bash gen_and_bleu.sh test de en
```

## Cite
Please consider citing us of you find any part of our code or work useful:
```
@inproceedings {kambhatla-etal-2022-cipherdaug,
   abbr="ACL",
   title = "CipherDAug: Ciphertext Based Data Augmentation for Neural Machine Translation",
   author = "Kambhatla, Nishant and
   Born, Logan and
   Sarkar, Anoop",
   booktitle = "Proceedings of the 60th Annual Meeting of the Association for Computational Linguistics: Long Paper (To Appear)",
   month = may,
   year = "2022",
   address = "Online",
   publisher = "Association for Computational Linguistics",
   } 
```
