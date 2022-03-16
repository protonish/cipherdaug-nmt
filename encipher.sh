LOC='/cs/lab-folder/' # set your root project location
# LOC='/local-scratch'
ROOT="${LOC}/username/cipherdaug-nmt"
DATAROOT="${ROOT}/data/iwslt14" # set your data root


# specify SRC and TGT data to locate data folder
# specify side

DEF_SIDE="src"

while getopts "s:t:x:" FLAG; do
    case "${FLAG}" in
        s) SRC=${OPTARG};;
        t) TGT=${OPTARG};;
        x) SIDE=${OPTARG};;
        # f) SPLITT=${OPTARG};;
    esac
done

if [ ! ${#SRC} -gt 0 ]; then
    echo "-s arg must be provided"
    echo "usage: bash encipher.sh -s de -t en -x src" # -f train"
    exit 1
fi

if [ ! ${#TGT} -gt 0 ]; then
    echo "-t arg must be provided"
    echo "usage: bash encipher.sh -s de -t en -x src" # -f train"
    exit 1
fi

# if [ ! ${#SPLITT} -gt 0 ]; then
#     echo "-f (split) arg must be provided"
#     echo "usage: bash encipher.sh -s de -t en -x src -f train"
#     exit 1
# fi

if [ ! ${#SIDE} -gt 0 ]; then
    echo "warning: -x (side) arg not provided: should be either 'src' or 'tgt'"
    echo "usage: bash encipher.sh -src de -tgt en -side src" # -f train"
    echo "default fallback to 'src'"
    SIDE=$DEF_SIDE
fi

#####################################
###### cipher naming convention #####
#####################################
# for each src lang, create a
# corresponding cipher dir "srcx"
# src = de; -> cipher = dex
# replace x with the key
# e.g; de -- keys [2,3]
# output --> de2, de3

####### don't change this ###########
## multiling train depends on this ##
#####################################

KEYS=(1 2 3 4 5)
SPLITS=("train" "valid" "test")

ENCIPHER="${ROOT}/cipher/encipher.py"

for KEY in "${KEYS[@]}"; do

    for SPLIT in "${SPLITS[@]}"; do

        # infer input and output filenames
        if [ ${SIDE} = "src" ]; then
            echo "-x (side) : 'src'"
            SELF_OUT="${DATAROOT}/${SRC}x-${TGT}"
            OUT_DIR="${DATAROOT}/${SRC}x-${TGT}"
            mkdir -p ${SELF_OUT} ${OUT_DIR}

            FILE="${SPLIT}.${SRC}-${TGT}.${SRC}"
            CIPHER="${SPLIT}.${SRC}${KEY}-${TGT}.${SRC}${KEY}"
            # the parallel side of input file
            PARL="${SPLIT}.${SRC}-${TGT}.${TGT}"
            COPY_PARL="${SPLIT}.${SRC}${KEY}-${TGT}.${TGT}"
            # self copy [dex - de automatically]
            SELF_SRC="${OUT_DIR}/${CIPHER}"
            SELF_TGT="${DATAROOT}/${SRC}-${TGT}/${FILE}"
            COPY_SELF_SRC="${SPLIT}.${SRC}${KEY}-${SRC}.${SRC}${KEY}"
            COPY_SELF_TGT="${SPLIT}.${SRC}${KEY}-${SRC}.${SRC}"

        elif [ ${SIDE} = "tgt" ]; then
            echo "-x (side) : 'tgt'"
            # SELF_OUT="${DATAROOT}/${TGT}/${TGT}x"
            # OUT_DIR="${DATAROOT}/${SRC}/${TGT}x"
            # mkdir -p ${SELF_OUT} ${OUT_DIR}

            # FILE="${SPLIT}.${SRC}-${TGT}.${TGT}"
            # CIPHER="${SPLIT}.${SRC}-${TGT}${KEY}.${TGT}${KEY}"
            # # the parallel side of input file
            # PARL="${SPLIT}.${SRC}-${TGT}.${SRC}"
            # COPY_PARL="${SPLIT}.${SRC}-${TGT}${KEY}.${SRC}"
            # # self copy [de - dex automatically]
            # SELF_SRC="${DATAROOT}/${SRC}/${TGT}/${FILE}"
            # SELF_TGT="${OUT_DIR}/${CIPHER}"
            # COPY_SELF_SRC="${SPLIT}.${TGT}-${TGT}${KEY}.${TGT}"
            # COPY_SELF_TGT="${SPLIT}.${TGT}-${TGT}${KEY}.${TGT}${KEY}"

        fi

        if [ ! -f "${OUT_DIR}/${CIPHER}" ]; then
            echo ""
            echo "Generating ** ${SPLIT} ** ${SRC}-${TGT} ${SIDE} cipher .."
            # generate cipher data for specified input
            python ${ENCIPHER} -i  "${DATAROOT}/${SRC}-${TGT}/${FILE}" --keys $KEY \
                --char-dict-path "${DATAROOT}/${SRC}-${TGT}/chardict.train.${SRC}" > "${OUT_DIR}/${CIPHER}"

            echo "Generating real parallel data for cipher .."
            # generate parallel data by copying
            cat "${DATAROOT}/${SRC}-${TGT}/${PARL}" >  "${OUT_DIR}/${COPY_PARL}"

            echo "Generating self parallel data for cipher .."
            # generate self parallel data by copying
            cat "${SELF_SRC}" > "${SELF_OUT}/${COPY_SELF_SRC}"
            cat "${SELF_TGT}" > "${SELF_OUT}/${COPY_SELF_TGT}"

            echo "Done!"

        else
            echo "Found ${SRC}-${TGT} ${SIDE} - ${KEY} cipher. Not generating!"
        fi

    done
done

echo
echo "Check dirs:"
echo "${OUT_DIR}"
echo "${SELF_OUT}"
