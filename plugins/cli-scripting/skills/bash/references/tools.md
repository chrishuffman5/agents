# Bash Tools Reference

> grep, sed, awk, jq, find, sort, uniq, cut, process management, networking.

---

## 1. grep

```bash
# Basic usage
grep "pattern" file.txt
grep -i "pattern" file.txt        # case-insensitive
grep -v "pattern" file.txt        # invert (non-matching)
grep -n "pattern" file.txt        # line numbers
grep -c "pattern" file.txt        # count matches
grep -l "pattern" *.txt           # files with matches
grep -L "pattern" *.txt           # files WITHOUT matches

# Extended regex (-E)
grep -E "error|warning|critical" /var/log/syslog
grep -E "^[0-9]{4}-[0-9]{2}" log.txt
grep -E "\b[A-Z]{2,}\b" text.txt

# Perl regex (-P)
grep -P "(?<=user=)\w+" access.log
grep -P "\d{1,3}(\.\d{1,3}){3}" file

# Output only match
grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" access.log | sort -u

# Recursive
grep -r "TODO" ./src/ --include="*.sh" --exclude-dir=".git"

# Context
grep -A 3 "ERROR" app.log       # 3 lines after
grep -B 2 "ERROR" app.log       # 2 lines before
grep -C 2 "ERROR" app.log       # 2 lines context

# Real examples
grep -rn "TODO\|FIXME\|HACK" /opt/scripts/ --include="*.sh"
grep "ERROR" app.log | awk '{print $1, substr($2,1,5)}' | sort | uniq -c
```

---

## 2. sed

```bash
# Substitution
sed 's/foo/bar/' file.txt        # first per line
sed 's/foo/bar/g' file.txt       # all occurrences
sed 's/foo/bar/gi' file.txt      # all, case-insensitive (GNU)

# In-place
sed -i 's/old/new/g' file.txt
sed -i.bak 's/old/new/g' file.txt   # with backup

# Address ranges
sed '3s/foo/bar/' file.txt       # only line 3
sed '2,5s/foo/bar/' file.txt     # lines 2-5
sed '/start/,/end/s/foo/bar/' file.txt

# Delete lines
sed '/^#/d' config.txt           # delete comments
sed '/^$/d' file.txt             # delete blank lines

# Print specific lines
sed -n '10,20p' file.txt
sed -n '/START/,/END/p' file.txt

# Insert / append
sed '3i\New line before 3' file.txt
sed '/pattern/a\Added after match' file.txt

# Capture groups (ERE with -E)
echo "2025-03-15" | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/'

# Real examples
sed -i 's/[[:space:]]*$//' file.txt          # remove trailing whitespace
sed -n 's/^host=//p' config.txt              # extract value
sed -i '/^AllowRoot/s/^/#/' /etc/ssh/sshd_config   # comment out line
```

---

## 3. awk

```bash
# Fields: $0=whole line, $1=first field, $NF=last, NF=count
awk '{print $1, $3}' file.txt
awk -F: '{print $1, $7}' /etc/passwd

# Filter
awk '/ERROR/{print}' app.log
awk '$3 > 100 {print $1, $3}' data.txt
awk 'NR>=10 && NR<=20' file.txt

# BEGIN and END blocks
awk 'BEGIN{print "=== Report ==="} {print} END{print "=== Done ==="}' file

# Math and counters
awk '{sum += $1} END{print "Sum:", sum, "Avg:", sum/NR}' numbers.txt
awk '/ERROR/{count++} END{print "Errors:", count}' app.log

# Printf formatting
awk '{printf "%-20s %8.2f MB\n", $1, $2/1024}' data.txt

# Output separator
awk 'BEGIN{OFS=","} {print $1,$2,$3}' data.txt

# Associative arrays
awk '{count[$1]++} END{for(k in count) print k, count[k]}' log.txt

# Real examples
du -s /home/* | awk '{sum[$2]+=$1} END{for(u in sum)printf "%10d %s\n",sum[u],u}' | sort -rn
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -10
awk '/BEGIN_BLOCK/,/END_BLOCK/{if(!/BEGIN|END/)print}' file.txt
```

---

## 4. jq — JSON Processing

```bash
data='{"name":"Alice","age":30,"tags":["admin","user"]}'

# Basic access
echo "$data" | jq '.'                   # pretty print
echo "$data" | jq -r '.name'            # Alice (raw, no quotes)
echo "$data" | jq '.tags[0]'            # "admin"
echo "$data" | jq '.nonexistent // "default"'   # alternative operator

# Arrays
arr='[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"},{"id":3,"name":"Carol"}]'
echo "$arr" | jq 'length'               # 3
echo "$arr" | jq 'map(.name)'           # ["Alice","Bob","Carol"]
echo "$arr" | jq '[.[] | select(.id > 1)]'   # filter
echo "$arr" | jq 'sort_by(.name)'       # sort

# Transformations
echo "$arr" | jq -r '.[] | "\(.id): \(.name)"'   # string interpolation
echo "$arr" | jq '[.[] | {type: "user", (.name): .id}]'

# Group, unique, math
echo "$data_arr" | jq 'group_by(.type)'
echo "$data_arr" | jq '[.[].count] | add'         # sum
echo "$data_arr" | jq '[.[].count] | add / length' # average

# Shell variable injection
name="Alice"
echo "$arr" | jq --arg n "$name" '[.[] | select(.name == $n)]'
echo "$arr" | jq --argjson t 2 '[.[] | select(.id > $t)]'

# keys, values, entries
obj='{"a":1,"b":2,"c":3}'
echo "$obj" | jq 'keys'                 # ["a","b","c"]
echo "$obj" | jq 'to_entries | map(select(.value > 1)) | from_entries'

# Slurp multiple inputs
echo '{"a":1}
{"b":2}' | jq -s 'add'                  # {"a":1,"b":2}

# Construct from scratch
jq -n '{timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"), version: "1.0"}'
```

---

## 5. find

```bash
find /etc -name "*.conf"               # by name
find . -iname "*.CONF"                 # case-insensitive
find . -type f                         # files only
find . -type d                         # directories only

# By size
find /var -size +100M
find /tmp -size -1k
find . -empty

# By time
find /var/log -mtime -7                # modified in last 7 days
find /tmp -mtime +30                   # not modified in 30+ days
find . -newer /etc/hosts

# By permissions
find . -perm 644
find . -perm /111                      # any exec bit
find . -user root

# Actions
find . -name "*.tmp" -delete
find . -name "*.log" -exec gzip {} +
find . -name "*.sh" -print0 | xargs -0 chmod +x

# Depth and prune
find /etc -maxdepth 1 -type f
find . -path ./.git -prune -o -name "*.sh" -print

# Combine
find . -type f -name "*.sh" -size +1k -mtime -7
find . -name "*.sh" -o -name "*.bash"
```

---

## 6. sort, uniq, cut, wc

```bash
# sort
sort file.txt                          # lexicographic
sort -rn numbers.txt                   # numeric reverse
sort -k2,2n -k1,1 data.txt            # multi-key
sort -t: -k3,3n /etc/passwd            # custom delimiter
sort -u file.txt                       # unique

# uniq (input MUST be sorted)
sort file.txt | uniq -c                # count occurrences
sort file.txt | uniq -d                # only duplicates

# Common pattern: frequency count
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -10

# wc
wc -l file.txt                         # lines
wc -w file.txt                         # words

# cut
cut -d: -f1 /etc/passwd                # field 1
cut -d, -f2,4 data.csv                 # fields 2,4
cut -c1-10 file.txt                    # characters

# head / tail
head -n 20 file.txt
tail -n 20 file.txt
tail -f /var/log/syslog                # follow
tail -F /var/log/syslog                # follow by name (re-opens if rotated)

# comm (compare sorted files)
comm -12 <(sort file1) <(sort file2)   # lines in BOTH
comm -23 <(sort file1) <(sort file2)   # only in file1

# diff
diff -u file1 file2                    # unified format
diff -r dir1/ dir2/                    # recursive
```

---

## 7. Process Management

```bash
# List processes
ps aux | grep nginx
pgrep -l nginx
pgrep -u root

# Background
long_command &
echo "PID: $!"

# Job control
jobs; fg %1; bg %1; kill %1

# Wait for multiple
cmd1 & pid1=$!
cmd2 & pid2=$!
wait $pid1; echo "cmd1: $?"
wait $pid2; echo "cmd2: $?"

# Signals
kill -TERM $pid                        # graceful
kill -KILL $pid                        # force
kill -HUP $pid                         # reload config
kill -0 $pid && echo "running"         # check alive

killall nginx; pkill nginx
pkill -TERM -f "python.*script.py"

# nohup / disown / timeout
nohup long_command > output.log 2>&1 &
disown $!
timeout 30 curl https://example.com
```

---

## 8. Networking

### curl

```bash
# GET
curl -s https://api.example.com/data
curl -o output.json https://api.example.com

# Headers and auth
curl -H "Authorization: Bearer $TOKEN" url
curl -u username:password url

# POST
curl -X POST -d '{"name":"Alice"}' -H 'Content-Type: application/json' url
curl -X POST -F "file=@/path/to/file" url

# TLS
curl -k url                            # skip cert verification
curl --cacert ca.crt url
curl --cert client.crt --key client.key url

# Retry and timing
curl --retry 3 --retry-delay 2 url
http_code=$(curl -s -o /dev/null -w "%{http_code}" url)

# Download
curl -# -O https://example.com/file.zip
curl -L url                            # follow redirects
```

### ssh / scp / rsync

```bash
ssh user@host 'df -h'
ssh -i ~/.ssh/id_ed25519 user@host
ssh -L 8080:localhost:80 user@host     # local port forward
ssh -J jumpuser@jumphost target        # jump host
ssh user@host 'bash -s' < local_script.sh

scp file.txt user@host:/remote/path/
scp -r ./dir user@host:/remote/

rsync -avz src/ user@host:/dest/
rsync -avz --delete src/ host:/dest/
rsync -avz --exclude='*.log' src/ host:/dest/
rsync -avz --dry-run src/ host:/dest/

# nc (netcat)
nc -z -w 3 host 22 && echo "port open"
```
