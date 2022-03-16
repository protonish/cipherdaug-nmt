import string
import random
from collections import Counter
from collections import defaultdict

import argparse
import os
import sys

import pathlib
from typing import Union, Optional

random.seed(456)


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


# file ins and outs
def read_file(file: Union[str, pathlib.Path]) -> list:
    # print("Reading input: {}".format(file))
    with open(file, "r") as f:
        text = f.readlines()
    return text


def write_file(key: int, text: list, dir_path: Union[str, pathlib.Path], fname: dict, mod: Optional[str] = None):
    """
    requires fname to be in "filename.ext" format
    """
    # already validated from argaparse check_path that dir_path exists
    dir_name = os.path.dirname(dir_path)
    # in_name, out_name = formatted_file_names(fname, key)
    # path = os.path.join(dir_name, out_name)
    # filename = fname + "." + str(output_ext(key))
    out_name_format = build_ext(fname, key, mod=mod)
    filename = build_filename(out_name_format)

    path = os.path.join(dir_name, filename)
    print("Writing in dir: {}".format(dir_name))
    with open(path, "w") as f:
        for line in text:
            f.write("{}".format(output_ext(key), line))
    print("Finished writing cipher file with key : {}".format(key))


def get_fname(in_path: Union[str, pathlib.Path]):
    """
    returns everything except the dir path
    path: "/path/to/dir/filename.ext"

    returns filename.ext
    """
    dir_name = os.path.dirname(in_path)
    fname = in_path[len(dir_name) + 1 :]

    return fname


# not in use
def get_fname_and_ext(in_path: Union[str, pathlib.Path]):
    """
    works only when filename is in the format: "filename.ext"
    """
    dir_name = os.path.dirname(in_path)
    fname = in_path[len(dir_name) + 1 :].split(".")
    name = fname[:-1]
    ext = fname[-1]

    return name, ext


# not in use
def format_fname(in_path: Union[str, pathlib.Path]) -> dict:
    """
    only works when file-name is in the format: "filename.src-tgt.src".
    takes inpout file path as input and formats it into a structured file name format.

    returns a dictionary with keys: ['name', 'src', 'tgt', 'side']
    """
    name_dict = {}
    dir_name = os.path.dirname(in_path)
    name_dict["dir"] = dir_name
    fname = in_path[len(dir_name) + 1 :].split(".")  # -> ['file', 'src-tgt', 'src']
    name_dict["name"] = fname[:-2]
    # for now, add assertion; TODO: make the method general.
    assert "-" in fname[-2], "The input file name is not in name.src-tgt.src format."
    src_tgt = fname[-2].split("-")
    src = src_tgt[0]
    tgt = src_tgt[-1]

    side = None
    if fname[-1] == src:
        side = "src"
        name_dict["ext"] = src
    else:
        side = "tgt"
        name_dict["ext"] = tgt

    assert side is not None, "There is something wrong with the input filename!"

    name_dict["src"] = src
    name_dict["tgt"] = tgt
    name_dict["side"] = side

    return name_dict


# not in use
def formatted_file_names(fname: dict, key: int) -> str:
    # input file name structure
    in_name = fname["name"] + "." + fname["src"] + "-" + fname["tgt"] + "."
    in_ext = fname["src"] if fname["side"] == "src" else fname["tgt"]
    in_name = in_name + "." + in_ext

    # output file name structure
    out_name = fname["name"] + "."  # + fname["src"] + "-" + fname["tgt"] + "."
    if fname["side"] == "src":
        out_name = out_name + str(output_ext(key)) + "-" + fname["tgt"] + "." + str(output_ext(key))
    elif fname["side"] == "tgt":
        out_name = out_name + fname["src"] + "-" + str(output_ext(key)) + "." + str(output_ext(key))
    else:
        print("formatted_file_names() -> Error while formatting file names!")
        exit()

    return in_name, out_name


# not in use
def output_ext_ascii(key: int, ext=None):
    """
    given a key, returns a made up lange name from the ascii char list.
    [a,b,c,d,e,f, ...,z,A,B,..]
    if key ==1, ext = aa; if key ==3, ext = cc
    """
    fnames_alpha = string.ascii_letters
    # fnames_alpha[0] = a
    fname = fnames_alpha[key - 1]
    return fname + fname


def output_ext(key: int, ext: str):
    """
    given a key and file ext, concats them both.
    de, 6 --> de6
    """
    new_ext = ext + str(key)
    return new_ext


def build_ext(fname: dict, key: int, mod: Optional[str] = None) -> dict:
    if fname["src"] == fname["ext"]:
        fname["out_src"] = output_ext(key, fname["ext"])
        if mod is not None:
            fname["out_tgt"] = mod
        else:
            fname["out_tgt"] = fname["tgt"]
    else:
        fname["out_tgt"] = output_ext(key, fname["ext"])
        if mod is not None:
            fname["out_src"] = mod
        else:
            fname["out_src"] = fname["src"]

    fname["out_ext"] = output_ext(key, fname["ext"])

    return fname


def build_filename(fname: dict) -> str:
    """
    returns filename given a dictionary with name components
    """
    filename = fname["name"]
    assert "out_src" in fname, "Named_dict (fname) does not contain 'out' keys."

    filename = filename + "." + fname["out_src"] + "-" + fname["out_tgt"] + "." + fname["out_ext"]

    return filename


def build_dir(fname: dict) -> str:
    """
    returns output dir name given a dictionary with name components
    """

    return


def deduplicate(paths: str):
    paths = paths.split(",")
    files = defaultdict(list)
    for path in paths:
        if os.path.isfile(path):
            _, ext = get_fname_and_ext(path.strip())
            files[ext].append(path)

    dedup = []
    for lang in files.keys():
        dedup.append(files[lang][0])
        files[lang][0]

    return dedup


def get_langs_from_dir(args):
    assert os.path.isdir(args.input), "Input must be a directory!"
    dir_name = args.input
    allfiles = [
        f for f in os.listdir(dir_name) if os.path.isfile(os.path.join(dir_name, f)) and "dict" == f.split(".")[0]
    ]

    for f in allfiles:
        lang = f.split(".")[1]
        print(lang)


def batchify(lrange: int, bsz: int = 32) -> list:
    """Yield bsz-sized chunks from lst in lrange."""
    idx = list(range(0, lrange, 1))
    # shuffle the list radomly
    random.shuffle(idx)
    for i in range(0, len(idx), bsz):
        yield idx[i : i + bsz]


def swapout(plaintext: list, ciphertext: list, prob: float = 0.1, batch_prob: float = 0.6) -> list:
    assert len(plaintext) == len(ciphertext), "Plaintext and Ciphertext text lengths do not match! {} - {}".format(
        len(plaintext), len(ciphertext)
    )
    batches = list(batchify(len(plaintext)))

    num_sentences = 0
    num_swaps = 0
    # print(batches[:2])
    for batch in batches:
        for idx in batch:
            if random.random() < batch_prob:
                num_sentences += 1
                cipher = ciphertext[idx].split(" ")
                for i in range(len(cipher)):
                    if random.random() < prob:
                        plain = plaintext[idx].split(" ")
                        cipher[i] = plain[i]
                        num_swaps += 1

                ciphertext[idx] = " ".join(cipher)

    # print("Edited {} lines with a total of {} swapouts.".format(num_sentences, num_swaps))

    for cl in ciphertext:
        print(cl.strip())


def prep_align_file(args):
    inp = args.input
    inp = inp.split(",")

    assert len(inp) == 2, "Exactly 2 files needed for alignment."

    with open(inp[0], "r") as f:
        src = f.readlines()
    with open(inp[1], "r") as f:
        tgt = f.readlines()

    assert len(src) == len(tgt), "Source and Target files of different lengths: \nsrc: {}\ntgt: {}".format(
        inp[0], inp[1]
    )

    aligned = []
    for sline, tline in zip(src, tgt):
        line = sline.strip() + " ||| " + tline.strip()
        aligned.append(line)

    for line in aligned:
        print(line)


def util_parser():
    def path_exists(path):
        # works for both files and directories
        if os.path.exists(path):
            return path
        else:
            raise argparse.ArgumentTypeError(f"Path exists check:{path} is not a valid path")

    parser = argparse.ArgumentParser(
        prog="cipher_utils",
        usage="%(prog)s --input --keys [options]",
        description="Arguments for handling file ops for cipher text.",
    )

    parser.add_argument("-i", "--input", type=str, required=True, help="input file paths")
    parser.add_argument("-o", "--original", type=path_exists, help="original file paths")
    parser.add_argument("-p", "--prob", type=float, help="swapout probability")

    parser.add_argument("--dedup", action="store_true", help="get deduplicated paths")
    parser.add_argument("--getlangs", action="store_true", help="get all langs in the given dir")
    parser.add_argument("--swapout", action="store_true", help="swap words from ciphertext with plaintext with prob")

    return parser


if __name__ == "__main__":

    parser = util_parser()
    args = parser.parse_args()

    if args.dedup:
        dedup_paths = deduplicate(args.input)
        for path in dedup_paths:
            print("{}".format(path), end=",")

    if args.getlangs:
        get_langs_from_dir(args)
    # print(dedup_paths)

    if args.swapout:
        assert len(args.input.split(",")) == 1, "Can't have more than one cipherfile for Swapout"
        assert args.original is not None, "--original can not be empty. Need the original plaintext."
        assert args.prob is not None, "--prob must be set for Swapout."

        plaintext = read_file(args.original)
        ciphertext = read_file(args.input)

        # assert len(plaintext) == len(ciphertext), "Plaintext and Ciphertext must be of same length."
        assert plaintext[:100] != ciphertext[:100], "Plaintext and Cipheretext appear to be the same text."

        swapout(plaintext, ciphertext, prob=args.prob)
