#!/usr/bin/env bash

readonly SUMMARY_FMT="%-30s%s"
readonly ORDINALS=( first second third fourth fifth sixth seventh eighth ninth tenth )

warnings=()

info() {
  echo "${INFO_COLOR}$*${RESTORE}"
}

infof() {
  local format_string="$1"
  shift
  # the format string is constructed from the caller's input. There is no
  # good way to rewrite this that will not trigger SC2059, so outright
  # disable it here.
  # shellcheck disable=SC2059
  printf "${INFO_COLOR}${format_string}${RESTORE}\n" "$@"
}

warn() {
  echo "${WARN_COLOR}WARNING: $*${RESTORE}"
}

debug() {
  if [[ "$_arg_debug" == "on" ]]; then
    echo "${DEBUG_COLOR}$*${RESTORE}"
  fi
}

summary_row() {
    infof "${SUMMARY_FMT}" "$1" "${2:-${WARN_COLOR}<unknown>${RESTORE}}"
}

comparison_summary_row() {
  local header value
  header="$1"
  shift;

  if [[ "$1" == "$2" ]]; then
    value="$1"
  else
    value="${WARN_COLOR}${1:-<unknown>} | ${2:-<unknown>}${RESTORE}"
  fi

  summary_row "${header}" "${value}"
}

print_bl() {
  if [[ "$_arg_debug" == "on" ]]; then
    debug "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  else
    echo
  fi
}

# Strips color codes from Standard in. This function is intended to be used as a filter on another command:
# print_summary | strip_color_codes
strip_color_codes() {
  # shellcheck disable=SC2001  # I could only get this to work with sed
  sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g'
}

read_build_warnings() {
  if [[ "${build_outcomes[0]}" == "FAILED" ]]; then
    warnings+=("The first build failed. This may skew the outcome of the experiment.")
  fi
  if [[ "${build_outcomes[1]}" == "FAILED" ]]; then
    warnings+=("The second build failed. This may skew the outcome of the experiment.")
  fi

  local warnings_file="${EXP_DIR}/warnings.txt"
  if [ -f "${warnings_file}" ]; then
    while read -r l; do
      warnings+=("$l")
    done <"${warnings_file}"
  fi
}

print_warnings() {
  read_build_warnings
  if [[ ${#warnings[@]} -gt 0 ]]; then
    print_bl
    for (( i=0; i<${#warnings[@]}; i++ )); do
      warn "${warnings[i]}"
    done
  fi
}

print_summary() {
  #defined in build_scan.sh
  read_build_scan_metadata
  #defined in build_scan.sh
  detect_warnings_from_build_scans

  info "Summary"
  info "-------"
  print_experiment_info
  print_experiment_specific_summary_info
  print_build_scans
  print_warnings
  print_performance_metrics

  if [[ "${build_scan_publishing_mode}" == "on" ]]; then
    print_bl
    print_quick_links
  fi
}

print_experiment_info() {
  comparison_summary_row "Project:" "${project_names[@]}"
  comparison_summary_row "Git repo:" "${git_repos[@]}"
  comparison_summary_row "Git branch:" "${git_branches[@]}"
  comparison_summary_row "Git commit id:" "${git_commit_ids[@]}"
  summary_row "Git options:" "${git_options}"
  summary_row "Project dir:" "${project_dir:-<root directory>}"
  comparison_summary_row "${BUILD_TOOL} ${BUILD_TOOL_TASK}s:" "${requested_tasks[@]}"
  summary_row "${BUILD_TOOL} arguments:" "${extra_args:-<none>}"
  summary_row "Experiment:" "${EXP_NO} ${EXP_NAME}"
  summary_row "Experiment id:" "${EXP_SCAN_TAG}"
  if [[ "${SHOW_RUN_ID}" == "true" ]]; then
    summary_row "Experiment run id:" "${RUN_ID}"
  fi
  summary_row "Experiment artifact dir:" "$(relative_path "${SCRIPT_DIR}" "${EXP_DIR}")"
}

print_experiment_specific_summary_info() {
  # this function is intended to be overridden by experiments as-needed
  # have one command to satisfy shellcheck
  true
}

print_performance_metrics() {
  # this function is intended to be overridden by experiments as-needed
  # have one command to satisfy shellcheck
  true
}

print_performance_characteristics() {
  print_performance_characteristics_header

  print_realized_build_time_savings

  print_build_caching_leverage_metrics

  print_executed_cacheable_tasks_warning
}

print_performance_characteristics_header() {
  print_bl
  info "Performance Characteristics"
  info "----------------------"
}

print_realized_build_time_savings() {
  local value
  value=""
  if [[ -n "${effective_task_execution_duration[0]}" && -n "${effective_task_execution_duration[1]}" ]]; then
    local first_build second_build realized_savings
    first_build=$(format_duration "${effective_task_execution_duration[0]}")
    second_build=$(format_duration "${effective_task_execution_duration[1]}")
    realized_savings=$(format_duration effective_task_execution_duration[0]-effective_task_execution_duration[1])
    value="${realized_savings} wall-clock time (from ${first_build} to ${second_build})"
  fi
  summary_row "Realized build time savings:" "${value}"
}

print_build_caching_leverage_metrics() {
  local task_count_padding
  task_count_padding=$(max_length "${avoided_from_cache_num_tasks[1]}" "${executed_cacheable_num_tasks[1]}" "${executed_not_cacheable_num_tasks[1]}")

  local value
  value=""
  if [[ "${avoided_from_cache_num_tasks[1]}" ]]; then
    local taskCount
    taskCount="$(printf "%${task_count_padding}s" "${avoided_from_cache_num_tasks[1]}" )"
    value="${taskCount} ${BUILD_TOOL_TASK}s, $(format_duration avoided_from_cache_avoidance_savings[1]) total saved execution time"
  fi
  summary_row "Avoided cacheable ${BUILD_TOOL_TASK}s:" "${value}"

  value=""
  if [[ "${executed_cacheable_num_tasks[1]}" ]]; then
    local summary_color
    summary_color=""
    if (( executed_cacheable_num_tasks[1] > 0)); then
      summary_color="${WARN_COLOR}"
    fi

    taskCount="$(printf "%${task_count_padding}s" "${executed_cacheable_num_tasks[1]}" )"
    value="${summary_color}${taskCount} ${BUILD_TOOL_TASK}s, $(format_duration executed_cacheable_duration[1]) total execution time${RESTORE}"
  fi
  summary_row "Executed cacheable ${BUILD_TOOL_TASK}s:" "${value}"

  value=""
  if [[ "${executed_not_cacheable_num_tasks[1]}" ]]; then
    taskCount="$(printf "%${task_count_padding}s" "${executed_not_cacheable_num_tasks[1]}" )"
    value="${taskCount} ${BUILD_TOOL_TASK}s, $(format_duration executed_not_cacheable_duration[1]) total execution time"
  fi
  summary_row "Executed non-cacheable ${BUILD_TOOL_TASK}s:" "${value}"
}

print_executed_cacheable_tasks_warning() {
  if (( executed_cacheable_num_tasks[1] > 0)); then
    print_bl
    warn "Not all cacheable ${BUILD_TOOL_TASK}s' outputs were taken from the build cache in the second build. This reduces the savings in ${BUILD_TOOL_TASK} execution time."
  fi
}

max_length() {
  local max_len

  max_len=${#1}
  shift

  for x in "${@}"; do
    if (( ${#x} > max_len )); then
      max_len=${#x}
    fi
  done

  echo "${max_len}"
}

warn_if_nonzero() {
  local value
  value=$1
  if (( value > 0 )); then
    echo "${WARN_COLOR}${value}${RESTORE}"
  else
    echo "$value"
  fi
}

print_build_scans() {
  for (( i=0; i<2; i++ )); do
    if [[ "${build_scan_publishing_mode}" == "on" ]]; then
      if [ -z "${build_outcomes[i]}" ]; then
        summary_row "Build scan ${ORDINALS[i]} build:" "${WARN_COLOR}${build_scan_urls[i]:+${build_scan_urls[i]} }BUILD SCAN DATA FETCH FAILED${RESTORE}"
      elif [[ "${build_outcomes[i]}" == "FAILED" ]]; then
        summary_row "Build scan ${ORDINALS[i]} build:" "${WARN_COLOR}${build_scan_urls[i]:+${build_scan_urls[i]} }FAILED${RESTORE}"
      else
        summary_row "Build scan ${ORDINALS[i]} build:" "${build_scan_urls[i]}"
      fi
    else
      summary_row "Build scan ${ORDINALS[i]} build:" "<publication disabled>"
    fi
  done
}

create_receipt_file() {
  {
  print_summary | strip_color_codes
  print_bl
  print_command_to_repeat_experiment | strip_color_codes
  print_bl
  echo "Generated by $(print_version)"
  } > "${RECEIPT_FILE}"
}

format_duration() {
  local duration=$1
  local hours=$((duration/60/60/1000))
  local minutes=$((duration/60/1000%60))
  local seconds=$((duration/1000%60%60))
  local millis=$((duration%1000))

  if [[ "${hours}" != 0 ]]; then
    printf "%dh " "${hours}"
  fi

  if [[ "${minutes}" != 0 ]]; then
    printf "%dm " "${minutes}"
  fi

  printf "%d.%03ds" "${seconds}" "${millis}"
}
