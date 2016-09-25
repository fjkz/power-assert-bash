# Power Assert for Bash

Something like Power Assert for Bash.

## Usage

Load `power-assert.bash` with `.` or `source` command.

`power-assert.bash` provides `[[[` command. This is similar to `[` command, but it prints descriptive messages if it fails.

For example,

```
. power-assert.bash
A="HELLO WORLD"
[[[ "${A}" == "HELL WORLD" ]]]
```

when we run the above script, the following message is printed.

```
assertion error:

[[[ "${A}" == "HELL WORLD" ]]]  ->  false
     |
     "HELLO WORLD"

at function main (sample.sh:3)
```

## License

This work is released under the MIT License, see `LICENSE` for details.
