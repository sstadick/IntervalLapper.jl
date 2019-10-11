module IntervalLapper

export Interval, overlap, intersect
export Lapper

"""
Represents an interval of (start, stop] with a label val.
"""
struct Interval{T}
	start::Int
	stop::Int
	val::T
end

"""
Check if two intervals overlap.

# Example
```jldoctest
julia> overlap(Interval(0, 10, "cats"), Interaval(5, 15, "Dogs"))
true
```
"""
function overlap(a::Interval, b::Interval)
	a.start < b.stop && a.stop > b.start
end

"""
Determine the number of positions shared by two intervals

# Example
```jldoctest
julia> intersect(Interval(0, 10, "cats"), Interaval(5, 15, "Dogs"))
5
```
"""
function intersectlen(a::Interval, b::Interval)
	diff = min(a.stop, b.stop) - max(a.start, b.start)
	diff >= 0 ? diff : 0
end

"""
Primary object of the library. The intervals can be used for iterating / pulling values out of the tree
"""
struct Lapper{T}
	intervals::Vector{Interval{T}}
	max_len::Int
	cursor::Int
	cov::Union{Nothing, Int}
	overlaps_merged::Bool
end


end # module
