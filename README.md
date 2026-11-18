# C-- interpreter in Prolog

An interpreter for **C--**, a small C-like language, written in SWI-Prolog. It reads a C-- program, splits it into tokens, parses the tokens into a syntax tree with a DCG grammar, and runs the tree.

It started as coursework for the Programming Paradigms module at Birkbeck, University of London (2020), and was cleaned up and extended in 2026.

## The C-- language

The full specification is in [`TheC--Language.pdf`](TheC--Language.pdf) (a one-page scan). In short:

- **Values:** non-negative integer literals. Variables hold integers and are global. There are no unary operators.
- **Statements:**
  - assignment: `x = e`
  - `print e1, e2, ...`
  - `if (e) s1 else s2` (the `else` part is optional)
  - `while (e) s`
  - blocks: `{ s1 s2 ... }`
- **Operators:** `||`, `&&`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `+`, `-`, `*`, `/`, `%`, with C's meaning, precedence and associativity. Division rounds towards zero and `%` gives C's remainder.
- Comparison and logical operators **return 1 or 0**. `&&` and `||` treat any non-zero value as true.
- `if` and `while` conditions **must evaluate to 1 or 0**.
- `print` shows its values on one line, **separated by blanks**, then a newline.
- An `else` belongs to the nearest `if`, as in C.

## Example

`cmmExamples/example3.cmm` prints a table of factorials:

```
n = 8
k = 1
f = 1
while (k <= n) {
    f = f * k
    print k,f
    k = k + 1
}
```

Output:

```
1 1
2 2
3 6
4 24
5 120
6 720
7 5040
8 40320
```

## How it works

1. **Tokenize.** The [`tokenize`](https://github.com/shonfeder/tokenize) package splits the source text into tokens such as `word(k)`, `punct(=)` and `number(1)`. Spaces, tabs and line breaks are then removed.
2. **Parse.** DCG grammar rules turn the tokens into a syntax tree. Statements become terms like `assign(id(k), num(1))`, `if(Cond, Then, Else)` and `while(Cond, Body)`. Expressions become `(Operator, Left, Right)` terms. Operator precedence comes from layering the grammar, from `||` (loosest) down to numbers, variables and brackets (tightest).
3. **Run.** The evaluator walks the tree. It stores variables as `variable(Name, num(Value))` facts, calculates expressions using Prolog's own arithmetic, and prints the results.

## Running it

### Setup

1. Install [SWI-Prolog](https://www.swi-prolog.org/Download.html). Tested with version 10.0.2 on Windows.
2. Install the `tokenize` package. At the SWI-Prolog prompt:

   ```prolog
   ?- pack_install(tokenize).
   ```

   Answer **y** to the questions, except: **on Windows, answer n to `Run scripts?`**. The package is plain Prolog and needs no build step, but the build step looks for `make`, which Windows doesn't have, and the install then fails.

### Run the examples

Load `interpreter.pl`, either from a terminal:

```
swipl interpreter.pl
```

or from the SWI-Prolog console, using the full path:

```prolog
?- ['C:/path/to/interpreter'].
```

Then:

```prolog
?- run_examples.     % run every example program and print its output
?- test_examples.    % compare each example's output with its .output file
```

`test_examples` prints `PASS` or `FAIL` for each program. On a failure, it shows the expected and the actual output.

To run one program on its own:

```prolog
?- run_file('cmmExamples/example3.cmm').
```

Paths are relative to `interpreter.pl`, so this works whatever the current folder is. To add a program to the examples and tests, put the `.cmm` file (and a `.output` file with its expected output) in `cmmExamples/`, and add an `example_file(...)` line near the top of `interpreter.pl`.

## Tests

Each `.cmm` program in `cmmExamples/` has a matching `.output` file with its expected output.

| Program | What it checks |
|---|---|
| `example1` – `example5` | The example programs from the coursework |
| `division` | `/` rounds towards zero and `%` behaves like C's remainder, including for negative values |
| `logic` | `&&` and `\|\|` treat any non-zero value as true and return 1 or 0 |
| `reset` | Variables from one program don't leak into the next |
| `unassigned` | Using a variable before assigning it gives a clear error; output printed before the error is kept |
| `whilenobraces` | A `while` body can be a single statement without braces |
| `danglingelse` | An `else` belongs to the nearest `if` |
| `mixedbraces` | One branch of an `if` can use braces and the other not |
| `printexpr` | `print` accepts full expressions, not just numbers and variables |
| `badcondition` | An `if` condition other than 1 or 0 gives a clear error |

## Files

| File | Contents |
|---|---|
| `interpreter.pl` | The interpreter: example list, test runner, tokens, parser and evaluator |
| `cmmExamples/` | C-- test programs (`.cmm`) and their expected output (`.output`) |
| `TheC--Language.pdf` | The C-- language specification |

## Limitations and ideas for improvement

- **Depends on the `tokenize` package.** C-- needs only a small tokenizer (numbers, names and a handful of symbols). Writing one in `interpreter.pl` would remove the install step and the Windows build problem.
- **Two warnings on `make.`** Reloading with `make.` shows warnings about `tokenize:state/4` and `tokenize:tokens/3`. They come from inside the `tokenize` package, not from this code, and are harmless.
- **`&&` and `||` don't stop early.** Both sides are always worked out. C-- expressions can't print or change variables, so this only matters if the right-hand side causes an error. For example, `0 && 5 / 0` gives a division-by-zero error, where C would give 0.
- **Conditions must be exactly 1 or 0**, as the specification requires. Real C would treat any non-zero condition as true.
- **Syntax errors are not located.** A program that doesn't parse gives only "could not be parsed", with no line number or position.
- **Division by zero** gives SWI-Prolog's own error message rather than a C-- one.
- **The expression evaluator could be simpler.** It has some repeated rules that could be merged into a shorter, clearer version.

## Credits

- The grammar approach is based on the SWISH notebook [Compiler1](https://swish.swi-prolog.org/p/Compiler1.swinb).
- The `+`/`-` grammar rule is based on [this Stack Overflow answer](https://stackoverflow.com/questions/7543100/grammar-involving-braces).
- The C-- specification and example programs `example1` – `example5` came with the Birkbeck coursework.
