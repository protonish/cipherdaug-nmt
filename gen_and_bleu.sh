# LOC='/cs/lab-machine' # set your root project location
LOC='/local-scratch'
# LOC='/home'    # jarvis machine
ROOT="${LOC}/user/cipherdaug-nmt"
DATAROOT="${ROOT}/data" # set your data root

DATABIN="${ROOT}/data-bin"

FAIRSEQ="${ROOT}/fairseq"

# data directory containing train, valid and test splits
DATA="${DATABIN}/de-en"  # always use ordered bpe data for tests; 
# remember what happened in multisub exp; binary test sets are a pain in the neck.

# SRC="de"
# TGT="en"

# experiment identifier; this becomes a dir in checkpoints and experiments folders
EXPTNAME="baseline"
RUN="#0"

# paths to checkpoints and experiments directories
CKPTDIR="checkpoints/${EXPTNAME}"
EXPTDIR="experiments/${EXPTNAME}"

CKPT="checkpoint_best.pt"

# GEN="test" # valid0 valid1 test

GEN=$1
SRC=$2
TGT=$3

LANG_PAIRS="de-en"
LANG_LIST=""

iwslt14_dex_2keys_kl_pure(){

    EXPTNAME="iwslt14_dex_2keys_symkl"
    RUN="#0"
    DATA="${DATABIN}/iwslt14/dex_en_2keys"
    LANG_PAIRS="de-en"
    LANG_LIST="${DATA}/bin/langs.file"

    CKPTDIR="checkpoints/${EXPTNAME}"
    EXPTDIR="experiments/${EXPTNAME}"
    
    # specific checkpoints can als be averaged/ensembled
    # C1="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.3506.pt"
    # C2="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.3401.pt"
    # C3="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.3209.pt"
    # C4="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.3206.pt"
    # C5="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.3203.pt"
    # C6="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.3104.pt"
    # C7="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.3000.pt"
    # C8="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.2809.pt"
    # C9="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.2507.pt"
    # C10="${ROOT}/${CKPTDIR}/checkpoint.best_bleu_37.2502.pt"

    # CKPT_STRING=$C1,$C2,$C3,$C4,$C5,$C6,$C7,$C8,$C9,$C10

    AVG=5
    python ${FAIRSEQ}/scripts/average_checkpoints.py \
        --inputs ${CKPTDIR} \
        --output "${ROOT}/${CKPTDIR}/checkpoint.avg${AVG}.pt" \
        --num-epoch-checkpoints ${AVG} \

    # CKPT="checkpoint_best.pt"
    CKPT="checkpoint.avg${AVG}.pt"


    RES="${EXPTDIR}/gen.avg${AVG}"
    mkdir -p ${RES}
}

####### interactively generate translation (easy to preserve order ######
# best left untouched 

interactive() {

    echo "sanity -- src and tgt wc -l"
    wc -l ${DATA}/${GEN}.${SRC}-${TGT}.${SRC}
    wc -l ${DATA}/${GEN}.${SRC}-${TGT}.${TGT}

    # cat "${DATA}/bpe/${GEN}.bpe.${SRC}-${TGT}.${SRC}" \
    # always use this--> ${DATA}/${GEN}.${SRC}-${TGT}.${SRC} -- accept command line args
    python "${FAIRSEQ}/fairseq_cli/interactive.py" "${DATA}/bin" \
        --input="${DATA}/${GEN}.${SRC}-${TGT}.${SRC}" \
        --bpe sentencepiece --sentencepiece-model "${DATA}/bpe/spm.bpe.model" \
        --source-lang ${SRC} --target-lang ${TGT} \
        --task translation_multi_simple_epoch \
        --lang-tok-style "multilingual" \
        --path ${CKPTDIR}/${CKPT} \
        --buffer-size 500  --batch-size 496 \
        --beam 5 --lenpen 1.0 --remove-bpe=sentencepiece  \
        --encoder-langtok "tgt" \
        --lang-dict "${LANG_LIST}" \
        --lang-pairs "${LANG_PAIRS}" \
        # --tokenizer moses 
        # > "${RES}/gen.${SRC}-${TGT}.${TGT}.out"
        # --moses-source-lang ${SRC} --moses-target-lang ${TGT}
        # --sentencepiece-model "${DATA}/bpe/spm.bpe.model"

}

####### exp config call #########
### this sets the variable values
iwslt14_dex_2keys_kl_pure


#### putting it all together ###

export CUDA_VISIBLE_DEVICES=1

interactive | tee "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.out"

# extract hypotheses
grep ^H "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.out" | cut -f3- > "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.sys"

# prepare refs
cat "${DATA}/${GEN}.${SRC}-${TGT}.${TGT}" > "${RES}/${GEN}.${SRC}-${TGT}.${TGT}.ref"

########### compute SacreBLEU ###########
sacrebleu "${RES}/${GEN}.${SRC}-${TGT}.${TGT}.ref" -i "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.sys" -m bleu -w 4 \
| tee "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.sacrebleu"

########### compute multibleu like previous work ############

# step 1: tokenize hyps and refs

# don't be surprised! remember we did NOT apply moses tokenization when preprocessing
# while previous work applies moses tokenization during preprocessing.
# we do not apply moses tokenization because it messes with ciphertexts. we let sentencepice handle it instead.
# we've verified that this doesn't change the bleu score but just enables a smooth handling of the ciphertexts.

sacremoses -j 4 tokenize < "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.sys" > "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.sys.multi"
sacremoses -j 4 tokenize < "${RES}/${GEN}.${SRC}-${TGT}.${TGT}.ref" > "${RES}/${GEN}.${SRC}-${TGT}.${TGT}.ref.multi"

# step 2: compute multibleu (produces same results as multibleu.perl)
fairseq-score -r "${RES}/${GEN}.${SRC}-${TGT}.${TGT}.ref.multi" -s "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.sys.multi" \
| tee "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.multibleu"

################ display scores #############
echo "sacreBLEU"
cat "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.sacrebleu"
echo ""
echo "multiBLEU"
cat "${RES}/gen.${GEN}.${SRC}-${TGT}.${TGT}.multibleu




# standard usage: bash gen_and_bleu.sh test de en
# for diverse trans try enciphered source text: bash bash gen_and_bleu.sh test de1 en
