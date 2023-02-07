#!/usr/bin/env bash
DEBUG=0 #0,1,2
SHOW_ENCRYPTED_ONLY=true
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
            if is_attribute_array "${ATTRIBUTE}"; then
                get_inline_children_attributes "${ATTRIBUTE}"
            else
                if [[ ${SHOW_ENCRYPTED_ONLY} == true ]];then 
                    DECRYPT=$(grep "${ATTRIBUTE}" < "${ws_file}" | grep "decrypt" || true)
                    if [[ -n "${DECRYPT}" ]];then
                        if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | INLINE: ${ATTRIBUTE}"; fi
                        if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | DECRYPT: ${DECRYPT}"; fi
                        ATTRIBUTES+=("${ATTRIBUTE}")
                    fi
                else
                    if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | INLINE: ${ATTRIBUTE}"; fi
                    ATTRIBUTES+=("${ATTRIBUTE}")
                fi
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
            CHILD_NAME="${CHILDREN[${CHILD}]}"
            CHILD_ATTRIBUTE="${PARENT_ATRIBUTE}.${CHILD_NAME}"
            if ! is_attribute_array "${CHILD_ATTRIBUTE}";then
                if [[ ${SHOW_ENCRYPTED_ONLY} == true ]];then
                    # Skip looking for decrypt if the child name is a number, because it means it's a list not an "array" of attributes
                    if ! [[ "${CHILD_NAME}" =~ ^[0-9]+$ ]] ; then
                        if [[ ${DEBUG} -ge 2 ]]; then echo "(d) | CHILD: ${CHILD_NAME}"; fi
                        DECRYPT=$(grep "${CHILDREN[${CHILD}]}" < "${ws_file}" | grep "decrypt" || true)
                        if [[ -n "${DECRYPT}" ]];then
                            if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | CHILD${CHILD}: ${CHILD_ATTRIBUTE}"; fi
                            if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | DECRYPT: ${DECRYPT}"; fi
                            ATTRIBUTES+=("${CHILD_ATTRIBUTE}")
                        fi
                    fi
                else
                    if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | CHILD${CHILD}: ${CHILD_ATTRIBUTE}"; fi
                    ATTRIBUTES+=("${CHILD_ATTRIBUTE}")
                fi
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
                if [[ ${SHOW_ENCRYPTED_ONLY} == true ]];then
                    ATTRIBUTE_NAME="${ATTRIBUTE##*.}"
                    # Skip looking for decrypt if the child name is a number, because it means it's a list not an "array" of attributes
                    if ! [[ ${ATTRIBUTE_NAME} =~ ^[0-9]+$ ]] ; then
                        # Skip looking for decrypt if the child name is a number, because it means it's a list not an "array" of attributes
                        DECRYPT=$(grep "${ATTRIBUTE_NAME}" < "${ws_file}" | grep "decrypt" || true)
                        if [[ -n "${DECRYPT}" ]];then
                            if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | NESTED: ${ATTRIBUTE}"; fi
                            if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | DECRYPT: ${DECRYPT}"; fi
                            ATTRIBUTES+=("${ATTRIBUTE}")
                        fi
                    fi
                else
                    if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | NESTED: ${ATTRIBUTE}"; fi
                    ATTRIBUTES+=("${ATTRIBUTE}")
                fi
            fi
        done
    fi
}

function is_attribute_array {
    ATTRIBUTE="${1}"
    ws config dump --key="${ATTRIBUTE}" | grep -q "array" && return 0 || return 1 || true
}

function list_attributes {
    if [[ ${#ATTRIBUTES[*]} -gt 0 ]];then 
        for (( ATTRIBUTE=0; ATTRIBUTE<${#ATTRIBUTES[*]}; ATTRIBUTE++ ));
        do
            echo "${ATTRIBUTES[${ATTRIBUTE}]}"
        done 
    else
        echo "No attributes found"
    fi
}

get_inline_attributes
get_nested_attributes

if [[ ${DEBUG} -eq 0 ]]; then
    list_attributes
fi

if [[ ${DEBUG} -ge 2 ]]; then echo "(d) | ALL_ATTR: ${ATTRIBUTES[*]}"; fi
if [[ ${DEBUG} -ge 2 ]]; then echo "(d) | ALL_ATTR_#: ${#ATTRIBUTES[*]}"; fi