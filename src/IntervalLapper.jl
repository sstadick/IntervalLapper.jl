module IntervalLapper

export Interval, overlap, intersect
export Lapper, find, seek, lower_bound

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

function overlap(a::Interval, start::Int, stop::Int)
	a.start < stop && a.stop > start
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


function Lapper(intervals::Vector{Interval{T}}) where T
	sort!(intervals, by = x -> (x.start))
	max_len = 0
	for interval in intervals
		iv_len = interval.stop - interval.start # add an check for intervals where this could be negative?
		if iv_len > max_len
			max_len = iv_len
		end
	end
	return Lapper(intervals, max_len, 0, nothing, false)
end

function lower_bound(start::Int, intervals::Vector{Interval{T}}) where T
	size = length(intervals) + 1
	low = 1

	@inbounds while size > 1
		half = div(size, 2)
		other_half = size - half
		probe = low + half
		other_low = low + other_half
		v = intervals[probe]
		size = half
		low = v.start < start ? other_low : low
	end

	low
end


#=
#
# Find Iterator / Seek Iterator
#
=#

@inline function checked_sub(a::Int, b::Int, or=1)
	maybe = a - b
	maybe >= 1 ? maybe : or
end

struct FindIter{T}
	inner::Lapper{T}
	start::Int
	stop::Int
end


function find(lapper::Lapper{T}, start::Int, stop::Int) where T
	FindIter(lapper, start, stop)	
end

function Base.iterate(iter::FindIter)
	(iter, Ref(lower_bound(iter.start, iter.inner.intervals)))
end

struct SeekIter{T}
	inner::Lapper{T}
	start::Int
	stop::Int
	cursor::Ref{Int}
end

function Base.iterate(iter::SeekIter)
	(iter, iter.cursor)
end

function seek(lapper::Lapper{T}, start::Int, stop::Int, cursor::Ref{Int}) where T
	if cursor[] <= 1 || (cursor[] < length(lapper.intervals) && lapper.intervals[cursor[]].start > start)
		cursor[] = lower_bound(checked_sub(start, lapper.max_len), lapper.intervals)
	end
	
	while cursor[] + 1 <= length(lapper.intervals) && lapper.intervals[cursor[] + 1].start < checked_sub(start, lapper.max_len)
		cursor[] += 1
	end
	SeekIter(lapper, start, stop, cursor)
end

function Base.iterate(iter::Union{FindIter, SeekIter}, offset::Ref{Int})
	while offset[] < length(iter.inner.intervals)
	interval = iter.inner.intervals[offset[]]
	offset[] += 1
        if overlap(interval, iter.start, iter.stop)
	    return (interval, offset)
        elseif interval.start >= iter.stop
            break
        end
    end
    nothing
end

end # module
