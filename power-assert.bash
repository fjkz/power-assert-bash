#!/usr/bin/env bash
#
# Power Assert for Bash
#

# print the expanded sentense
function powerassert_expand() {
  echo ""
  echo "expanded:"
  echo ""
  echo "[[[ $@ ]]]"
}

# print diff
function powerassert_diff() {
  left_name="$1"
  right_name="$2"
  left_val="$3"
  right_val="$4"
  echo ""
  # change ---, +++ line
  echo "--- ${left_name}"
  echo "+++ ${right_name}"
  diff -u <(echo "${left_val}") <(echo "${right_val}") |
    sed -e '/^---/d' |
    sed -e '/^+++/d'
}

# print as
#
# $left:  AAA
# $right: BBB
#
function powerassert_table() {
  left_name="$1"
  right_name="$2"
  left_val="$3"
  right_val="$4"
  echo ""
  echo -e "${left_name}: \t${left_val}"
  echo -e "${right_name}: \t${right_val}"
}

# print as
#
# [[[ $a == aa ]]]
#     |
#     a
#
function powerassert_single_point() {
  sentence="$1"
  val="$2"

  # print "|"
  echo "${sentence}"     |
    sed -e 's/[^\$]/ /g' |
    sed -e 's/\$.*$/|/'

  # indent
  echo -n "${sentence}"  |
    sed -e 's/[^\$]/ /g' |
    sed -e 's/\$.*$//'

  echo "${val}"
}

# print as
#
# [[[ $a == $b ]]]
#     |     |
#     |     BB
#     AA
#
function powerassert_double_point() {
  sentence="$1"
  right_val="$2"
  left_val="$3"

  # print "| |"
  echo "${sentence}"     |
    sed -e 's/[^\$]/ /g' |
    sed -e 's/\$/|/g '   |
    sed -e 's/ .$//'

  # print "|" and indent
  echo -n "${sentence}"  |
    sed -e 's/[^\$]/ /g' |
    sed -e 's/\$/|/g '   |
    sed -e 's/| *$//'

  echo "${left_val}"

  # indent
  echo -n "${sentence}"  |
    sed -e 's/[^\$]/ /g' |
    sed -e 's/\$.*$//'

  echo "${right_val}"
}

# print descriptive messages
function powerassert_describe() {
  file="$1"
  line="$2"
  shift 2

  sentence=$(head "${file}" -n "${line}" | tail -n 1)

  echo "assertion error at ${file}: line ${line}"

  # trim commant and spaces
  sentence=$(echo "${sentence}" |
    sed -e 's/#.*$//'           |
    sed -e 's/^[[:space:]]*//'  |
    sed -e 's/[[:space:]]*$//')

  # expect sentence is one line
  if [[ ! ${sentence} =~ ^\[\[\[.*\]\]\]$ ]]; then
    return
  fi

  echo ""
  echo "${sentence}  ->  false"

  if [ "$#" -ne 3 ]; then
    powerassert_expand "$@"
    return
  fi

  # case: [[[ <left_name> <operator> <right_name> ]]]

  # remove spaces and brackets
  equation=$(echo "${sentence}"                  |
    sed -e 's/^[[:space:]]*\[\[\[[[:space:]]*//' |
    sed -e 's/[[:space:]]*\]\]\][[:space:]]*$//')

  left_name=""
  right_name=""

  # match to $a ${a} "$a" "${a}"
  if [[ ${equation} =~ ^\$[A-Za-z1-9?]+ ]]     ||
     [[ ${equation} =~ ^\$\{[A-Za-z1-9?]+\} ]] ||
     [[ ${equation} =~ ^\"\$[A-Za-z1-9?]+\" ]] ||
     [[ ${equation} =~ ^\"\$\{[A-Za-z1-9?]+\}\" ]]
  then
    left_name="${BASH_REMATCH[0]}"
  fi

  if [[ ${equation} =~ \$[A-Za-z1-9?]+$ ]]     ||
     [[ ${equation} =~ \$\{[A-Za-z1-9?]+\}$ ]] ||
     [[ ${equation} =~ \"\$[A-Za-z1-9?]+\"$ ]] ||
     [[ ${equation} =~ \"\$\{[A-Za-z1-9?]+\}\"$ ]]
  then
    right_name="${BASH_REMATCH[0]}"
  fi

  num_var=0
  if [ "${left_name}" != "" ]; then
    ((num_var++))
  fi
  if [ "${right_name}" != "" ]; then
    ((num_var++))
  fi

  if [ "${num_var}" -eq 0 ]; then
    return
  fi

  left_val="$1"
  operatior="$2"
  right_val="$3"

  case "${operatior}" in
    == )
      # if either of left or right value has two or more line, print diff
      if [ $(echo "${left_val}" | wc -l) -gt 1 ] ||
         [ $(echo "${right_val}" | wc -l) -gt 1 ]
      then
        powerassert_diff                 \
          "${left_name}" "${right_name}" \
          "${left_val}" "${right_val}"
        return
      fi

      if [ "${num_var}" -eq 2 ]; then
        powerassert_table                     \
          "${left_name}" "${right_name}"      \
          "\"${left_val}\"" "\"${right_val}\""
        return
      fi

      # ${num_val} -eq 1
      if [ "${left_name}" != "" ]; then
        val="${left_val}"
      else
        val="${right_val}"
      fi
      powerassert_single_point "${sentence}" "\"${val}\""
      return
      ;;

    != )
      echo ""
      echo "${left_name} == ${right_name}"
      echo " |"
      echo "\"${left_val}\""
      return
      ;;

    -eq | -ne | -lt | -gt | -le | -ge )
      if [ "${num_var}" -eq 2 ]; then
        powerassert_double_point \
          "${sentence}" "${left_val}" "${right_val}"
        return
      fi

      # ${num_val} -eq 1
      if [ "${left_name}" != "" ]; then
        val="${left_val}"
      else
        val="${right_val}"
      fi
      powerassert_single_point "${sentence}" "${val}"
      return
      ;;

    *)
      if [ "${num_var}" -ne 0 ]; then
        powerassert_expand "$@"
      fi
      return
      ;;
  esac
}

# substance of [[[ command
function powerassert_bracket() {

  # run in a sub shell for
  # 1. applying +xve option only in this function
  # 2. avoiding use local command
  # 3. print all to stderr
  (
    set +xve

    file="$1"
    line="$2"
    shift 2

    argv=("$@")
    if [ "${argv[$# - 1]}" != "]]]" ]; then
      echo "[[[: missing ']]]'"
      exit 2
    fi
    argv=("${argv[@]:0:$(($#-1))}")

    test "${argv[@]}"
    code="$?"

    case "${code}" in
      0 )
        # true
        exit 0
        ;;
      1 )
        # false
        powerassert_describe "${file}" "${line}" "${argv[@]}"
        exit 1
        ;;
      * )
        # other error
        echo "arguments: ${argv[@]}"
        exit "${code}"
        ;;
    esac
  ) >&2
}

# define [[[ command as alias.
# ${BASH_SOURCE} and ${LINENO} are expanded
# where [[[ command is executed.
shopt -s expand_aliases
alias [[[='powerassert_bracket "${BASH_SOURCE}" "${LINENO}"'
