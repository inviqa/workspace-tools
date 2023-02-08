#!/usr/bin/env bash

function load_parameters {
    tmp="${0%.*}"
    ME=${tmp##*/}
    DEBUG=0 #0,1,2
    REQUIREMENTS=('yq' 'jq')
    ATTRIBUTES=()
    WS_FILE="workspace.yml"
    SHOW_ENCRYPTED_ONLY=false
    
    read_parameters "${@}"
    if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | WS_FILE: ${WS_FILE}"; fi
}

function print_usage {
  printf  "usage: %s [options] \n" "${ME}"
  printf  "\noptions:"
  USAGE="
      -d|--debug <level>                0: show only command errors
                                        1: show all the attributes that are read and their type
                                        2: show all computed steps output
      -e|--encrypted                    Print list of encrypted attributes only
      -h|--help                         Print this help  
      -q|--quiet                        Equal to --debug 0
      -w|--workspace-file               Path to the Workspace file where the encrypted secrets are stored (defaults to workspace.yml)
"
echo "${USAGE}"
}

function validate_argument {
  ARGUMENT="${1}"
  if [[ -z "${ARGUMENT}" || "${ARGUMENT}" == "-*" ]]; then
    echo "(e) | Invalid or missing argument ${1}"
    print_usage
    exit 1
  fi
}

function read_parameters {
  if [[ -n "${1}" ]]; then
    case "${1}" in
      -d|--debug)
        validate_argument "${2}"
        DEBUG="${2}"
        shift 2
        ;;
      -e|--encrypted)
        SHOW_ENCRYPTED_ONLY=true
        shift 1
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      -q|--quiet)
        DEBUG=0
        shift 1
        ;;
      -w|--workspace-file)
        validate_argument "${2}"
        WS_FILE="${2}"
        shift 2
        ;;
      *)
        echo "(e) | Invalid option: ${1}"
        print_usage
        exit 1
        ;;
    esac
    read_parameters "${@}"
  fi
}

function is_requirement_available {
    for TOOL in "${REQUIREMENTS[@]}"
    do
        TOOL_PATH="$( command -v "${TOOL}")"
        if [[ ! -x "${TOOL_PATH}" ]]; then
            echo "(e) | ABORTING: COMMAND '${TOOL}' NOT FOUND OR NOT EXECUTABLE!"
            return 1
        else
            if [[ ${DEBUG} -ge 1 ]]; then echo "(d) | REQUIREMENT FOUND: ${TOOL_PATH}"; fi
        fi
    done
}

function get_inline_attributes {
    START_WITH='attribute('
    # shellcheck disable=SC2207
    INLINE_ATTRIBUTES=( $(yq "${WS_FILE}" -o json | jq  -r 'to_entries[] | select(.key | startswith("'"${START_WITH}"'")) | .key' || true  ) )
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
                    DECRYPT=$(grep "${ATTRIBUTE}" < "${WS_FILE}" | grep "decrypt" || true)
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
    CHILDREN=( $(yq "${WS_FILE}" -o json | jq  -r 'to_entries[] | select(.key | startswith("attribute('\'"${PARENT_ATRIBUTE}"\'')")) | .value' | jq -r 'paths | map(.|tostring) | join(".")' || true  ) )
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
                        DECRYPT=$(grep "${CHILDREN[${CHILD}]}" < "${WS_FILE}" | grep "decrypt" || true)
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
    NESTED_ATTRIBUTES=( $(yq '.attributes' "${WS_FILE}" -o json | jq -r 'paths | map(.|tostring) | join(".")' || true  ))
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
                        DECRYPT=$(grep "${ATTRIBUTE_NAME}" < "${WS_FILE}" | grep "decrypt" || true)
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

load_parameters "${@}"
if is_requirement_available; then
    get_inline_attributes
    get_nested_attributes
    if [[ ${DEBUG} -eq 0 ]]; then
        list_attributes
    elif [[ ${DEBUG} -ge 2 ]]; then
        echo "(d) | ALL_ATTR: ${ATTRIBUTES[*]}"
        echo "(d) | ALL_ATTR_#: ${#ATTRIBUTES[*]}"
    fi
    exit 0
else
    exit 1
fi
