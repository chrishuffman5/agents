# Bash Language Reference

> Variables, parameter expansion, quoting, control flow, functions, I/O, strings, error handling.

---

## 1. Variables and Quoting

```bash
# NO spaces around =
name="Alice"
readonly PI=3.14159
declare -r MAXCONN=100
export DATABASE_URL="postgres://localhost/mydb"
declare -i count=0; count+=5   # integer type

# Quoting rules
var="world"
echo "Hello $var"              # Hello world (double: expands)
echo 'Hello $var'              # Hello $var  (single: literal)
echo $'Line1\nLine2'           # ANSI-C quoting — interprets \n \t

# ALWAYS quote variables
file="my file (1).txt"
ls "$file"                     # correct
# ls $file                    # WRONG: word splitting

# Command substitution
today=$(date +%Y-%m-%d)
parent=$(dirname $(realpath "$0"))
output=$(printf 'line1\nline2')
echo "$output"                 # preserves newlines

# Arithmetic
echo $((10 + 3))              # 13
echo $((10 ** 3))             # 1000
((count++))
result=$(echo "scale=4; 22/7" | bc)   # floats via bc
```

## 2. Arrays

```bash
# Indexed arrays
arr=(alpha beta gamma delta)
echo "${arr[0]}"               # alpha
echo "${arr[-1]}"              # delta (last, bash 4.3+)
echo "${arr[@]}"               # all elements
echo "${#arr[@]}"              # 4 (count)
echo "${!arr[@]}"              # 0 1 2 3 (indices)
arr+=("epsilon")               # append
echo "${arr[@]:1:2}"           # beta gamma (slice)

for item in "${arr[@]}"; do echo "Item: $item"; done
for i in "${!arr[@]}"; do echo "$i: ${arr[$i]}"; done

# Associative arrays (requires declare -A)
declare -A config
config[host]="localhost"
config[port]="5432"
echo "${config[host]}"
echo "${!config[@]}"           # keys
[[ -v config[host] ]] && echo "key exists"
for key in "${!config[@]}"; do echo "$key=${config[$key]}"; done
```

## 3. Parameter Expansion

```bash
var="Hello World"

# Defaults
echo "${var:-default}"          # Hello World (set, use it)
echo "${empty:-default}"        # default (empty, use default)
echo "${empty:=assigned}"       # assigned AND sets the variable

# Error if unset
# echo "${undefined:?Not set}"  # exits with error

# String operations
echo "${#var}"                  # 11 (length)

# Remove suffix/prefix
path="/usr/local/bin/script.sh"
echo "${path%/*}"               # /usr/local/bin (shortest suffix)
echo "${path%%/*}"              # (empty — longest suffix)
echo "${path#*/}"               # usr/local/bin/script.sh (shortest prefix)
echo "${path##*/}"              # script.sh (longest prefix = basename!)

# Replacement
echo "${var/World/Bash}"        # Hello Bash (first match)
echo "${var//o/0}"              # Hell0 W0rld (all matches)

# Substring
echo "${var:6}"                 # World
echo "${var:0:5}"               # Hello
echo "${var: -5}"               # World (space before - required)

# Case conversion (bash 4+)
echo "${var^^}"                 # HELLO WORLD
echo "${var,,}"                 # hello world
echo "${var^}"                  # Hello World (first char upper)
```

## 4. Control Flow

```bash
# if / elif / else
x=42
if [[ $x -gt 100 ]]; then echo "big"
elif [[ $x -gt 10 ]]; then echo "medium"
else echo "small"
fi

# Arithmetic if
if ((x > 10 && x < 100)); then echo "between"; fi

# [[ ]] tests
[[ -z "$s" ]]                  # zero length
[[ -n "$s" ]]                  # non-empty
[[ "$s" == "hello" ]]          # string equal
[[ "$s" =~ ^h.*o$ ]]           # regex match
[[ "$s" == h* ]]               # glob match (no quotes on pattern)

# Numeric tests
[[ $n -eq 5 ]]                 # equal
[[ $n -gt 3 ]]                 # greater than
((n > 3 && n < 10))            # cleaner arithmetic

# File tests
[[ -e /etc/hosts ]]            # exists
[[ -f /etc/hosts ]]            # regular file
[[ -d /etc ]]                  # directory
[[ -r /etc/hosts ]]            # readable
[[ -x /bin/bash ]]             # executable
[[ -s /etc/hosts ]]            # non-empty
[[ file1 -nt file2 ]]         # newer than

# case / esac
case "$day" in
  Monday|Tuesday|Wednesday|Thursday|Friday) echo "Weekday" ;;
  Saturday|Sunday) echo "Weekend" ;;
  *) echo "Unknown" ;;
esac

# Loops
for fruit in apple banana cherry; do echo "$fruit"; done
for i in {1..5}; do echo $i; done
for ((i=0; i<5; i++)); do echo "i=$i"; done

while [[ $count -lt 5 ]]; do ((count++)); done

# Read file line by line
while IFS= read -r line || [[ -n "$line" ]]; do
  echo ">>> $line"
done < /etc/hosts

# Field splitting
while IFS=: read -r user pass uid gid gecos home shell; do
  echo "User: $user, Shell: $shell"
done < /etc/passwd

# break with level / continue
for i in {1..3}; do
  for j in {1..3}; do
    [[ $j -eq 2 ]] && break 2
  done
done
```

## 5. Functions

```bash
greet() { echo "Hello, $1!"; }
function greet_v2 { echo "Hello, $1!"; }

# Local variables
calculate() {
  local result a=$1 b=$2
  result=$((a * b))
  echo "$result"
}
r=$(calculate 6 7)   # 42

# Return codes vs output
is_even() { (($1 % 2 == 0)); }
is_even 4 && echo "even" || echo "odd"

# Namerefs (declare -n)
increment() { declare -n _ref=$1; ((_ref++)); }
counter=10; increment counter; echo "$counter"   # 11
```

## 6. I/O and Redirection

```bash
command > out.txt              # stdout to file (overwrite)
command >> out.txt             # append
command 2> err.txt             # stderr to file
command &> all.txt             # both to file (bash 4+)
command > /dev/null 2>&1       # discard both

# Here-docs
cat <<EOF
Host: $(hostname)
User: $USER
EOF

cat <<'EOF'                    # no expansion (quoted delimiter)
Literal: $USER $(date)
EOF

# Here-strings
grep "pattern" <<< "This has the pattern"
read -r first last <<< "John Doe"

# Process substitution
diff <(ls /bin) <(ls /usr/bin)
while IFS= read -r line; do ((count++)); done < <(cat /etc/hosts)

# tee
command | tee output.txt       # stdout AND file
command | tee -a output.txt    # append
```

## 7. Error Handling

```bash
# Script header
set -euo pipefail
IFS=$'\n\t'

# trap
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT
trap 'echo "Error at line $LINENO (exit $?)"; exit 1' ERR
trap 'echo "Interrupted"; exit 130' INT

# die pattern
die() { echo "ERROR: ${1:-Unknown}" >&2; exit "${2:-1}"; }
cd /some/dir || die "Cannot cd"

# Require tools
require_cmd() { command -v "$1" &>/dev/null || die "Required: $1"; }

# Retry with backoff
retry() {
  local max=$1 delay=$2; shift 2
  local attempt=1
  while true; do
    "$@" && return 0
    ((attempt >= max)) && { echo "Failed after $max attempts" >&2; return 1; }
    echo "Attempt $attempt failed, retrying in ${delay}s..." >&2
    sleep "$delay"; ((attempt++)); ((delay *= 2))
  done
}
retry 3 2 curl -s https://api.example.com/health
```

## 8. String Operations

```bash
str="Hello, World!"
echo "${str:7}"                # World!
echo "${str:7:5}"              # World
echo "${#str}"                 # 13

# Regex matching
email="user@example.com"
if [[ "$email" =~ ^([^@]+)@([^@]+)$ ]]; then
  echo "User: ${BASH_REMATCH[1]}"
  echo "Domain: ${BASH_REMATCH[2]}"
fi

# printf formatting
printf "Name: %-20s Age: %3d\n" "Alice" 30
printf "%05d\n" 42              # 00042
printf "%.2f\n" 3.14159        # 3.14
formatted=$(printf "%04d-%02d-%02d" 2025 3 5)
```
