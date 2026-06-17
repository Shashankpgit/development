# Part 07 — Text Processing: pipes, sort, cut, awk, sed, wc, uniq

Linux's power comes from chaining small tools together with pipes. This file teaches you how to build pipelines that slice, sort, and transform text — the skill that separates someone who uses Linux from someone who is productive in Linux.

---

## The Pipe `|` — The Core of Linux Power

A pipe (`|`) takes the **output of one command** and feeds it as **input to the next command**. You can chain as many commands as you want.

```bash
command1 | command2 | command3
```

**Real example:**

```bash
# Without pipes — three separate steps, messy
ps aux > /tmp/processes.txt
grep "nginx" /tmp/processes.txt > /tmp/nginx.txt
cat /tmp/nginx.txt

# With pipes — one clean line
ps aux | grep nginx
```

Every command in a pipe reads from standard input (stdin) and writes to standard output (stdout). The pipe connects stdout of one command to stdin of the next.

---

## `sort` — Sort Lines of Text

```bash
sort file.txt              # alphabetical sort
sort -r file.txt           # reverse (Z→A)
sort -n numbers.txt        # numeric sort (treats values as numbers, not strings)
sort -h sizes.txt          # human-readable numeric sort (10K, 5M, 2G)
sort -u file.txt           # unique — removes duplicate lines (sort + uniq)
sort -k2 data.txt          # sort by the 2nd column/field
sort -t: -k3 -n /etc/passwd   # sort /etc/passwd by 3rd field (UID), using : as delimiter
```

**Why numeric sort matters:**

```bash
# Without -n (string sort — wrong for numbers!)
echo -e "10\n2\n100\n1" | sort
# 1
# 10
# 100
# 2   ← 2 comes AFTER 100 alphabetically!

# With -n (numeric sort — correct)
echo -e "10\n2\n100\n1" | sort -n
# 1
# 2
# 10
# 100
```

---

## `uniq` — Remove or Count Duplicate Lines

`uniq` only removes **adjacent** duplicates. Always sort first.

```bash
sort file.txt | uniq          # remove duplicate lines
sort file.txt | uniq -c       # count occurrences of each line
sort file.txt | uniq -d       # show only DUPLICATE lines
sort file.txt | uniq -u       # show only UNIQUE lines (appear once)
```

**Real use — find most common IPs in web logs:**

```bash
# access.log has one IP per request line
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10
# Shows the top 10 most frequent IP addresses
```

---

## `cut` — Extract Columns from Text

```bash
cut -d: -f1 /etc/passwd        # -d: = delimiter is colon, -f1 = field 1
cut -d: -f1,3 /etc/passwd      # fields 1 and 3
cut -d, -f2 data.csv           # CSV: get second column
cut -c1-10 file.txt            # characters 1 to 10 of each line
cut -c5- file.txt              # from character 5 to end of line
```

**Example with /etc/passwd:**

```
root:x:0:0:root:/root:/bin/bash
shashank:x:1000:1000::/home/shashank:/bin/bash
```

```bash
cut -d: -f1 /etc/passwd        # get all usernames (field 1)
# root
# shashank

cut -d: -f1,6 /etc/passwd      # username and home directory
# root:/root
# shashank:/home/shashank
```

---

## `awk` — Powerful Column-Based Text Processing

`awk` is a mini-programming language for processing structured text line by line. It automatically splits each line into fields.

```bash
awk '{print $1}' file.txt         # print the 1st field (space-separated)
awk '{print $1, $3}' file.txt     # print fields 1 and 3
awk '{print NR, $0}' file.txt     # NR = line number, $0 = entire line
awk -F: '{print $1}' /etc/passwd  # -F: = use colon as field separator
```

**awk built-in variables:**
- `$0` — the entire line
- `$1`, `$2`, `$3`... — field 1, 2, 3...
- `NF` — number of fields on the current line
- `NR` — current line number
- `FS` — field separator (default: whitespace)

**Real examples:**

```bash
# Show PID and command name from ps output
ps aux | awk '{print $2, $11}'

# Show nginx requests over 1000ms from access.log
# Access log format: IP - - [date] "METHOD path protocol" status size time
awk '$NF > 1.0' /var/log/nginx/access.log    # last field (response time) > 1 second

# Sum all numbers in column 5 of a file
awk '{sum += $5} END {print sum}' data.txt

# Process only lines where 3rd field equals "ERROR"
awk '$3 == "ERROR" {print $0}' app.log

# Print lines between a pattern (like grep -A but more control)
awk '/START/,/END/' file.txt     # print lines from START to END
```

---

## `sed` — Stream Editor for Find/Replace and Transformations

`sed` (Stream EDitor) processes text transformations line by line without opening an editor.

### Basic find and replace:

```bash
sed 's/old/new/' file.txt          # replace FIRST occurrence per line
sed 's/old/new/g' file.txt         # replace ALL occurrences per line (g=global)
sed 's/old/new/i' file.txt         # case-insensitive replace
sed 's/ERROR/[ERROR]/g' app.log    # add brackets around ERROR
```

### Edit files in place:

```bash
sed -i 's/localhost/production.db.server/g' config.json
# -i = in-place editing (modifies the actual file, not just stdout)

# Safer: make a backup before editing
sed -i.bak 's/localhost/production.db/g' config.json
# Creates config.json.bak as backup, then modifies config.json
```

### Delete lines matching a pattern:

```bash
sed '/^#/d' config.txt            # delete comment lines (starting with #)
sed '/^$/d' file.txt              # delete empty lines
sed '5d' file.txt                 # delete line 5
sed '5,10d' file.txt              # delete lines 5 through 10
```

### Print specific lines:

```bash
sed -n '5p' file.txt              # print only line 5
sed -n '5,10p' file.txt           # print lines 5 through 10
sed -n '/ERROR/p' app.log         # print only lines containing ERROR (like grep)
```

### Real-world config file editing:

```bash
# Change port 80 to port 8080 in nginx config
sudo sed -i 's/listen 80/listen 8080/g' /etc/nginx/nginx.conf

# Remove all blank lines from a script
sed -i '/^$/d' deploy.sh

# Comment out a line containing a specific pattern
sed -i 's/^SELINUX=enforcing/# SELINUX=enforcing/' /etc/selinux/config
```

---

## `tr` — Translate or Delete Characters

```bash
tr 'a-z' 'A-Z'              # lowercase to uppercase
tr 'A-Z' 'a-z'              # uppercase to lowercase
tr -d '\r'                  # delete carriage returns (fix Windows line endings)
tr -d ' '                   # delete all spaces
tr -s ' '                   # squeeze repeated spaces into one
tr ':' '\n'                 # replace colons with newlines
```

`tr` reads from stdin — always used with a pipe or redirection:

```bash
echo "Hello World" | tr 'a-z' 'A-Z'
# HELLO WORLD

cat windows-file.txt | tr -d '\r' > linux-file.txt
# Remove Windows carriage returns
```

---

## Building Real Pipelines

This is where everything comes together. Complex tasks become one-liners.

### Top 10 most accessed URLs in nginx log:

```bash
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10
#     │                                        │          │          │       │
#     │                                        │          │          │       └── show top 10
#     │                                        │          │          └── sort by count (highest first)
#     │                                        │          └── count + remove duplicates
#     │                                        └── sort alphabetically (uniq needs sorted input)
#     └── extract URL (field 7 in combined log format)
```

### Find all unique IP addresses that got a 403 error:

```bash
grep " 403 " /var/log/nginx/access.log | awk '{print $1}' | sort -u
```

### Monitor disk usage and alert if over 80%:

```bash
df -h | awk 'NR>1 {gsub(/%/,""); if($5>80) print "WARNING: "$6" is "$5"% full"}'
```

### Count lines of code in a project (excluding blank lines and comments):

```bash
find . -name "*.js" | xargs grep -c "" | awk -F: '{sum+=$2} END {print sum, "total lines"}'
```

### Extract all email addresses from a file:

```bash
grep -Eo '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' contacts.txt | sort -u
```

---

## Common Misunderstanding: "I need to write a Python script for this text processing"

**The misunderstanding:** "This log parsing task requires a script — I'll write Python."

**The reality:** For most one-off log analysis and data transformation tasks, a single pipeline of `grep | awk | sort | uniq | head` is:
- Faster to write (one line vs 20 lines of Python)
- Faster to run (these C programs process gigabytes per second)
- No file to manage or run

**When to actually use Python/scripting:**
- The logic is complex (multiple conditions, branching, nested loops)
- You need to run it repeatedly (make it a proper script)
- You need to handle errors carefully
- The output format needs to be structured (JSON, XML)

For ad-hoc analysis of log files and data — reach for the pipeline first.

---

→ Continue to: `08-networking-commands.md`
