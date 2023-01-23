#!/usr/bin/env bash
DEBUG=1 #0,1,2
ATTRIBUTES=()

ws_file="${1:-workspace.yml}"

if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | WS_FILE: ${ws_file}"; fi

function get_inline_attributes {

    START_WITH='attribute('
    # shellcheck disable=SC2207
    INLINE_ATTRIBUTES=( $(yq "${ws_file}" -o json | jq  -r 'to_entries[] | select(.key | startswith("'"${START_WITH}"'")) | .key' || true  ) )

    if [[ ${#INLINE_ATTRIBUTES[*]} -ge 1 ]]; then
        if [[ ${DEBUG} -ge 2 ]]; then echo "(d) | INLINE_ATTRIBUTES: ${INLINE_ATTRIBUTES[*]}"; fi
        if [[ ${DEBUG} -ge 2 ]]; then echo "(d) | INLINE_ATTR_#: ${#INLINE_ATTRIBUTES[*]}"; fi
        for (( ATTRIB=0; ATTRIB<${#INLINE_ATTRIBUTES[*]}; ATTRIB++ ));
        do
            ATTRIBUTE="${INLINE_ATTRIBUTES[${ATTRIB}]}"
            ATTRIBUTE="${ATTRIBUTE##*\(\'}"
            ATTRIBUTE="${ATTRIBUTE%%\'\)}"
            if is_attribute_array "${ATTRIBUTE}";then
                get_inline_children_attributes "${ATTRIBUTE}"
            else
                if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | INLINE: ${ATTRIBUTE}"; fi
                ATTRIBUTES+=("${ATTRIBUTE}")
            fi
        done
    fi
}

function get_inline_children_attributes {
    PARENT_ATRIBUTE="${1}"
    if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | PARENT: ${PARENT_ATRIBUTE}"; fi
    # shellcheck disable=SC2207
    CHILDREN=( $(yq "${ws_file}" -o json | jq  -r 'to_entries[] | select(.key | startswith("attribute('\'"${PARENT_ATRIBUTE}"\'')")) | .value' | jq -r 'paths | map(.|tostring) | join(".")' || true  ) )
    if [[ ${#CHILDREN[*]} -ge 1 ]]; then
        if [[ ${DEBUG} -ge 2 ]]; then  echo "(d) | CHILDREN_#: ${#CHILDREN[*]}"; fi
        for (( CHILD=0; CHILD<${#CHILDREN[*]}; CHILD++ ));
        do
            CHILD_ATTRIBUTE="${PARENT_ATRIBUTE}.${CHILDREN[${CHILD}]}"
            if ! is_attribute_array "${CHILD_ATTRIBUTE}";then
                if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | CHILD${CHILD}: ${CHILD_ATTRIBUTE}"; fi
                ATTRIBUTES+=("${CHILD_ATTRIBUTE}")
            fi
        done
    fi
}

function get_nested_attributes {
    # shellcheck disable=SC2207
    NESTED_ATTRIBUTES=( $(yq '.attributes' "${ws_file}" -o json | jq -r 'paths | map(.|tostring) | join(".")' || true  ))
    if [[ ${#NESTED_ATTRIBUTES[*]} -ge 1 ]]; then
        if [[ ${DEBUG} -ge 2 ]]; then echo "(d) | NESTED_ATTRIBUTES: ${NESTED_ATTRIBUTES[*]}"; fi
        if [[ ${DEBUG} -ge 2 ]]; then echo "(d) | NESTED_ATTRIBUTES_#: ${#NESTED_ATTRIBUTES[*]}"; fi
        for (( ATTRIB=0; ATTRIB<${#NESTED_ATTRIBUTES[*]}; ATTRIB++ ));
        do
            ATTRIBUTE="${NESTED_ATTRIBUTES[${ATTRIB}]}"
            if ! is_attribute_array "${ATTRIBUTE}";then
                if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | NESTED: ${ATTRIBUTE}"; fi
                ATTRIBUTES+=("${ATTRIBUTE}")
            fi
        done
    fi
}

function is_attribute_array {
    ATTRIBUTE="${1}"
    ws config dump --key="${ATTRIBUTE}" | grep -q "array" && return 0 || return 1 || true
}


get_inline_attributes
get_nested_attributes

if [[ ${DEBUG} -ge 2 ]]; then echo "(d) | ALL_ATTR: ${ATTRIBUTES[*]}"; fi
if [[ ${DEBUG} -ge 2 ]]; then echo "(d) | ALL_ATTR_#: ${#ATTRIBUTES[*]}"; fi
