# Part 03 — Viewing & Editing Files: cat, less, head, tail, nano, vim

Reading file contents is something you do constantly in Linux — checking config files, reading logs, inspecting scripts. The right tool depends on what you need.

---

## `cat` — Print File Contents to Terminal

### When do you use this?

For small files where you want to see the entire content at once.

```bash
cat README.md
cat /etc/hostname
cat config.json
```

### View multiple files together:

```bash
cat file1.txt file2.txt file3.txt
# Outputs all three files one after another (concatenate = cat)
```

### Show line numbers:

```bash
cat -n app.js       # number all lines
cat -b app.js       # number non-empty lines only
```

### Show hidden characters (useful for debugging encoding issues):

```bash
cat -A file.txt     # shows $ at end of each line, ^I for tabs, ^M for Windows CR
```

### When NOT to use cat:

For large files, `cat` dumps everything to the terminal at once — thousands of lines scroll past faster than you can read. Use `less` instead.

---

## `less` — View Files With Scrolling Navigation

### When do you use this?

For any file larger than your terminal screen. `less` lets you scroll, search, and navigate without loading the whole file into memory.

```bash
less /var/log/syslog
less access.log
less /etc/nginx/nginx.conf
```

### Navigating inside `less`:

```
Space / f       → scroll forward one page
b               → scroll backward one page
G               → go to END of file
g               → go to START of file
/searchterm     → search forward (press Enter)
?searchterm     → search backward
n               → jump to next search match
N               → jump to previous search match
q               → quit
h               → help (shows all keyboard shortcuts)
```

### Follow a growing file in real time:

```bash
less +F /var/log/nginx/access.log
# Same as tail -f but with full navigation
# Press Ctrl+C to stop following, then you can navigate normally
# Press F again to resume following
```

---

## `head` — Show the Beginning of a File

```bash
head /var/log/syslog          # show first 10 lines (default)
head -n 20 access.log         # show first 20 lines
head -n 5 /etc/passwd         # show first 5 lines
```

### Useful for checking file format/headers:

```bash
head -n 1 large-data.csv      # see the CSV column headers
head -n 3 script.sh           # check the shebang and initial config
```

---

## `tail` — Show the End of a File

```bash
tail /var/log/syslog          # show last 10 lines (default)
tail -n 50 error.log          # show last 50 lines
tail -n 100 /var/log/auth.log
```

### The most important use: following log files in real time:

```bash
tail -f /var/log/nginx/access.log
```

`-f` (follow) keeps the terminal open and continuously prints new lines as they're added to the file. Essential for watching your application logs while testing.

**Press `Ctrl+C` to stop.**

### Follow multiple files simultaneously:

```bash
tail -f /var/log/nginx/access.log /var/log/nginx/error.log
```

### Follow from a specific point:

```bash
tail -f -n 0 app.log    # follow from NOW (don't show existing lines, only new ones)
```

---

## `wc` — Count Lines, Words, and Bytes

```bash
wc filename.txt
# Output: 142  891  7234  filename.txt
#           │    │    │
#           │    │    └── bytes (file size)
#           │    └── words
#           └── lines
```

```bash
wc -l file.txt    # count lines only
wc -w file.txt    # count words only
wc -c file.txt    # count bytes only
```

Real-world use:
```bash
# How many error lines in the log?
grep "ERROR" app.log | wc -l

# How many users are in the system?
wc -l /etc/passwd
```

---

## Output Redirection — Write Command Output to Files

These aren't commands but operators — they redirect where output goes.

### `>` — Write output to file (overwrites):

```bash
ls -la > file-list.txt      # saves ls output to file, creates if needed
echo "Hello" > greeting.txt
cat > new-file.txt          # type content, Ctrl+D to save (interactive)
```

### `>>` — Append output to file (adds to end):

```bash
echo "line 1" > myfile.txt
echo "line 2" >> myfile.txt    # adds to existing content
echo "line 3" >> myfile.txt

cat myfile.txt
# line 1
# line 2
# line 3
```

### `2>` — Redirect error output:

```bash
ls /nonexistent 2> errors.txt   # save error messages to file
ls /nonexistent 2>/dev/null     # suppress errors completely (/dev/null = trash)
command > output.txt 2>&1       # redirect both stdout AND stderr to file
```

### Real use — save log while also watching it:

```bash
./start-server.sh 2>&1 | tee server.log
# tee writes to file AND shows on terminal simultaneously
```

---

## `nano` — Beginner-Friendly Terminal Text Editor

`nano` is the easiest terminal editor. You can see the keyboard shortcuts at the bottom of the screen.

```bash
nano filename.txt         # open or create file
nano /etc/hosts           # edit a system file
sudo nano /etc/nginx/nginx.conf   # edit with root privileges
```

### Inside nano:

```
^ means Ctrl key. M- means Alt key.

^X       → Exit (it asks to save if you've made changes)
^O       → Save (Write Out) without exiting
^K       → Cut the current line
^U       → Paste (Uncut)
^W       → Search (Find)
^\       → Find and Replace
^G       → Help
Alt+U    → Undo
Alt+E    → Redo
^/       → Go to line number
```

**Workflow:**
1. `sudo nano /etc/nginx/nginx.conf`
2. Make your changes
3. Press `Ctrl+O` → press Enter to confirm filename → file saved
4. Press `Ctrl+X` to exit

---

## `vim` — The Powerful but Steep-Learning-Curve Editor

Vim is everywhere — every Linux server has it. You WILL accidentally open it someday and need to know how to get out.

### The critical concept: Vim has MODES

Vim starts in **Normal mode** — keyboard keys execute commands, NOT type text. This is where beginners panic and start pressing random keys.

```
Normal Mode → press i → Insert Mode (now you can type text)
Insert Mode → press Esc → back to Normal Mode

Normal Mode → press : → Command Mode (for save, quit, etc.)
Command Mode → press Esc → back to Normal Mode
```

### Getting in and out safely:

```bash
vim filename.txt       # opens the file
```

**Just opened vim and want out without changing anything:**
```
Press: Esc   (make sure you're in Normal mode)
Type:  :q!   (q = quit, ! = force without saving)
Press: Enter
```

**Edit and save:**
```
Press: Esc   (Normal mode)
Press: i     (enters Insert mode — you can type now)
Type your changes
Press: Esc   (back to Normal mode)
Type:  :wq   (w = write/save, q = quit)
Press: Enter
```

### Essential Normal mode commands:

```
dd        → delete (cut) current line
yy        → copy (yank) current line
p         → paste below current line
u         → undo
Ctrl+R    → redo
/text     → search for "text"
n         → next search match
:set number  → show line numbers
:42       → go to line 42
gg        → go to top of file
G         → go to bottom of file
```

### When you'd actually use vim over nano:

- When SSH-ing into a server that doesn't have nano installed
- Editing large files (vim is much faster than nano on large files)
- When you need multiple cursors, macros, or powerful editing (for experienced users)
- When a tutorial or colleague tells you to

For beginners: use nano for editing config files. Learn vim gradually if you want.

---

## Real-World Scenario: Debugging a Failing Web Server

```bash
# 1. Check the last 50 lines of the error log
tail -n 50 /var/log/nginx/error.log

# 2. Watch the error log in real time while reloading the page
tail -f /var/log/nginx/error.log

# 3. Search for a specific error in the full log
grep "permission denied" /var/log/nginx/error.log | tail -20

# 4. Check the config file for mistakes
cat /etc/nginx/nginx.conf

# 5. Edit the config to fix the issue
sudo nano /etc/nginx/nginx.conf

# 6. Save and restart nginx
sudo systemctl restart nginx

# 7. Watch the log to confirm it's working
tail -f /var/log/nginx/access.log
```

---

## Common Misunderstanding: "cat is the best way to read files"

**The misunderstanding:** "I use `cat` to read every file."

**The reality:** `cat` is perfect for small files (config files, short scripts). For large files:
- `cat /var/log/syslog` — dumps potentially millions of lines scrolling past in milliseconds. You can't read it.
- `less /var/log/syslog` — shows page by page, you can scroll, search, navigate.
- `tail -n 100 /var/log/syslog` — shows the last 100 lines (usually what you actually want)
- `grep "ERROR" /var/log/syslog` — shows only the relevant lines

A practical rule: if the file is less than 30 lines, use `cat`. If it's longer, use `less` or `tail -n 50`.

---

→ Continue to: `04-permissions-and-ownership.md`
