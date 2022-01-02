#!/usr/bin/env bash
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT


STACK_NAME="deleteme-cfn-vpc-test"
declare -r STACK_NAME

TEMPLATE_FILE="vpc.json"
declare -r TEMPLATE_FILE

usage() {
  cat <<EOF
Usage: create_and_teardown.sh [-h] [-v] -b bucket -r region -p project

Create and delete the project stack and whatever test fixture stacks are required to test it

NOTE:  If the script errors out, it will run the cleanup function.
 - create the project stack and wait for it to finish
 - create the test fixture stack and wait for it to finish
 - pause for use to press a key
 - delete the stacks in reveres order waiting for each to finish

Available options:

-h, --help      Print this help and exit  
-v, --verbose   Print script debug info
-b, --bucket    upload templates to this bucket to run them
-r  --region    AWS region to run tests
-p  --project   Name of the project
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  msg "${GREEN}Cleaning up (destroying) stack: test-${STACK_NAME}${NOFORMAT}"
  aws cloudformation delete-stack --stack-name "test-${STACK_NAME}"
  aws cloudformation wait stack-delete-complete --stack-name "test-${STACK_NAME}"
  msg "${GREEN}Finished destroying stack: test-${STACK_NAME}${NOFORMAT}"
  aws cloudformation delete-stack --stack-name "${STACK_NAME}"
  aws cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}"
  msg "${GREEN}Finished destroying stack: ${STACK_NAME}${NOFORMAT}"
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    # shellcheck disable=SC2034
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  bucket=''
  region=''
  project=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -xv ;;
    --no-color) NO_COLOR=1 ;;
    -b | --bucket) # bucket name
      bucket="${2-}"
      shift
      ;;
    -r | --region) # AWS region
      region="${2-}"
      shift
      ;;
    -p | --project) # project name
      project="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  # check required params and arguments
  #[[ -z "${bucket-}" ]] && die "Missing required parameter: bucket"
  #[[ -z "${region-}" ]] && die "Missing required parameter: region"
  #[[ -z "${project-}" ]] && die "Missing required parameter: project"

  return 0
}

parse_params "$@"
setup_colors
COMMIT="$(git rev-parse HEAD)"
declare -r COMMIT
# script logic here

# create the stack under test. it exports output data for cross-stack references
create_stack() {
  aws cloudformation create-stack \
  --capabilities CAPABILITY_NAMED_IAM \
  --stack-name "${STACK_NAME}" \
  --template-body "file://${TEMPLATE_FILE}"
}

# after the stack is created, create the test stack whcih creates resources required to test
# the stack under test. it uses cross stack references with data exported from the stack under test
create_test_stack() {
   aws cloudformation create-stack \
   --capabilities CAPABILITY_NAMED_IAM \
   --stack-name "test-${STACK_NAME}" \
   --template-body "file://test_${TEMPLATE_FILE}"
 }

wait_for_continue() {
  msg "${GREEN}Press any key to continue to stack deletion${NOFORMAT}"
  while true ; do
    if read -r -t 3 -n 1 ; then
      break ;
    fi
  done
}

msg "${GREEN}Creating Stack: ${STACK_NAME}${NOFORMAT}"
create_stack
msg "${GREEN}Waiting for Stack to finish: ${STACK_NAME}${NOFORMAT}"
aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME}"


msg "${GREEN}Creating Test Stack: test-${STACK_NAME}${NOFORMAT}"
create_test_stack
msg "${GREEN}Waiting for Test Stack to finish: ${STACK_NAME}${NOFORMAT}"
aws cloudformation wait stack-create-complete --stack-name "test-${STACK_NAME}"

wait_for_continue

# the script runs the cleanup function before exiting