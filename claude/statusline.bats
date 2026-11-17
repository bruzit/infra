#!/usr/bin/env bats
# shellcheck disable=SC2016  # $vars in single quotes are jq variables

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  export HOME=$BATS_TEST_TMPDIR/home XDG_RUNTIME_DIR=$BATS_TEST_TMPDIR/run COLUMNS=200 TZ=UTC
  mkdir -p "$HOME"
  mkdir -m 700 "$XDG_RUNTIME_DIR"
  SL=$BATS_TEST_DIRNAME/statusline
  NOW=$(date +%s)
}

plain() { sed -E $'s/\e\\[[0-9;]*m//g; s/\e\\]8;;[^\e]*\e\\\\//g'; }

sl() { "$SL" | plain; }

input() { jq -nc --argjson now "$NOW" --arg home "$HOME" "$1"; }

repo() {
  git init -q -b main "$1"
  git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}

@test "renders both rows from full input" {
  run sl <<<"$(input '{
    model: {display_name: "Opus 5.5"}, effort: {level: "medium"},
    workspace: {current_dir: "\($home)/Projects/statusline-test"},
    context_window: {used_percentage: 21, total_input_tokens: 208000, context_window_size: 1000000},
    exceeds_200k_tokens: true,
    prompt_cache: {warm: true, expires_at: ($now + 3570), ttl: "1h"},
    rate_limits: {five_hour: {used_percentage: 4, resets_at: ($now + 3600)},
                  seven_day: {used_percentage: 14, resets_at: ($now + 172800)}}}')"
  assert_success
  assert_line -n 0 'Opus 5.5 · medium │ ~/Projects/statusline-test'
  assert_line -n 1 "ctx ██░░░░░░░░ 21% 208k/1M ⚑ │ cache ✓ 59m │ 5h 4% ↻ $(date -d "@$((NOW + 3600))" +%H:%M) │ 7d 14% ↻ $(date -d "@$((NOW + 172800))" '+%a %H:%M')"
}

@test "empty object degrades to placeholders" {
  run sl <<<'{}'
  assert_success
  assert_line -n 0 '? │ '
  assert_line -n 1 'ctx – │ cache –'
}

@test "malformed or missing input still exits 0" {
  run sl <<<'not json'
  assert_success
  assert_output 'status line: no input'
  run sl </dev/null
  assert_success
  assert_output 'status line: no input'
}

@test "missing jq is reported" {
  mkdir "$BATS_TEST_TMPDIR/bin"
  ln -s "$(command -v bash)" "$BATS_TEST_TMPDIR/bin/bash"
  run env PATH="$BATS_TEST_TMPDIR/bin" "$SL" <<<'{}'
  assert_success
  assert_output --partial 'status line: jq missing'
}

@test "control characters in input are stripped" {
  run "$SL" <<<'{"model":{"display_name":"a\u001b]0;pwned\u0007b\u009bc\u007fd"},"effort":{"level":"x\ny"}}'
  assert_success
  refute_output --partial $'\a'
  refute_output --partial $'\e]0'
  refute_output --partial $'\u009b'
  refute_output --partial $'\x7f'
  assert_line -n 0 --partial 'a]0;pwnedbcd'
  assert_line -n 0 --partial 'xy'
}

@test "out-of-range and non-numeric numbers are dropped" {
  run sl <<<'{"context_window":{"used_percentage":1e300,"total_input_tokens":"1; rm -rf /"},"rate_limits":{"five_hour":{"used_percentage":"9"}}}'
  assert_success
  assert_line -n 1 'ctx – │ cache –'
}

@test "narrow terminal drops reset times and token counts" {
  run env COLUMNS=60 "$SL" <<<"$(input '{
    context_window: {used_percentage: 21, total_input_tokens: 208000, context_window_size: 1000000},
    prompt_cache: {warm: true, expires_at: ($now + 3570)},
    rate_limits: {five_hour: {used_percentage: 4, resets_at: ($now + 3600)},
                  seven_day: {used_percentage: 14, resets_at: ($now + 172800)}}}')"
  assert_success
  run plain <<<"$output"
  assert_line -n 1 'ctx ██░░░░░░░░ 21% │ cache ✓ 59m │ 5h 4% ↻ '"$(date -d "@$((NOW + 3600))" +%H:%M)"' │ 7d 14%'
}

@test "home directory is shortened and long paths truncated" {
  run env COLUMNS=40 "$SL" <<<"$(input '{workspace: {current_dir: "\($home)/a/very/long/path/that/does/not/fit/anywhere"}}')"
  assert_success
  run plain <<<"$output"
  assert_line -n 0 --regexp '^\? │ …[^~]+/anywhere$'
}

@test "cold prompt cache shows recache cost" {
  run sl <<<'{"prompt_cache":{"warm":false,"recache_tokens_if_cold":150000}}'
  assert_line -n 1 'ctx – │ cache ✗ 150k'
}

@test "low cache hit ratio shows top miss cause" {
  run sl <<<"$(input '{prompt_cache: {warm: true, expires_at: ($now + 3570), hit_ratio: 0.42, misses: 3, miss_causes: {tools_changed: 2, ttl: 1}}}')"
  assert_line -n 1 'ctx – │ cache ✓ 59m 42% ⚠ tools_changed'
}

@test "rate limit ahead of pace is flagged" {
  run sl <<<"$(input '{rate_limits: {five_hour: {used_percentage: 90, resets_at: ($now + 9000)}}}')"
  assert_line -n 1 --partial '5h 90% ▲ ↻'
}

@test "git branch, dirty state and ahead count are right-aligned" {
  repo "$BATS_TEST_TMPDIR/up"
  git clone -q "$BATS_TEST_TMPDIR/up" "$BATS_TEST_TMPDIR/w"
  git -C "$BATS_TEST_TMPDIR/w" -c user.name=t -c user.email=t@t commit -q --allow-empty -m ahead
  touch "$BATS_TEST_TMPDIR/w/new"
  run sl <<<"$(jq -nc --arg d "$BATS_TEST_TMPDIR/w" '{workspace: {current_dir: $d}}')"
  assert_success
  assert_line -n 1 --regexp '^ctx – │ cache – +main ✱ ↑1$'
}

@test "detached HEAD shows short commit" {
  repo "$BATS_TEST_TMPDIR/w"
  git -C "$BATS_TEST_TMPDIR/w" checkout -q --detach
  run sl <<<"$(jq -nc --arg d "$BATS_TEST_TMPDIR/w" '{workspace: {current_dir: $d}}')"
  assert_line -n 1 --regexp " $(git -C "$BATS_TEST_TMPDIR/w" rev-parse --short=7 HEAD)$"
}

@test "repository fsmonitor command is not executed" {
  repo "$BATS_TEST_TMPDIR/w"
  printf '#!/bin/sh\ntouch "%s"\n' "$BATS_TEST_TMPDIR/pwned" >"$BATS_TEST_TMPDIR/hook"
  chmod +x "$BATS_TEST_TMPDIR/hook"
  git -C "$BATS_TEST_TMPDIR/w" config core.fsmonitor "$BATS_TEST_TMPDIR/hook"
  run sl <<<"$(jq -nc --arg d "$BATS_TEST_TMPDIR/w" '{workspace: {current_dir: $d}}')"
  assert_line -n 1 --partial 'main'
  assert [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
  git -C "$BATS_TEST_TMPDIR/w" status >/dev/null
  assert [ -e "$BATS_TEST_TMPDIR/pwned" ]
}

@test "git info is cached per session" {
  repo "$BATS_TEST_TMPDIR/w"
  json=$(jq -nc --arg d "$BATS_TEST_TMPDIR/w" '{session_id: "s1", workspace: {current_dir: $d}}')
  run sl <<<"$json"
  assert_line -n 1 --partial 'main'
  git -C "$BATS_TEST_TMPDIR/w" checkout -q -b other
  run sl <<<"$json"
  assert_line -n 1 --partial 'main'
  assert [ "$(stat -c %a "$XDG_RUNTIME_DIR/claude-statusline")" = 700 ]
}

@test "symlinked cache directory is not written through" {
  repo "$BATS_TEST_TMPDIR/w"
  mkdir "$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$XDG_RUNTIME_DIR/claude-statusline"
  run sl <<<"$(jq -nc --arg d "$BATS_TEST_TMPDIR/w" '{session_id: "s1", workspace: {current_dir: $d}}')"
  assert_line -n 1 --partial 'main'
  assert [ -z "$(ls -A "$BATS_TEST_TMPDIR/elsewhere")" ]
}

@test "pull request links only https URLs" {
  run "$SL" <<<'{"pr":{"number":12,"url":"https://github.com/o/r/pull/12","review_state":"approved"}}'
  assert_output --partial $'\e]8;;https://github.com/o/r/pull/12\e\\#12'
  run "$SL" <<<'{"pr":{"number":12,"url":"file:///etc/passwd","review_state":"draft"}}'
  refute_output --partial $'\e]8;;'
  run plain <<<"$output"
  assert_line -n 1 --regexp ' #12 ◌ draft$'
}
