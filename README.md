# IntervalLapper

This is a Julia port of my Rust
[port](https://docs.rs/rust-lapper/>) of
[nim-lapper](https://github.com/brentp/nim-lapper).

## Install

```
]
add IntervalLapper
```

## Docs

See the docs for the rust-lapper project. The API's are essentially the
same. The version 5.0.0 release is virtually identical at the time of
writing this readme. https://docs.rs/rust-lapper/

## Examples

```julia
using Test
import IntervalLapper
const IL = IntervalLapper
const Iv = IL.Interval{Int}

data = map(x -> Iv(x, x + 15, 0), 0:10:100)
lapper = IL.Lapper(data)

cursor = Ref(1)
e1 = Iv(0, 15, 0)
e2 = Iv(10, 25, 0)

@test [e1, e2] == collect(IL.find(lapper, 8, 20))
@test [e1, e2] == collect(IL.seek(lapper, 8, 20, cursor))
@test 2 == length(collect(IL.find(lapper, 8, 20)))
bits = IL.Bits(lapper.intervals)
@test IL.count(bits, 8, 20) == length(collect(IL.find(lapper, 8, 20)))
```

## Benchmarks

TBD. Anecdotally seems speedy, but no optimizations have been done. I'm
sure there some funkiness with type instability or missed broadcasting
opportunities. 
