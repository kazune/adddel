# NAME

adddel - count added and deleted lines between two files

# SYNOPSIS

**adddel** [**-l** | **--label**] [**--**] *OLD* *NEW*

**adddel** **-h** | **--help**

**adddel** **--version**

# DESCRIPTION

**adddel** compares two regular files and writes the number of added and deleted lines to standard output.
*OLD* is the original file and *NEW* is the modified file.
The files need not be in a Git repository.

Changed lines count as deletions and additions.
Whitespace and blank-line changes are included.
Line endings, final newlines, and character encodings are not normalized.
Identical files produce zero additions and zero deletions.
Empty files and comparing a file with itself are supported.

Symbolic links are followed to their target regular files.
Missing files, broken links, unreadable files, directories, and special files are rejected.
File names may contain spaces, tabs, newlines, or non-ASCII characters.

Line counts are obtained using `git diff --no-index --numstat`.
The diff algorithm is fixed to myers; indent heuristics, external diff commands, text conversion, and rename detection are disabled.
Git attributes may still affect text and binary classification.
Other Git settings and version differences are not completely isolated.

If Git reports binary counts as dashes, the comparison fails with an input error.
Identical binary files for which Git reports no differences produce zero additions and zero deletions.

# OPTIONS

Options must precede the first file argument.
Combined short options such as **-lh** or **-ll** are not accepted.

**-l**, **--label**
: Print labeled counts instead of tab-separated counts.
  This option may be repeated.

**-h**, **--help**
: Print help to standard output and exit successfully without checking input files or Git availability.
  Within the option prefix, help takes precedence over version display and invalid arguments, including unknown options.

**--version**
: Print `adddel VERSION` followed by a newline to standard output and exit successfully.
  The version is embedded at build time; input files and Git availability are not checked.
  Within the option prefix, version display takes precedence over invalid arguments, including unknown options, but help takes precedence over version display.
  There is no short option for version display.

**--**
: End option parsing.
  All subsequent arguments are file names.
  Use this to pass names beginning with a hyphen, or prefix such names with `./`.

Help and version options after the first file argument or after **--** are treated as file names.

# OUTPUT

By default, one line contains additions, a literal tab, deletions, and a final newline.
For example, with `<TAB>` representing the tab character:

```text
12<TAB>5
```

With **--label**, the same counts are printed as:

```text
additions: 12, deletions: 5
```

Diff details are not printed.
On failure, standard output is empty and an English diagnostic prefixed with `adddel: ` is written to standard error.

# EXIT STATUS

**0**
: Successful comparison, whether or not differences exist, or successful help or version display.

**1**
: Git is unavailable, Git fails, its count output is malformed, or another processing operation fails.

**2**
: Invalid arguments or input files, including binary differences whose lines cannot be counted.

# ENVIRONMENT

**TMPDIR**
: Directory used for temporary files.
  Defaults to `/tmp` if unset or empty.

# EXAMPLES

Compare two files:

```sh
adddel old.txt new.txt
```

Print labeled counts:

```sh
adddel --label old.txt new.txt
```

Compare files whose names begin with a hyphen:

```sh
adddel -- -old.txt -new.txt
```

Display help despite an unknown option:

```sh
adddel --unknown --help
```

Display the embedded version:

```sh
adddel --version
```

# REQUIREMENTS

macOS or Linux, Bash 3.2 or later, and Git 2.x for comparisons.
Help and version display do not require Git.

# SEE ALSO

bash(1), git(1), git-diff(1), gitattributes(5)
