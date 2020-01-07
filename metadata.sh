#!/bin/bash
is_debug=1
is_warning=1

dst_file=readme.txt
tmp_file=tmp_readme.txt

# used for bash4 hashmaps
if [[ "${BASH_VERSION::1}" -lt "4" ]] || [[ "${BASH_VERSION::1}" == "" ]]
then
    echo "Error: this script requires bash 4 or later"
    echo "       you have $BASH_VERSION"
    exit 1
fi

if ! [ -x "$(command -v sha1sum)" ];
then
    echo 'Error: sha1sum is not installed.' >&2
    exit 1
fi

function dbg() {
    if [ "$is_debug" -eq 0 ]
    then
        return
    fi
    echo "[*] $1"
}
function wrn() {
    if [ "$is_warning" -eq 0 ]
    then
        return
    fi
    echo "[!] $1"
}

function delete_cache() {
    if [ -f "$tmp_file" ]
    then
        rm "$tmp_file"
    fi
}

if [ "$#" -ne "1" ]
then
    echo "usage: $(basename $0) <directory>"
    echo "example: $(basename $0) cartoon"
    exit 0
fi

dir="$1"

dbg "Parsing dir '$dir' ..."
if [ ! -d "$dir" ]
then
    echo "Error: invalid directory '$dir'"
    exit 1
fi

cd "$dir" || exit 1

if [ ! -f "$dst_file" ]
then
    echo "Error: file not found '$dst_file'"
    exit 1
fi

delete_cache

declare -A file_images

function add_image() {
    local path="$1"
    local author="$2"
    local notes="$3"
    local tags="$4"
    local old_sha1="$5"
    old_sha1="$(echo "${old_sha1#*:}" | xargs)"
    path="${path:2}"
    author="$(echo "${author#*:}" | xargs)"
    notes="$(echo "${notes#*:}" | xargs)"
    tags="$(echo "${tags#*:}" | xargs)"
    if [ "$author" != "" ]; then author=" $author"; fi
    if [ "$notes" != "" ]; then notes=" $notes"; fi
    if [ "$tags" != "" ]; then tags=" $tags"; fi
    new_sha1="$(sha1sum "$path" | cut -d ' ' -f1)"
    if [ "$old_sha1" != "$new_sha1" ]
    then
        wrn "WARNING sha1 missmatch '$path'"
        wrn "'$old_sha1' -> '$new_sha1'"
    fi
    dbg "Adding image '$path' ..."
    dbg " author = '$author'"
    dbg " notes  = '$notes'"
    dbg " tags   = '$tags'"
    dbg " sha1   = '$old_sha1'"
    read -d '' credit << EOF
- $path
    author:$author
    notes:$notes
    tags:$tags
    sha1: $new_sha1
EOF
    file_images["$path"]="$credit"
}

i=0
file_path=INVALID
sha1=INVALID
author=INVALID
notes=INVALID
tags=INVALID
while IFS= read -r l
do
    i=$((i+1))
    if [ "$i" -eq 1 ]; then
        file_path="$l"
    elif [ "$i" -eq 2 ]; then
        author="$l"
    elif [ "$i" -eq 3 ]; then
        notes="$l"
    elif [ "$i" -eq 4 ]; then
        tags="$l"
    elif [ "$i" -eq 5 ]; then
        sha1="$l"
        i=0
        found=0
        while IFS= read -r -d '' f
        do
            img="- ${f:2}"
            if [ "$img" == "$file_path" ]
            then
                found=1
                break;
            fi
        done < <(find . -type f \( \
            -name "*.jpg" -o \
            -name "*.svg" -o \
            -name "*.png" \) -print0)
        if [ "$found" -eq 0 ]
        then
            wrn "WARNING delete image only exisiting in readme:"
            wrn "$file_path"
        else
            add_image "$file_path" "$author" "$notes" "$tags" "$sha1"
        fi
    fi
done < readme.txt

if [ "$i" -ne 0 ]
then
    echo "Error: invalid index $i != 0"
    exit 1
fi

find . -type f \( \
    -name "*.jpg" -o \
    -name "*.svg" -o \
    -name "*.png" \) -print0 | while IFS= read -r -d '' f
do
    img=${f:2}
    if [[ -v file_images[$img] ]]
    then
        dbg "'$img' is in list"
        echo "${file_images[$img]}" >> "$tmp_file"
        # file_images["$img"]="XXX" # empty element
    else
        dbg "'$img' is in not list"
        echo "- $img" >> "$tmp_file"
        echo "    author:" >> "$tmp_file"
        echo "    notes:" >> "$tmp_file"
        echo "    tags:" >> "$tmp_file"
        echo "    sha1: $(sha1sum "$img" | cut -d ' ' -f1)" >> "$tmp_file"
    fi
done

mv "$tmp_file" "$dst_file"
delete_cache

