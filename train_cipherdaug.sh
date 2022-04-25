# LOC='/cs/lab-machine' # set your root project location
LOC='/local-scratch'
# LOC='/home'
ROOT="${LOC}/user//cipherdaug-nmt"
DATAROOT="${ROOT}/data" # set your data root

DATABIN="${ROOT}/data-bin"

FAIRSEQ="${ROOT}/fairseq"

# override this in each setting; if not
# this assignment will be default
# this is messy but setting the plugin type USR_DIR never worked without complications.


TASK="translation_multi_simple_epoch_eval"
LOSS="label_smoothed_cross_entropy"
ARCH="transformer_iwslt_de_en"
MAX_TOK=7500
UPDATE_FREQ=1
TEST=""
SWITCHOUT=""
DEVICES=0,1
WANDB=""

iwslt14_dex_en_2keys_symkl() {
    # data directory containing train, valid and test splits
    DIR="iwslt14/dex_en_2keys"
    DATA="${DATABIN}/${DIR}/bin"

    LANG_LIST="${DATA}/langs.file"
    LANG_PAIRS="de-en,de1-en,de2-en"
    EVAL_LANG_PAIRS="de-en,"
    
    # these ratios can be changed if you want to analyse the 
    # model behaviour by varying the amount of training data
    SAMP_MAIN='"main:de-en":0.0'
    SAMP_TGT='"main:de1-en":1.0,"main:de2-en":1.0'
    SAMP_SRC='"main:de1-de":1.0,"main:de2-de":1.0'
    
    # virtual-data-size is net amount of training data (all inclusive)
    # that the model trains on. 
    SAMPLE_WEIGHTS="{${SAMP_TGT},${SAMP_MAIN}} --virtual-data-size 641000"
    # experiment identifier; this becomes a dir in checkpoints and experiments folders
    EXPTNAME="iwslt14_dex_2keys_symkl"
    RUN="#0"

    # paths to checkpoints and experiments directories
    CKPT="checkpoints/${EXPTNAME}"
    EXPTDIR="experiments/${EXPTNAME}"
    mkdir -p "$EXPTDIR"
    mkdir -p "$CKPT"

    # fairseq arguments
    TASK="translation_multi_simple_epoch_cipher --prime-src de --prime-tgt en"
    SWITCHOUT=""  # --switchout-tau 0.85 --word-dropout --> applies wordropot within cipherdaug
    LOSS="label_smoothed_cross_entropy_js --js-alpha 5 --js-warmup 500"
    ARCH="transformer_iwslt_de_en"
    MAX_EPOCH=200
    PATIENCE=25
    MAX_TOK=5000
    UPDATE_FREQ=4
    DEVICES=0
    WANDB="wand-project-name"
}

######## exp config call #########
iwslt14_dex_en_2keys_symkl

######## training begins here ####

echo "${EXPTNAME}"
echo "${ARCH}"
echo "${LOSS}"

echo "Entering training.."

export CUDA_VISIBLE_DEVICES=${DEVICES}
python  ${FAIRSEQ}/train.py --log-format simple --log-interval 200 ${TEST} \
    $DATA --save-dir ${CKPT} --keep-best-checkpoints 2 \
    --fp16 --fp16-init-scale 64 --empty-cache-freq 200 \
    --lang-dict "${LANG_LIST}" --lang-pairs "${LANG_PAIRS}" --encoder-langtok tgt \
    --task ${TASK} ${SWITCHOUT} \
    --arch ${ARCH} --share-decoder-input-output-embed --encoder-embed-dim 256 \
    --sampling-weights ${SAMPLE_WEIGHTS} \
    --optimizer adam --adam-betas '(0.9, 0.98)' --clip-norm 0.1 \
    --lr 6e-4 --lr-scheduler inverse_sqrt --warmup-updates 6000 \
    --dropout 0.3 --attention-dropout 0.1 --weight-decay 0.0001 \
    --max-update ${MAX_UPDATE} --patience ${PATIENCE} \
    --keep-last-epochs 15 \
    --criterion ${LOSS} \
    --label-smoothing 0.1 \
    --ddp-backend legacy_ddp --num-workers 2 \
    --max-tokens ${MAX_TOK} --update-freq ${UPDATE_FREQ} --eval-bleu \
    --eval-lang-pairs ${EVAL_LANG_PAIRS} --validate-after-updates 1000 \
    --valid-subset valid --ignore-unused-valid-subsets --batch-size-valid 200 \
    --eval-bleu-detok moses --eval-bleu-remove-bpe sentencepiece \
    --best-checkpoint-metric bleu --maximize-best-checkpoint-metric \
    --eval-bleu-args '{"beam": 1}' \
    --wandb-project ${WANDB} | tee -a "${EXPTDIR}/train.${RUN}.log"


# usage: bash train_cipherdaug.sh
