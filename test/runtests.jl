using Test
import IntervalLapper
const IL = IntervalLapper
const Iv = IL.Interval{Int}


function setup_nonoverlapping()
	data = map(x -> Iv(x, x + 10, 0), 0:20:100)
	IL.Lapper(data)
end

function setup_overlapping()
	data = map(x -> Iv(x, x + 15, 0), 0:10:100)
	IL.Lapper(data)
end

function setup_badlapper()
	data = [
	    Iv(70, 120, 0), # max_len = 50
            Iv(10, 15, 0),
            Iv(10, 15, 0), # exact overlap
            Iv(12, 15, 0), # inner overlap
            Iv(14, 16, 0), # overlap end
            Iv(40, 45, 0),
            Iv(50, 55, 0),
            Iv(60, 65, 0),
            Iv(68, 71, 0), # overlap start
            Iv(70, 75, 0),
	]
	IL.Lapper(data)
end

function setup_single()
	data = [Iv(10, 35, 0)]
	IL.Lapper(data)
end

@testset "Query Stop Interval Start" begin
	lapper = setup_nonoverlapping()
	cursor = Ref(1)
	@test nothing == Base.iterate(IL.find(lapper, 30, 35))
	@test nothing == Base.iterate(IL.seek(lapper, 30, 35, cursor))
	# @test nothing == length(collect(IL.find(lapper, 30, 35)))
end

# Test that a query that overlaps the start of an interval returns that interval
@testset "Query Overlaps Interval Start" begin 
	lapper = setup_nonoverlapping()
	cursor = Ref(1)
	expected = Iv(20, 30, 0)
	@test expected == Base.iterate(IL.find(lapper, 15, 25))[1]
	@test expected == Base.iterate(IL.seek(lapper, 15, 25, cursor))[1]
end

# Test that a query that overlaps the stop of an interval returns that interval
@testset "Query Overlaps Interval Stop" begin 
	lapper = setup_nonoverlapping()
	cursor = Ref(1)
	expected = Iv(20, 30, 0)
	@test expected == Base.iterate(IL.find(lapper, 25, 35))[1]
	@test expected == Base.iterate(IL.seek(lapper, 25, 35, cursor))[1]
end

# Test that a query that is enveloped by interval returns interval<Paste>
@testset "Interval Envelops Query" begin 
	lapper = setup_nonoverlapping()
	cursor = Ref(1)
	expected = Iv(20, 30, 0)
	@test expected == Base.iterate(IL.find(lapper, 22, 27))[1]
	@test expected == Base.iterate(IL.seek(lapper, 22, 27, cursor))[1]
end

# Test that a query that envolops an interval returns that interval
@testset "Query Envelops Interval" begin 
	lapper = setup_nonoverlapping()
	cursor = Ref(1)
	expected = Iv(20, 30, 0)
	@test expected == Base.iterate(IL.find(lapper, 15, 35))[1]
	@test expected == Base.iterate(IL.seek(lapper, 15, 35, cursor))[1]
end

@testset "Overlapping Intervals" begin
	lapper = setup_overlapping()
	cursor = Ref(1)
	e1 = Iv(0, 15, 0)
	e2 = Iv(10, 25, 0)

	@test [e1, e2] == collect(IL.find(lapper, 8, 20))
	@test [e1, e2] == collect(IL.seek(lapper, 8, 20, cursor))
	@test 2 == length(collect(IL.find(lapper, 8, 20)))
end

@testset "Merge Overlaps" begin
	lapper = setup_badlapper()
	expected = [
	    Iv( 10,  16,  0),
            Iv( 40,  45,  0),
            Iv( 50,  55,  0),
            Iv( 60,  65,  0),
            Iv( 68,  120,  0), # max_len = 50
	]
	IL.merge_overlaps!(lapper)
	@test expected == lapper.intervals
end

@testset "Lapper Coverage" begin
	lapper = setup_badlapper()
	before = IL.coverage(lapper)
	IL.merge_overlaps!(lapper)
	after = IL.coverage(lapper)
	@test before == after

	lapper = setup_nonoverlapping()
	coverage = IL.coverage(lapper)
	@test coverage == 50
end

@testset "Interval Intersections" begin
	i1 = Iv(70, 120, 0)
	i2 = Iv(10, 15, 0)
	i3 = Iv( 10,  15,  0) # exact overlap
        i4 = Iv( 12,  15,  0) # inner overlap
        i5 = Iv( 14,  16,  0) # overlap end
        i6 = Iv( 40,  50,  0)
        i7 = Iv( 50,  55,  0)
        i8 = Iv( 60,  65,  0)
        i9 = Iv( 68,  71,  0) # overlap start
        i10 = Iv( 70,  75,  0)

	@test IL.intersectlen(i2, i3) == 5 # exact match 
	@test IL.intersectlen(i2, i4) == 3 # inner intersect
	@test IL.intersectlen(i2, i5) == 1 #  end intersect
	@test IL.intersectlen(i9, i10) == 1 # start intersect
	@test IL.intersectlen(i7, i8) == 0 # no intersect
	@test IL.intersectlen(i6, i7) == 0 # no intersect stop = start
	@test IL.intersectlen(i1, i10) == 5 # inner intersect at start
end


@testset "Union and Itersect" begin
	data1 = [
	     Iv( 70,  120,  0), # max_len = 50
            Iv( 10,  15,  0), # exact overlap
            Iv( 12,  15,  0), # inner overlap
            Iv( 14,  16,  0), # overlap end
            Iv( 68,  71,  0), # overlap start
	]
	data2 = [
		Iv( 10,  15,  0),
		Iv( 40,  45,  0),
		Iv( 50,  55,  0),
		Iv( 60,  65,  0),
		Iv( 70,  75,  0),
	]

	lapper1 = IL.Lapper(data1)
	lapper2 = IL.Lapper(data2)

	# Should be the same either way it's calculated
	union, intersect = IL.union_and_intersect(lapper1, lapper2)
	@test intersect == 10
	@test union == 73
	union, intersect = IL.union_and_intersect(lapper2, lapper1)
	@test intersect == 10
	@test union == 73
	IL.merge_overlaps!(lapper1)
	IL.merge_overlaps!(lapper2)
	cov1 = IL.coverage(lapper1)
	cov2 = IL.coverage(lapper2)

	# Should still be the same
	union, intersect = IL.union_and_intersect(lapper1, lapper2, cov1, cov2)
	@test intersect == 10
	@test union == 73
	union, intersect = IL.union_and_intersect(lapper2, lapper1, cov2, cov1)
	@test intersect == 10
	@test union == 73
end

