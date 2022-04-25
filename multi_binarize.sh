#!/bin/bash
LOC='/cs/lab-folder/' # set your root project location
ROOT="${LOC}/username/cipherdaug-nmt"
DATAROOT="${ROOT}/data" # set your data root

DATABIN="${ROOT}/data-bin"

FAIRSEQ="${ROOT}/fairseq"
FAIRSCRIPTS="${FAIRSEQ}/scripts"

dex_en_2keys() {
    SRCS=(
        "de"
        "de1"
        "de2"
    )

    TGTS=(
        "en"
        "de"
    )

    # Preprocess/binarize the data
    TEXT="${DATABIN}/iwslt14/dex_en_2keys"
    mkdir -p "${TEXT}/bin"

    echo "make sure this is the config you want:"
    cat "${TEXT}/data.config.txt"
    echo ""
}


dex_en_5keys() {
    SRCS=(
        "de"
        "de1"
        "de2"
        "de3"
        "de4"
        "de5"
    )

    TGTS=(
        "en"
        "de"
    )

    # Preprocess/binarize the data
    TEXT="${DATABIN}/iwslt14/dex_en_5keys"
    mkdir -p "${TEXT}/bin"

    echo "make sure this is the config you want:"
    cat "${TEXT}/data.config.txt"
    echo ""
}

##############################
#### call the config here ####

dex_en_2keys
#dex_en_5keys


##############################
# best if left untouched

DICT=jointdict.txt

echo "Generating joined dictionary for all languages based on BPE.."
# strip the first three special tokens and append fake counts for each vocabulary
tail -n +4 "${TEXT}/bpe/spm.bpe.vocab" | cut -f1 | sed 's/$/ 100/g' > "${TEXT}/bin/${DICT}"

echo "binarizing pairwise langs .."
for SRC in ${SRCS[@]}; do
    for TGT in ${TGTS[@]}; do
        if [ ! ${SRC} = ${TGT} ]; then
            echo "binarizing data ${SRC}-${TGT} data.."
            fairseq-preprocess --source-lang ${SRC} --target-lang ${TGT} \
                --destdir "${TEXT}/bin" \
                --trainpref "${TEXT}/bpe/train.bpe.${SRC}-${TGT}" \
                --validpref "${TEXT}/bpe/valid.bpe.${SRC}-${TGT}" \
                --testpref "${TEXT}/bpe/test.bpe.${SRC}-${TGT}" \
                --srcdict "${TEXT}/bin/${DICT}" --tgtdict "${TEXT}/bin/${DICT}" \
                --workers 4
        fi
    done
done

echo ""
echo "Creating langs file based on binarised dicts .."
python "${ROOT}/cipher/utils.py" -i "${TEXT}/bin/" --getlangs > "${TEXT}/bin/langs.file"
echo "--> ${TEXT}/bin/langs.file"

