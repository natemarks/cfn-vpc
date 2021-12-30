#!/usr/bin/env bash
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

usage() {
  cat <<EOF
Usage: run_tests.sh [-h] [-v] -b bucket -r region -p project

Upload the templates to a bucket and run all of the test iterations

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
  msg "${GREEN}Cleaning up (deleting) stack: ${STACK_NAME}${NOFORMAT}"
  aws cloudformation delete-stack --stack-name "${STACK_NAME}"
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

msg "${RED}Read parameters:${NOFORMAT}"
msg "- bucket: ${bucket}"
msg "- region: ${region}"
msg "- project: ${project}"

# s3_path_exists com.imprivata.709310380790.us-east-1.cloudformation-templates/my_dir
# if s3_path_exists "some_bucket/some_dir"; then
#   msg "${RED}Bucket path already exists: some_bucket/some_dir ${NOFORMAT}"
#   exit 1
# fi
s3_path_exists() {
  aws s3 ls "s3://${1}"
  status=$?
  if [ $status -eq 0 ]
  then
    true
  else
    false
  fi
}

upload_templates() {
  msg "${GREEN}Uploading to: ${bucket}/cfntest/${project}/${COMMIT} ${NOFORMAT}"
  if s3_path_exists "${bucket}/cfntest/${project}/${COMMIT}"; then
    msg "${RED}Bucket path already exists: ${bucket} ${NOFORMAT}"
    exit 1
  fi
  aws s3 cp templates "s3://${bucket}/cfntest/${project}/${COMMIT}" --recursive
}

# upload_templates 
create_stack() {
  aws cloudformation create-stack \
  --stack-name "${STACK_NAME}" \
  --template-body "file://vpc.json"
}

wait_for_continue() {
  msg "${GREEN}Press any key to continue to stack deletion${NOFORMAT}"
  while true ; do
    if read -r -t 3 -n 1 ; then
      break ;
    fi
  done
}

STACK_NAME="deleteme-cfn-vpc"
declare -r STACK_NAME
create_stack
aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME}"
msg "${GREEN}Creating Stack: ${STACK_NAME}${NOFORMAT}"
wait_for_continue

