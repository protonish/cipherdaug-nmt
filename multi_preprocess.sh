#!/bin/bash
# LOC='/home'    # lab machine
LOC='/path/to/your/folder' # set your root project location
ROOT="${LOC}/user/cipherdaug-nmt"
DATAROOT="${ROOT}/data/iwslt14" # set your data root

DATABIN="${ROOT}/data-bin/iwslt14"
mkdir -p $DATABIN

FAIRSEQ="${ROOT}/fairseq-cipherdaug"
FAIRSCRIPTS="${FAIRSEQ}/scripts"

#####################
#### REAL  LANGS ####
#####################
SRCS=(
    "de"
    )
TGTS=(
    "en"
    )

#####################
### CIPHER  LANGS ###
#####################
CIPHER_LANGS=(
    "dex"
    )

CIPHER_SRCS=(
    "de1"
    "de2"
)

CIPHER_TGTS=(
    "de"
    "en"
)
KEYS=(1 2)

#####################
### SPM Parameters ##
#####################
SPM_TRAIN="${FAIRSCRIPTS}/spm_train.py"
SPM_ENCODE="${FAIRSCRIPTS}/spm_encode.py"

SUBWORD_TYPE="bpe"
BPESIZE=16000
TRAIN_MAXLEN=500

#####################
# join all SRC and TGT arrays for further preprocessing 

# source langs
# Declare an associative array
T=(${SRCS[@]} ${CIPHER_SRCS[@]})
declare -A TEMP_SRCS
# Store the values of arr3 in arr4 as keys.
for k in "${T[@]}"; do TEMP_SRCS["$k"]=1; done
# Extract the keys.
ALL_SRCS=("${!TEMP_SRCS[@]}")

# target langs
T=(${TGTS[@]} ${CIPHER_TGTS[@]})
declare -A TEMP_TGTS
# Store the values of arr3 in arr4 as keys.
for k in "${T[@]}"; do TEMP_TGTS["$k"]=1; done
# Extract the keys.
ALL_TGTS=("${!TEMP_TGTS[@]}")

#####################

PRIMARY=$1
echo "${PRIMARY}"

if [ ! ${#PRIMARY} -gt 0 ]; then
    echo "PRIMARY can not be empty. This is just a check to ensure you know the source language you want to encipher."
    echo "USAGE: bash multi_preprocess.sh de [dest_folder]"
    exit 1
fi

if [ ${#2} -gt 0 ]; then
    echo "Destination Input: $2"
    echo "Setting destination directory to $2 .."
    DEST="${DATABIN}/${2}"
    mkdir -p $DEST/bpe
else
	echo "Destination folder must be set."
	echo "try this USAGE: bash multi_preprocess.sh [src lang to encipher] [dest_folder]"
fi

# summarizes the final data config for record keeping
get_config() {
    echo "SRCS = ${SRCS[@]} | TGTS = ${TGTS[@]} | CIPHER_LANGS = ${CIPHER_LANGS[@]} | CIPHER_SRCS = ${CIPHER_SRCS[@]} | CIPHER_TGTS = ${CIPHER_TGTS[@]} | PRIMARY_SRC = ${PRIMARY} | DEST_DIR = "${DEST}" | BPESIZE = ${BPESIZE}"
}

echo "Saving data config to $DEST"
get_config > "${DEST}/data.config.txt"

#####################

# 1. copy relevant data files from DATAROOT to DATA-BIN
#    'data-bin' is the working directory for experimentr data
#    'data' is the original data-store; don't touch it.
copy() {

    for SRC in ${SRCS[@]}; do
        for TGT in ${TGTS[@]}; do
            if [ ! -f "${DEST}/train.${SRC}-${TGT}.${TGT}" ]; then
                echo "Copying ${SRC} and ${TGT} data .."
                cp "${DATAROOT}/${SRC}-${TGT}/"*".${SRC}-${TGT}."* "${DEST}"

                echo "Done Copying!"
            else
                echo "Found ${SRC} and ${TGT} data .."
            fi
        done
    done

    for CIPHER_DIR in ${CIPHER_LANGS[@]}; do
        for TGT in ${TGTS[@]}; do
            CIPHER_DIRECTORY="${CIPHER_DIR}-${TGT}"
        done
    done

    if [ ${#CIPHER_LANGS[@]} -gt 0 ]; then
        echo "Copying cipher files .."
        for CIPHER_DIR in ${CIPHER_LANGS[@]}; do
            for SRC in ${CIPHER_SRCS[@]}; do
                for TGT in ${CIPHER_TGTS[@]}; do
                    if [ ! -f "${DEST}/train.${SRC}-${TGT}.${TGT}" ]; then
                        echo "Copying ${SRC} and ${TGT} data .."
                        cp "${DATAROOT}/${CIPHER_DIRECTORY}/"*".${SRC}-${TGT}."* "${DEST}"

                        echo "Done Copying!"
                    else
                        echo "Found ${SRC} and ${TGT} data at ${DEST} .."
                    fi
                done
            done
        done
    fi

}

# 2. Optionally, apply SWAP_OUT : randomly swaps out tokens in the source text.
#    'data-bin' is the working directory for experimentr data
#    'data' is the original data-store; don't touch it.

swapout_self(){
    PROB=$1

    if (( ! $(echo "${PROB} > 0.0" |bc -l) )); then
    # if [ ! ${PROB} -gt 0.0 ]; then
        echo "PROB must be greater than 0."
        echo "function usage: swapout [prob value]"
        exit 1
    fi

    if [ ${#CIPHER_LANGS[@]} -gt 0 ]; then
        echo "Applying SWAPOUT to cipher files .."
            for SRC in ${SRCS[@]}; do
                for KEY in ${KEYS[@]}; do
                    # for TGT in ${CIPHER_TGTS[@]}; do
                        # adding a check to avoid swapping existing file
                        if [ -f "${DEST}/train.swap.${SRC}${KEY}-${SRC}.${SRC}${KEY}" ]; then
                            echo "swap file exists: train.swap.${SRC}${KEY}-${SRC}.${SRC}${KEY} !"
                        else
                            if [ -f "${DEST}/train.${SRC}${KEY}-${SRC}.${SRC}${KEY}" ]; then 
                                echo ""
                                echo "Swapping ${SRC}${KEY} data .."
                                python cipher/utils.py --swapout -i "${DEST}/train.${SRC}${KEY}-${SRC}.${SRC}${KEY}" \
                                --original "${DEST}/train.${SRC}${KEY}-${SRC}.${SRC}" --prob ${PROB} \
                                > "${DEST}/train.swap.${SRC}${KEY}-${SRC}.${SRC}${KEY}"

                                if [ ! $(wc -l < "${DEST}/train.swap.${SRC}${KEY}-${SRC}.${SRC}${KEY}") -eq \
                                $(wc -l < "${DEST}/train.${SRC}${KEY}-${SRC}.${SRC}${KEY}") ]; then
                                    echo "Cipher and Swapped file lengths do not match!"
                                    exit 1
                                else
                                    echo "Changing contents of ciphertext with swapped ciphertext."
                                    cat "${DEST}/train.swap.${SRC}${KEY}-${SRC}.${SRC}${KEY}" > "${DEST}/train.${SRC}${KEY}-${SRC}.${SRC}${KEY}"
                                fi

                                echo "SwapOut Applied!"

                            fi
                        fi

                        
                        
                    # done
                done
            done
    fi

}

# 3. learn BPE with sentencepiece
learn_bpe(){
    RAW_TRAIN_FILES=$(
        for SRC in "${ALL_SRCS[@]}"; do 
            for TGT in "${ALL_TGTS[@]}"; do
                if [ ! ${SRC} = ${TGT} ]; then 
                    echo $DEST/train.${SRC}-${TGT}.${SRC}; echo $DEST/train.${SRC}-${TGT}.${TGT};
                fi
            done 
        done | tr "\n" ",")


    TRAIN_FILES="$(python ${ROOT}/cipher/utils.py -i ${RAW_TRAIN_FILES} --dedup )"

    echo "learning joint BPE over ${TRAIN_FILES} .."

    python "${SPM_TRAIN}" \
        --input=${TRAIN_FILES} \
        --model_prefix="${DEST}/bpe/spm.${SUBWORD_TYPE}" \
        --vocab_size=${BPESIZE} \
        --character_coverage=1.0 \
        --model_type="${SUBWORD_TYPE}"
}

######################################
# 4. Optionally, call functions here #
######################################

copy
# swapout_self 0.2
learn_bpe



###################################
# 5. apply BPE to train/valid/test
#    encode train/valid
echo "encoding train data with learned BPE..."
for SRC in "${ALL_SRCS[@]}"; do
    for TGT in "${ALL_TGTS[@]}"; do
        if [ ! ${SRC} = ${TGT} ]; then
            python "${SPM_ENCODE}" \
                --model "${DEST}/bpe/spm.${SUBWORD_TYPE}.model" \
                --output_format=piece \
                --inputs "${DEST}/train.${SRC}-${TGT}.${SRC}" "${DEST}/train.${SRC}-${TGT}.${TGT}" \
                --outputs "${DEST}/bpe/train.bpe.${SRC}-${TGT}.${SRC}" "${DEST}/bpe/train.bpe.${SRC}-${TGT}.${TGT}" \
                --min-len 1 --max-len "${TRAIN_MAXLEN}"
        fi
    done
done

echo "encoding valid data with learned BPE..."
for SRC in "${ALL_SRCS[@]}"; do
    for TGT in "${ALL_TGTS[@]}"; do
        if [ ! ${SRC} = ${TGT} ]; then
            python "${SPM_ENCODE}" \
                --model "${DEST}/bpe/spm.${SUBWORD_TYPE}.model" \
                --output_format=piece \
                --inputs "${DEST}/valid.${SRC}-${TGT}.${SRC}" "${DEST}/valid.${SRC}-${TGT}.${TGT}" \
                --outputs "${DEST}/bpe/valid.bpe.${SRC}-${TGT}.${SRC}" "${DEST}/bpe/valid.bpe.${SRC}-${TGT}.${TGT}" \
                --min-len 1 --max-len "${TRAIN_MAXLEN}"

        fi

    done
done

echo "encoding test data with learned BPE ..."
for SRC in "${ALL_SRCS[@]}"; do
    for TGT in "${ALL_TGTS[@]}"; do
        if [ ! ${SRC} = ${TGT} ]; then
            python "${SPM_ENCODE}" \
                --model "${DEST}/bpe/spm.${SUBWORD_TYPE}.model" \
                --output_format=piece \
                --inputs "${DEST}/test.${SRC}-${TGT}.${SRC}" "${DEST}/test.${SRC}-${TGT}.${TGT}" \
                --outputs "${DEST}/bpe/test.bpe.${SRC}-${TGT}.${SRC}" "${DEST}/bpe/test.bpe.${SRC}-${TGT}.${TGT}" \
                --min-len 1 --max-len "${TRAIN_MAXLEN}"
        fi
    done
done

echo ""
echo "Finished encoding train/valid/test with Sentencepiece ${SUBWORD_TYPE} ."
get_config
# echo "|- ${SUBWORD_TYPE} - ${BPESIZE}" > "${DEST}/bpe/sp.log"
echo "Dir: ${DEST}/bpe"
