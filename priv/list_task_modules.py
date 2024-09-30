#!/usr/bin/env python3

import sys
import os
import glob

app_path = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
os.chdir(app_path)

header_path = "src/task_modules.hrl"
task_modules_path = "src/modules/*.erl"
task_modules_file = '.task_modules'
ignore_files = ['kt_compactor_worker', 'kt_skel']


def fname(path):
    (name, ext) = (os.path.splitext(os.path.basename(path)))
    return name


mods_list = [fname(key) for key in glob.glob(task_modules_path)
             if fname(key) not in ignore_files]
mods_list.sort()


def check_tmp():
    with open(task_modules_file) as f:
        tmp_list = f.read().splitlines()
        tmp_list.sort()
        if mods_list == tmp_list:
            exit(0)


if len(sys.argv) == 2 and sys.argv[1] == '--no-overwrite':
    if os.path.isfile(header_path):
        check_tmp()

with open(header_path, 'w') as header_file:
    name = fname(header_path)
    header_name = name.upper()

    first, rest = mods_list[0], mods_list[1:]

    header_file.write("-ifndef("+header_name+"_HRL).\n")

    header_file.write("-define("+header_name+"_HRL, 'true').\n\n")

    header_file.write("-define(TASKS, ['"+first+"'\n")

    for k in rest:
        header_file.write("               ,'"+k+"'\n")

    header_file.write("               ]).\n\n")
    header_file.write("-endif.\n")

with open(task_modules_file, 'w') as f:
    for k in mods_list:
        f.write(k+"\n")
