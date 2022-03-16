import string
import random
from collections import Counter

import argparse
import os
import sys

import pathlib
from typing import Union

import utils
from utils import eprint
import pickle
from tqdm import tqdm
import functools
from multiprocessing import Pool

# file ins and outs
def read_file(file: Union[str, pathlib.Path]) -> list:
    eprint("Reading input: {}".format(file))
    with open(file, "r") as f:
        text = f.readlines()
    return text


def build_char_vocab(text: list, args):

    char_dict_path = args.char_dict_path

    # format input path to parse particulars
    # fname = utils.format_fname(args.input)
    # dict_name = "charset.train." + fname["src"] + "-" + fname["tgt"] + "." + fname["src"] + ".pkl"

    char_vocab = {}

    if char_dict_path is not None and os.path.isfile(char_dict_path):
        eprint("Char Vocab Dictionary found. Loading from {} ..".format(char_dict_path))
        with open(char_dict_path, "rb") as f:
            char_vocab = pickle.load(f)
    else:
        eprint("Char Vocab Dictionary not found. Building ..")
        char_vocab["lower"] = get_char_vocab(text, alphaonly=True, loweronly=True)
        char_vocab["upper"] = get_char_vocab(text, alphaonly=True, upperonly=True)
        char_vocab["alpha"] = get_char_vocab(text, alphaonly=True)

        if char_dict_path is not None:
            eprint("Saving Char Vocab Dictionary to {} ..".format(char_dict_path))
            # dump char_vocab dict as pickle
            with open(char_dict_path, "wb") as f:
                pickle.dump(char_vocab, f)

        else:
            eprint("Saving char vocab is strongly recommended for proper mapping on valid and test wrt train data! ")

    return char_vocab


# cipher related
def get_char_vocab(text, alphaonly=False, loweronly=False, upperonly=False):
    char_counter = Counter()
    for line in text:
        if alphaonly:
            if loweronly:
                char_counter.update(c for c in line if c.isalpha() and c.islower())
            elif upperonly:
                char_counter.update(c for c in line if c.isalpha() and c.isupper())
            else:
                char_counter.update(c for c in line if c.isalpha())
        else:
            char_counter.update(c for c in line)

    chars = sorted(char_counter.keys())
    return chars


def shift_vocab(all_letters, key):
    """
    performs rot-key encipherment of plaintext given the key.
    essentially performs a char shift.
    key == 1 turns a=b, b=c, .. z=a;
    key == 3 turns a=c, b=e, .. z=c.

    returns a dict with orig chars as keys and new chars as values
    key = 1 returns d{'a':'b', 'b':'c', .. , 'z':'a'}
    """
    d = {}
    for i in range(len(all_letters)):
        d[all_letters[i]] = all_letters[(i + key) % len(all_letters)]
    return d


def monophonic(plain_txt: str, all_letters: list, shifted_letters: dict):
    """
    enciphers a line of plaintext with monophonic shift (rot-key) cipher
    i.e. number of unique chars across plaintext and ciphertext remains conserved
    """
    cipher_txt = []
    for char in plain_txt:
        if char in all_letters:
            temp = shifted_letters[char]
            cipher_txt.append(temp)
        else:
            temp = char
            cipher_txt.append(temp)

    cipher_txt = "".join(cipher_txt)
    return cipher_txt


# non tested
def homophonic(plaintext, prob):
    """
    enciphers a line of plaintext with homophonic ciphers
    i.e. number of unique chars in ciphertext is always less than plaintext
    """
    cipher_text = ""
    for i in range(len(plaintext)):
        cipher_text += "%" if random.random() > prob and (plaintext[i] in ["a", "e", "i", "o", "u"]) else "-"
    return cipher_text


# generate and write ciphers
def encipher(args):
    # read file
    plaintext = read_file(args.input)
    # formatted_in_file_name = utils.format_fname(args.input)

    # get charcater vocabulary
    char_vocab = build_char_vocab(plaintext, args)

    # all_ciphers = {}
    # encipher plaintext for each key
    for key in [args.keys]:
        ciphertext = []
        shifted_vocab = {}

        if args.cased:

            shifted_vocab["lower"] = shift_vocab(char_vocab["lower"], key)
            shifted_vocab["upper"] = shift_vocab(char_vocab["upper"], key)

            for plain_line in tqdm(plaintext, desc="lines"):
                cipher_line = monophonic(plain_line, char_vocab["lower"], shifted_vocab["lower"])
                cipher_line = monophonic(cipher_line, char_vocab["upper"], shifted_vocab["upper"])
                ciphertext.append(cipher_line)
        else:

            shifted_vocab["alpha"] = shift_vocab(char_vocab["alpha"], key=key)
            assert len(shifted_vocab["alpha"]) == len(
                char_vocab["alpha"]
            ), "Shifted Vocab not the same size as Original Vocab!"

            # for plain_line in tqdm(plaintext, desc="lines"):
            #     cipher_line = monophonic(plain_line, char_vocab["alpha"], shifted_vocab["alpha"])
            #     ciphertext.append(cipher_line)
            
            monocipher = functools.partial(monophonic, all_letters=char_vocab["alpha"], shifted_letters=shifted_vocab["alpha"])
            
            with Pool(4) as pool:
                ciphertext = list(pool.map(monocipher, tqdm(plaintext, desc="lines")))

        assert len(ciphertext) == len(plaintext), "Something's wrong! Plaintext and Ciphertext have diff lengths."

        eprint("Finished enciphering with key: ", key)

        # all_ciphers[key] = ciphertext

        # write to files
        # utils.write_file(key, ciphertext, args.output, formatted_in_file_name)

    return ciphertext

def parserr():
    def path_exists(path):
        # works for both files and directories
        if os.path.exists(path):
            return path
        else:
            raise argparse.ArgumentTypeError(f"Path exists check:{path} is not a valid path")

    parser = argparse.ArgumentParser(
        prog="encipher",
        usage="%(prog)s --input --keys [options]",
        description="Arguments for generating cipher text from an given plaintext.",
    )

    parser.add_argument("-i", "--input", type=path_exists, required=True, help="input file path")
    parser.add_argument("-o", "--output", type=path_exists, help="output file path")
    parser.add_argument("--prob", type=float, help="swapout probability")
    # parser.add_argument(
    #     "--save-chars",
    #     action="store_true",
    #     help="save original character set; helps when enciphering the same source with multiple keys.",
    # )
    parser.add_argument(
        "--char-dict-path",
        type=str,
        default=None,
        help="char dict path; will save if given and if exists, will be re-used",
    )

    parser.add_argument("--keys", type=int, required=True, help="(1 key for now) list of keys for encipherment")
    parser.add_argument("--alpha", action="store_true", help="encipher alphaonly")
    parser.add_argument("--lower", action="store_true", help="encipher lowercase only")
    parser.add_argument("--upper", action="store_true", help="encipher uppercase only")
    parser.add_argument("--cased", action="store_true", help="encipher while preserving case")
    parser.add_argument("--swapout", action="store_true", help="swap words from ciphertext with plaintext with prob")

    return parser


if __name__ == "__main__":
    parser = parserr()
    args = parser.parse_args()

    ciphertext = encipher(args)

    for cline in ciphertext:
        print(cline.strip())
