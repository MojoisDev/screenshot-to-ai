# Minimal dependency-free test harness.
TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
  # assert_eq <actual> <expected> <message>
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$1" = "$2" ]; then
    echo "PASS: $3"
  else
    echo "FAIL: $3"
    echo "  expected: [$2]"
    echo "  actual:   [$1]"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_contains() {
  # assert_contains <haystack> <needle> <message>
  TESTS_RUN=$((TESTS_RUN + 1))
  case "$1" in
    *"$2"*) echo "PASS: $3" ;;
    *)
      echo "FAIL: $3"
      echo "  expected to contain: [$2]"
      echo "  actual:              [$1]"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      ;;
  esac
}

finish() {
  echo "---"
  echo "$TESTS_RUN run, $TESTS_FAILED failed"
  [ "$TESTS_FAILED" -eq 0 ]
}
