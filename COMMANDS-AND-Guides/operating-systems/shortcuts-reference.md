# Linux Shortcuts — Complete Reference

> **Last updated:** July 6, 2026
> **Every shortcut you'll use in the terminal: bash, vim, less/man, top, htop, tmux, and nano. One file.**

---

## 1. Bash / Terminal Keyboard Shortcuts

These work in any terminal running bash (or zsh). They come from the **readline** library.

### Cursor Movement

| Shortcut | Action |
|----------|--------|
| `Ctrl+A` | Jump to **beginning** of line |
| `Ctrl+E` | Jump to **end** of line |
| `Ctrl+F` | Move **forward** one character |
| `Ctrl+B` | Move **backward** one character |
| `Alt+F` | Move forward one **word** |
| `Alt+B` | Move backward one **word** |

```
Example:
  You typed: sudo systemctl restart nginx
  Cursor is at end.
  Ctrl+A → cursor jumps to 's' in 'sudo'
  Alt+F  → cursor jumps to after 'sudo'
  Alt+F  → cursor jumps to after 'systemctl'
```

### Editing

| Shortcut | Action |
|----------|--------|
| `Ctrl+K` | **Kill** (cut) from cursor to end of line |
| `Ctrl+U` | Kill from cursor to **beginning** of line |
| `Ctrl+W` | Kill the **word** before the cursor |
| `Alt+D` | Kill the word **after** the cursor |
| `Ctrl+Y` | **Yank** (paste) the last killed text |
| `Ctrl+D` | Delete character **under** cursor (or exit shell if line is empty) |
| `Ctrl+H` | Delete character **before** cursor (same as Backspace) |
| `Ctrl+T` | **Transpose** (swap) two characters before cursor |
| `Alt+T` | Transpose two words |
| `Alt+U` | Uppercase from cursor to end of word |
| `Alt+L` | Lowercase from cursor to end of word |

```
Practical use:
  Type a long command, realize the first word is wrong.
  Ctrl+A → go to beginning
  Ctrl+K → cuts the whole line (it's now in the "kill ring")
  Type the correct command
  
  Or: You want to reuse part of the previous command.
  Ctrl+Y → pastes what you cut
```

### History Navigation

| Shortcut | Action |
|----------|--------|
| `↑` / `Ctrl+P` | Previous command in history |
| `↓` / `Ctrl+N` | Next command in history |
| `Ctrl+R` | **Reverse search** — type to search backward through history |
| `Ctrl+S` | Forward search through history (may need `stty -ixon` to enable) |
| `Ctrl+G` | Cancel the current history search, restore original line |
| `Alt+.` | Insert the **last argument** of the previous command |
| `Ctrl+O` | Execute current history line, then advance to next history entry |

```
Ctrl+R in action:
  Press Ctrl+R
  Type "nginx"
  → (reverse-i-search)`nginx': sudo systemctl restart nginx
  Keep pressing Ctrl+R → cycle through older matches
  Press Enter → run it
  Press Esc or Ctrl+G → cancel, keep the text in your prompt

Alt+. in action:
  Last command: cd /very/long/path/to/some/directory
  New command: ls (cursor here)
  Alt+. → ls /very/long/path/to/some/directory
  Alt+. again → inserts the last arg of the command BEFORE that one
```

### Process and Screen Control

| Shortcut | Action |
|----------|--------|
| `Ctrl+C` | Send **SIGINT** to the running process (interrupt / kill it) |
| `Ctrl+Z` | Send **SIGSTOP** — suspend process to background |
| `Ctrl+D` | Send **EOF** (end of input). Exits the shell if used at the prompt. |
| `Ctrl+L` | **Clear** the screen (same as `clear`) |
| `Ctrl+S` | **Pause** terminal output (scroll lock) |
| `Ctrl+Q` | **Resume** terminal output (scroll lock off) |
| `Ctrl+\` | Send **SIGQUIT** (stronger than Ctrl+C, produces a core dump) |

```
Ctrl+Z then bg then disown:
  Running a long command and need the prompt back:
  Ctrl+Z        → suspends it (shows "[1]+ Stopped   command")
  bg            → resumes it in the background
  disown %1     → removes it from shell's job table (won't die when you close terminal)
  
  Or start it right: command &
```

### Tab Completion

| Shortcut | Action |
|----------|--------|
| `Tab` | Complete the current word (command, file, variable) |
| `Tab Tab` | Show all possible completions when there are multiple |
| `Alt+/` | Force filename completion |
| `Alt+~` | Username completion |
| `Alt+$` | Variable completion |
| `Alt+@` | Hostname completion |

---

## 2. History Expansion

These let you reuse parts of previous commands. Type them and press Enter or Tab to expand (Tab expands without running).

| Expansion | Meaning | Example |
|-----------|---------|---------|
| `!!` | Entire last command | `sudo !!` → reruns last command with sudo |
| `!$` | Last **argument** of last command | `mkdir /very/long/path && cd !$` |
| `!^` | First argument of last command | |
| `!*` | All arguments of last command | |
| `!:2` | Second word of last command | |
| `!n` | Command number `n` from history | `!42` |
| `!-n` | `n`th command back from current | `!-2` = two commands ago |
| `!string` | Most recent command starting with `string` | `!git` → last git command |
| `!?string` | Most recent command containing `string` | `!?nginx` |
| `^old^new` | Replace `old` with `new` in last command | `^typo^correct` |

```
Practical examples:

mkdir -p /opt/myapp/config/production
cd !$
→ cd /opt/myapp/config/production

ls /etc/nginx/sites-available/
cat !$:1/default
→ cat /etc/nginx/sites-available/default

git commit -m "fix bug"
→ realized typo:
^fix bug^fix login bug
→ git commit -m "fix login bug"

sudo systemctl restart nginx
# Wrong password for sudo
sudo !!
→ sudo sudo systemctl restart nginx   ← wrong, but you get the idea

# Better:
systemctl restart nginx   ← ran as regular user, failed
sudo !!
→ sudo systemctl restart nginx
```

---

## 3. less and man Page Shortcuts

`man` uses `less` to display pages. The `/` shortcut you saw comes from here.

### Navigation

| Key | Action |
|-----|--------|
| `Space` or `f` | Scroll **forward** one full page |
| `b` | Scroll **backward** one full page |
| `d` | Scroll **down** half page |
| `u` | Scroll **up** half page |
| `↓` or `j` or `e` | Scroll down one line |
| `↑` or `k` or `y` | Scroll up one line |
| `g` or `<` | Jump to **beginning** |
| `G` or `>` | Jump to **end** |
| `nG` or `ng` | Jump to line `n` (e.g., `50G` = go to line 50) |
| `%` | Jump to a percentage through the file (e.g., `50%`) |

### Search

| Key | Action |
|-----|--------|
| `/pattern` | Search **forward** for `pattern` |
| `?pattern` | Search **backward** for `pattern` |
| `n` | Jump to **next** match |
| `N` | Jump to **previous** match |
| `&pattern` | Show only lines matching `pattern` (filter view) |

```
Practical man page usage:
  man nginx
  /server_name    → search for "server_name"
  n               → next occurrence
  N               → previous occurrence
  G               → jump to bottom (see SEE ALSO, FILES sections)
  g               → jump back to top
  q               → quit
  
  Looking for a specific flag:
  man curl
  /-L             → find the -L flag explanation
```

### Multiple Files and Marks

| Key | Action |
|-----|--------|
| `:n` | Open **next** file (when less opened multiple files) |
| `:p` | Open **previous** file |
| `ma` | Set mark `a` at current position |
| `'a` | Jump back to mark `a` |
| `F` | Follow mode — keep reading as file grows (like `tail -f`) |

### Other

| Key | Action |
|-----|--------|
| `q` | **Quit** |
| `h` | Show help |
| `-i` | Toggle case-insensitive search |
| `-S` | Toggle line wrapping (long lines truncated vs. wrapped) |
| `v` | Open current file in `$EDITOR` (vim/nano) |
| `!command` | Run a shell command without quitting |

---

## 4. vim Shortcuts

vim is the default text editor in most Linux environments. It has modes.

### Modes

```
Normal mode  → default on startup. Navigation + commands.
Insert mode  → typing text. Entered with i, a, o, etc.
Visual mode  → selecting text. Entered with v, V, Ctrl+V.
Command mode → :commands. Entered with : from Normal mode.
```

### Entering and Leaving Insert Mode

| Key | Action (from Normal mode) |
|-----|---------------------------|
| `i` | Insert **before** cursor |
| `a` | Insert **after** cursor |
| `I` | Insert at **beginning** of line |
| `A` | Insert at **end** of line |
| `o` | Open new line **below** and insert |
| `O` | Open new line **above** and insert |
| `s` | Delete character under cursor and insert |
| `S` | Delete whole line and insert |
| `Esc` | Return to Normal mode (from any mode) |
| `Ctrl+C` | Return to Normal mode |

### Navigation (Normal Mode)

| Key | Action |
|-----|--------|
| `h` | Move left |
| `j` | Move down |
| `k` | Move up |
| `l` | Move right |
| `w` | Jump forward to beginning of next **word** |
| `W` | Jump forward to next WORD (whitespace-delimited) |
| `b` | Jump backward to beginning of **word** |
| `e` | Jump to **end** of current word |
| `0` | Jump to beginning of line |
| `^` | Jump to first non-whitespace character of line |
| `$` | Jump to end of line |
| `gg` | Jump to **first** line of file |
| `G` | Jump to **last** line of file |
| `:n` | Jump to line number `n` (e.g., `:42` = go to line 42) |
| `Ctrl+F` | Scroll forward one page |
| `Ctrl+B` | Scroll backward one page |
| `Ctrl+D` | Scroll down half page |
| `Ctrl+U` | Scroll up half page |
| `H` | Move cursor to top of screen |
| `M` | Move cursor to middle of screen |
| `L` | Move cursor to bottom of screen |
| `%` | Jump to matching bracket: `(`, `)`, `{`, `}`, `[`, `]` |

### Editing (Normal Mode)

| Key | Action |
|-----|--------|
| `x` | Delete character under cursor |
| `X` | Delete character before cursor |
| `dd` | Delete (cut) entire line |
| `D` | Delete from cursor to end of line |
| `dw` | Delete word |
| `d$` | Delete to end of line |
| `d0` | Delete to beginning of line |
| `dgg` | Delete from current line to beginning of file |
| `dG` | Delete from current line to end of file |
| `yy` or `Y` | Yank (copy) current line |
| `yw` | Yank word |
| `y$` | Yank to end of line |
| `p` | Paste **after** cursor (or below current line for full lines) |
| `P` | Paste **before** cursor (or above current line) |
| `u` | **Undo** last change |
| `Ctrl+R` | **Redo** undone change |
| `r` | Replace single character under cursor |
| `R` | Enter Replace mode (overwrite text) |
| `~` | Toggle case of character under cursor |
| `.` | Repeat last change (extremely useful) |
| `>>` | Indent line right |
| `<<` | Indent line left |
| `==` | Auto-indent current line |

### Cut/Copy/Paste with Count

```
5dd   → delete 5 lines
3yy   → yank (copy) 3 lines
2dw   → delete 2 words
10j   → move down 10 lines
```

### Search and Replace

| Key | Action |
|-----|--------|
| `/pattern` | Search **forward** |
| `?pattern` | Search **backward** |
| `n` | Next match |
| `N` | Previous match |
| `*` | Search for the word under cursor (forward) |
| `#` | Search for the word under cursor (backward) |
| `:%s/old/new/g` | Replace ALL occurrences in file |
| `:%s/old/new/gc` | Replace all, **confirm** each one |
| `:5,10s/old/new/g` | Replace in lines 5-10 only |
| `:'<,'>s/old/new/g` | Replace in visual selection (auto-filled after selecting with V) |

```
:%s/localhost/10.0.1.5/g      → replace all "localhost" with IP
:%s/\bfoo\b/bar/g             → whole-word replacement (\b = word boundary)
:%s/password = .*/password = "REDACTED"/g  → redact all passwords in config
```

### Visual Mode (Selecting Text)

| Key | Action |
|-----|--------|
| `v` | Start **character** selection |
| `V` | Start **line** selection |
| `Ctrl+V` | Start **block** (column) selection |
| (move with h/j/k/l, w, b, etc.) | Extend selection |
| `y` | Yank (copy) selected text |
| `d` | Delete selected text |
| `c` | Delete selected text and enter Insert mode |
| `>` | Indent selected lines |
| `<` | De-indent selected lines |
| `~` | Toggle case of selected text |

### File Operations (Command Mode)

| Command | Action |
|---------|--------|
| `:w` | **Write** (save) file |
| `:q` | **Quit** (fails if unsaved changes) |
| `:wq` or `:x` | Save and quit |
| `:q!` | Quit **without** saving (force) |
| `:w filename` | Save as new filename |
| `:e filename` | Open another file |
| `:e!` | Reload file from disk (discard changes) |
| `:split file` | Open file in horizontal split |
| `:vsplit file` | Open file in vertical split |
| `Ctrl+W Ctrl+W` | Switch between split windows |

### Multiple Lines — Quick Tricks

```
# Comment out lines 10-20:
:10,20s/^/# /

# Delete blank lines:
:g/^$/d

# Delete lines containing "debug":
:g/debug/d

# Show line numbers:
:set number
:set nonumber

# Case-insensitive search:
:set ignorecase
/pattern    ← now case-insensitive

# Turn on syntax highlighting:
:syntax on
```

---

## 5. top Shortcuts

Press these while `top` is running:

| Key | Action |
|-----|--------|
| `q` | Quit |
| `h` | Help |
| `k` | **Kill** a process (prompts for PID, then signal) |
| `r` | **Renice** — change priority of a process |
| `1` | Toggle per-CPU display (see all cores individually) |
| `M` | Sort by **memory** usage |
| `P` | Sort by **CPU** usage (default) |
| `T` | Sort by **time** (total CPU time consumed) |
| `N` | Sort by **PID** |
| `i` | Toggle showing **idle** processes |
| `u` | Filter by **username** (prompts for name) |
| `f` | Enter field management (add/remove/reorder columns) |
| `o` | Enter filter expression |
| `s` | Change **refresh interval** (prompts for seconds) |
| `z` | Toggle **color** display |
| `b` | Toggle **bold** for running processes |
| `Space` | Refresh immediately |
| `c` | Toggle full command path vs. short name |
| `V` | Toggle tree (forest) view |
| `H` | Toggle showing **threads** instead of processes |
| `W` | **Write** current config to `~/.toprc` |
| `<` / `>` | Move sort column left/right |

---

## 6. htop Shortcuts

htop is a better version of top (install with `sudo apt install htop`).

| Key | Action |
|-----|--------|
| `q` or `F10` | Quit |
| `F1` | Help |
| `F2` | Setup (configure what columns/meters to show) |
| `F3` or `/` | **Search** processes by name |
| `F4` | **Filter** — show only matching processes |
| `F5` | Toggle **tree** view |
| `F6` | Choose **sort column** |
| `F7` | **Decrease** priority (renice +) |
| `F8` | **Increase** priority (renice -) |
| `F9` | **Kill** the selected process (choose signal) |
| `Space` | **Tag** a process (for multi-process operations) |
| `U` | **Untag** all |
| `k` | Kill tagged processes |
| `u` | Filter by **user** |
| `H` | Toggle **user threads** |
| `K` | Toggle **kernel threads** |
| `t` | Toggle tree view |
| `I` | **Invert** sort order |
| `P` | Sort by CPU |
| `M` | Sort by memory |
| `T` | Sort by time |
| `l` | Show **open files** for selected process (calls lsof) |
| `s` | **Strace** the selected process |
| `a` | Set CPU **affinity** for selected process |

---

## 7. tmux Shortcuts

tmux is a terminal multiplexer — multiple windows/panes in one SSH session. The prefix key is `Ctrl+B` (press it, release, then press the action key).

### Sessions

| Shortcut | Action |
|----------|--------|
| `Ctrl+B d` | **Detach** from session (session keeps running) |
| `Ctrl+B s` | **List** all sessions (interactive switcher) |
| `Ctrl+B $` | **Rename** current session |
| `Ctrl+B (` | Switch to **previous** session |
| `Ctrl+B )` | Switch to **next** session |

```bash
# From shell (not inside tmux):
tmux                          # new session
tmux new -s mysession         # new named session
tmux attach                   # attach to last session
tmux attach -t mysession      # attach to named session
tmux ls                       # list sessions
tmux kill-session -t name     # kill a session
```

### Windows (Tabs)

| Shortcut | Action |
|----------|--------|
| `Ctrl+B c` | **Create** new window |
| `Ctrl+B ,` | **Rename** current window |
| `Ctrl+B &` | **Kill** current window |
| `Ctrl+B n` | Next window |
| `Ctrl+B p` | Previous window |
| `Ctrl+B l` | Last (previously used) window |
| `Ctrl+B w` | List windows (interactive switcher) |
| `Ctrl+B 0-9` | Switch to window by number |
| `Ctrl+B f` | **Find** window by name |

### Panes (Split Screen)

| Shortcut | Action |
|----------|--------|
| `Ctrl+B %` | Split pane **vertically** (side by side) |
| `Ctrl+B "` | Split pane **horizontally** (top/bottom) |
| `Ctrl+B ←→↑↓` | **Navigate** between panes |
| `Ctrl+B x` | **Kill** current pane |
| `Ctrl+B z` | **Zoom** current pane (fullscreen toggle) |
| `Ctrl+B q` | Show pane **numbers** (then press number to jump) |
| `Ctrl+B o` | Cycle through panes |
| `Ctrl+B Space` | Cycle through layout presets |
| `Ctrl+B {` | Move pane **left** |
| `Ctrl+B }` | Move pane **right** |
| `Ctrl+B Ctrl+↑↓←→` | **Resize** pane (hold Ctrl, press arrow) |

### Copy Mode (Scrollback)

| Shortcut | Action |
|----------|--------|
| `Ctrl+B [` | Enter **copy mode** (can scroll up through history) |
| `q` or `Esc` | Exit copy mode |
| `/` | Search forward in copy mode |
| `?` | Search backward in copy mode |
| `n` / `N` | Next / previous search match |
| `Space` | Start selection (vi mode) |
| `Enter` | Copy selection and exit |
| `Ctrl+B ]` | **Paste** copied text |

### Other

| Shortcut | Action |
|----------|--------|
| `Ctrl+B :` | Open **command prompt** (type tmux commands directly) |
| `Ctrl+B ?` | Show all key bindings |
| `Ctrl+B t` | Show a **clock** |
| `Ctrl+B ~` | Show previous messages |

---

## 8. nano Shortcuts

nano is the beginner-friendly terminal editor. Shortcuts use `Ctrl` (shown as `^`) or `Alt` (shown as `M-`).

| Shortcut | Action |
|----------|--------|
| `Ctrl+G` | **Help** |
| `Ctrl+O` | **Save** file (WriteOut) |
| `Ctrl+X` | **Exit** (prompts to save if modified) |
| `Ctrl+K` | **Cut** current line (or selected text) |
| `Ctrl+U` | **Paste** (UnCut) |
| `Ctrl+W` | **Search** for text (Where is) |
| `Ctrl+\` | Search and **replace** |
| `Ctrl+C` | Show current cursor **position** (line/column) |
| `Ctrl+_` | Go to specific **line number** |
| `Ctrl+A` | Jump to beginning of line |
| `Ctrl+E` | Jump to end of line |
| `Ctrl+Y` | Scroll **up** one page (Page Up) |
| `Ctrl+V` | Scroll **down** one page (Page Down) |
| `Alt+A` | Start **selecting** text (then use arrows to extend) |
| `Alt+6` | **Copy** selected text (or current line) |
| `Ctrl+R` | **Insert** another file at cursor position |
| `Alt+U` | **Undo** |
| `Alt+E` | **Redo** |
| `Alt+N` | Toggle **line numbers** |
| `Alt+#` | Toggle line numbers (alternate) |
| `Alt+\` | Jump to first line |
| `Alt+/` | Jump to last line |

---

## 9. grep / sed One-Liners

Not keyboard shortcuts, but typing shortcuts you'll use constantly.

```bash
# grep patterns:
grep -r "pattern" .           # recursive search in current dir
grep -i "pattern" file        # case-insensitive
grep -n "pattern" file        # show line numbers
grep -v "pattern" file        # invert — lines NOT matching
grep -l "pattern" dir/        # show only filenames that match
grep -c "pattern" file        # count matching lines
grep -A 3 "pattern" file      # show 3 lines After each match
grep -B 3 "pattern" file      # show 3 lines Before each match
grep -C 3 "pattern" file      # show 3 lines of Context (before + after)
grep -E "pat1|pat2" file      # extended regex, match either pattern
grep -w "word" file           # whole word match only

# sed shortcuts:
sed -n '10,20p' file          # print lines 10-20
sed '5d' file                 # delete line 5
sed '/pattern/d' file         # delete lines matching pattern
sed 's/old/new/g' file        # replace all (prints to stdout)
sed -i 's/old/new/g' file     # replace in-place (modifies the file!)
sed -i.bak 's/old/new/g' file # replace in-place, save backup as file.bak
```

---

## 10. Quick Reference Card

```
BASH READLINE
─────────────────────────────────────────────────────
Ctrl+A / Ctrl+E     Line start / end
Alt+F / Alt+B       Word forward / backward
Ctrl+K / Ctrl+U     Kill to end / to start
Ctrl+W              Kill word backward
Ctrl+Y              Paste killed text
Ctrl+R              Reverse history search
Alt+.               Last argument of previous command
Ctrl+L              Clear screen
Ctrl+C              Kill process
Ctrl+Z              Suspend process (fg/bg to resume)

HISTORY
─────────────────────────────────────────────────────
!!          Last command
!$          Last argument
!string     Last command starting with string
^old^new    Fix typo in last command

LESS / MAN
─────────────────────────────────────────────────────
/pattern    Search forward
?pattern    Search backward
n / N       Next / previous match
g / G       File start / end
Space / b   Page down / up
q           Quit

VIM (NORMAL MODE)
─────────────────────────────────────────────────────
i / a / o       Insert before / after / new line below
Esc             Back to Normal mode
gg / G          File start / end
0 / $           Line start / end
dd / yy / p     Cut line / copy line / paste
u / Ctrl+R      Undo / redo
/pattern        Search
:%s/old/new/g   Replace all
:wq             Save and quit
:q!             Quit without saving

TMUX (prefix = Ctrl+B)
─────────────────────────────────────────────────────
d               Detach session
c               New window
% / "           Split vertical / horizontal
←→↑↓           Navigate panes
z               Zoom pane (fullscreen toggle)
s               List sessions
[               Enter copy/scroll mode

TOP / HTOP
─────────────────────────────────────────────────────
q           Quit
k           Kill process
M / P       Sort by memory / CPU
1           Per-CPU view (top)
F3 or /     Search processes (htop)
F9          Kill selected (htop)
```
