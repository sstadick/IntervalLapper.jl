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
	bits = IL.Bits(lapper.intervals)
	cursor = Ref(1)
	@test nothing == Base.iterate(IL.find(lapper, 30, 35))
	@test nothing == Base.iterate(IL.seek(lapper, 30, 35, cursor))
	@test IL.count(bits, 30, 35) == length(collect(IL.find(lapper, 30, 35)))
end

# Test that a query that overlaps the start of an interval returns that interval
@testset "Query Overlaps Interval Start" begin 
	lapper = setup_nonoverlapping()
	cursor = Ref(1)
	expected = Iv(20, 30, 0)
	@test expected == Base.iterate(IL.find(lapper, 15, 25))[1]
	@test expected == Base.iterate(IL.seek(lapper, 15, 25, cursor))[1]
	bits = IL.Bits(lapper.intervals)
	@test IL.count(bits, 15, 25) == length(collect(IL.find(lapper, 15, 25)))
end

# Test that a query that overlaps the stop of an interval returns that interval
@testset "Query Overlaps Interval Stop" begin 
	lapper = setup_nonoverlapping()
	cursor = Ref(1)
	expected = Iv(20, 30, 0)
	@test expected == Base.iterate(IL.find(lapper, 25, 35))[1]
	@test expected == Base.iterate(IL.seek(lapper, 25, 35, cursor))[1]
	bits = IL.Bits(lapper.intervals)
	@test IL.count(bits, 25, 35) == length(collect(IL.find(lapper, 25, 35)))
end

# Test that a query that is enveloped by interval returns interval<Paste>
@testset "Interval Envelops Query" begin 
	lapper = setup_nonoverlapping()
	cursor = Ref(1)
	expected = Iv(20, 30, 0)
	@test expected == Base.iterate(IL.find(lapper, 22, 27))[1]
	@test expected == Base.iterate(IL.seek(lapper, 22, 27, cursor))[1]
	bits = IL.Bits(lapper.intervals)
	@test IL.count(bits, 22, 27) == length(collect(IL.find(lapper, 22, 27)))
end

# Test that a query that envolops an interval returns that interval
@testset "Query Envelops Interval" begin 
	lapper = setup_nonoverlapping()
	cursor = Ref(1)
	expected = Iv(20, 30, 0)
	@test expected == Base.iterate(IL.find(lapper, 15, 35))[1]
	@test expected == Base.iterate(IL.seek(lapper, 15, 35, cursor))[1]
	bits = IL.Bits(lapper.intervals)
	@test IL.count(bits, 15, 35) == length(collect(IL.find(lapper, 15, 35)))
end

@testset "Overlapping Intervals" begin
	lapper = setup_overlapping()
	cursor = Ref(1)
	e1 = Iv(0, 15, 0)
	e2 = Iv(10, 25, 0)

	@test [e1, e2] == collect(IL.find(lapper, 8, 20))
	@test [e1, e2] == collect(IL.seek(lapper, 8, 20, cursor))
	@test 2 == length(collect(IL.find(lapper, 8, 20)))
	bits = IL.Bits(lapper.intervals)
	@test IL.count(bits, 8, 20) == length(collect(IL.find(lapper, 8, 20)))
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
	@test coverage == 60
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
	@testset "Non-merged-lappers" begin
		@testset "Lapper1 vs Lapper2" begin
			union, intersect = IL.union_and_intersect(lapper1, lapper2)
			@test intersect == 10
			@test union == 73
		end
		@testset "Lapper2 vs Lapper1" begin
			union, intersect = IL.union_and_intersect(lapper2, lapper1)
			@test intersect == 10
			@test union == 73
		end
	end

	# Should still be the same
	@testset "Merged-Lappers" begin
		IL.merge_overlaps!(lapper1)
		IL.merge_overlaps!(lapper2)
		cov1 = IL.coverage(lapper1)
		cov2 = IL.coverage(lapper2)
		@testset "Lapper1 vs Lapper2" begin
			union, intersect = IL.union_and_intersect(lapper1, lapper2, cov1, cov2)
			@test intersect == 10
			@test union == 73
		end
		@testset "Lapper2 vs Lapper1" begin
			union, intersect = IL.union_and_intersect(lapper2, lapper1, cov2, cov1)
			@test intersect == 10
			@test union == 73
		end
	end
end

@testset "Find Overlaps In Large Intervals" begin
        data1 = [
            Iv( 0,  8,  0),
            Iv( 1,  10,  0), 
            Iv( 2,  5,  0), 
            Iv( 3,  8,  0),
            Iv( 4,  7,  0),
            Iv( 5,  8,  0),
            Iv( 8,  8,  0),
            Iv( 9,  11,  0),
            Iv( 10,  13,  0),
            Iv( 100,  200,  0),
            Iv( 110,  120,  0),
            Iv( 110,  124,  0),
            Iv( 111,  160,  0),
            Iv( 150,  200,  0),
        ]
        lapper = IL.Lapper(data1);
	found = collect(IL.find(lapper, 8, 11))
        @test found == [
            Iv( 1,  10,  0), 
            Iv( 9,  11,  0),
            Iv( 10,  13,  0),
        ]
	bits = IL.Bits(lapper.intervals)
	@test IL.count(bits, 8, 11) == length(collect(IL.find(lapper, 8, 11)))

	cursor = Ref(1)
	found = collect(IL.seek(lapper, 8, 11, cursor))
        @test found == [
            Iv( 1,  10,  0), 
            Iv( 9,  11,  0),
            Iv( 10,  13,  0),
        ]
	
	found = collect(IL.find(lapper, 145, 151))
	@test found == [
            Iv( 100,  200,  0),
            Iv( 111,  160,  0),
            Iv( 150,  200,  0),
        ]
	bits = IL.Bits(lapper.intervals)
	@test IL.count(bits, 145, 151) == length(collect(IL.find(lapper, 145, 151)))

	cursor = Ref(1)
	found = collect(IL.seek(lapper, 145, 151, cursor))
	@test found == [
            Iv( 100,  200,  0),
            Iv( 111,  160,  0),
            Iv( 150,  200,  0),
        ]
end


@testset "Depth Sanity" begin
        data1 = [
            Iv( 0,  10,  0),
            Iv( 5,  10,  0)
        ]
        lapper = IL.Lapper(data1);
	found = collect(IL.depth(lapper))
        @test found == [
                   IL.Interval( 0,  5,  1),
                   IL.Interval( 5,  10,  2)
        ]
end

@testset "Depth Harder" begin
	data1 = [
            Iv( 1,  10,  0),
            Iv( 2,  5,  0),
            Iv( 3,  8,  0),
            Iv( 3,  8,  0),
            Iv( 3,  8,  0),
            Iv( 5,  8,  0),
            Iv( 9,  11,  0),
            Iv( 15,  20,  0),
        ]
        lapper = IL.Lapper(data1);
	found = collect(IL.depth(lapper))
        @test found == [
                   IL.Interval( 1,  2,  1),
                   IL.Interval( 2,  3,  2),
                   IL.Interval( 3,  8,  5),
                   IL.Interval( 8,  9,  1),
                   IL.Interval( 9,  10,  2),
                   IL.Interval( 10,  11,  1),
                   IL.Interval( 15,  20,  1),
        ]
end

@testset "Depth Hard" begin
        data1 = [
            Iv( 1,  10,  0),
            Iv( 2,  5,  0),
            Iv( 3,  8,  0),
            Iv( 3,  8,  0),
            Iv( 3,  8,  0),
            Iv( 5,  8,  0),
            Iv( 9,  11,  0),
        ]
        lapper = IL.Lapper(data1);
	found = collect(IL.depth(lapper))
        @test found == [
                   IL.Interval( 1,  2,  1),
                   IL.Interval( 2,  3,  2),
                   IL.Interval( 3,  8,  5),
                   IL.Interval( 8,  9,  1),
                   IL.Interval( 9,  10,  2),
                   IL.Interval( 10,  11,  1),
        ]
end

#=
# Bug tests - these are tests that came from real life
=#

# Test that it's not possible to induce index out of bounds by pushing the
# cursor past the end of the lapper
@testset "Seek Over Len" begin
	lapper = setup_nonoverlapping();
	single = setup_single();
	cursor = Ref(1)
	count = 0
	for interval in lapper.intervals
		for o_interval in IL.seek(single, interval.start, interval.stop, cursor)
			count += 1
		end
	end
end

# Test that if lower_bound puts us before the first match, we still return match
@testset "Find Over Behind First Match" begin
        lapper = setup_badlapper();
	e1 = Iv( 50,  55,  0)
	found = Base.iterate(IL.find(lapper, 50, 55))[1];
        @test found == e1
end

# When there is a very long interval that spans many little intervals, test that the
# little intervals still get returned properly
@testset "Bad Skips" begin
        data = [
            Iv(25264912,  25264986,  0),	
            Iv(27273024,  27273065	,  0),
            Iv(27440273,  27440318	,  0),
            Iv(27488033,  27488125	,  0),
            Iv(27938410,  27938470	,  0),
            Iv(27959118,  27959171	,  0),
            Iv(28866309,  33141404	,  0),
        ]
        lapper = IL.Lapper(data)

	found = collect(IL.find(lapper, 28974798, 33141355))
	@test found == [
            Iv(28866309,  33141404	,  0),
        ]
	bits = IL.Bits(lapper.intervals)
	@test IL.count(bits, 28974798, 33141355) == length(collect(IL.find(lapper, 28974798, 33141355)))
end




