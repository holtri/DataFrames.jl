module TestUtils
    using Base.Test, DataFrames, StatsBase
    import DataFrames: identifier

    @test identifier("%_B*_\tC*") == :_B_C_
    @test identifier("2a") == :x2a
    @test identifier("!") == :x!
    @test identifier("\t_*") == :_
    @test identifier("begin") == :_begin
    @test identifier("end") == :_end

    @test DataFrames.make_unique([:x, :x, :x_1, :x2]) == [:x, :x_2, :x_1, :x2]
    @test_throws ArgumentError DataFrames.make_unique([:x, :x, :x_1, :x2], allow_duplicates=false)
    @test DataFrames.make_unique([:x, :x_1, :x2], allow_duplicates=false) == [:x, :x_1, :x2]

    # Check that reserved words are up to date

    f = "$JULIA_HOME/../../src/julia-parser.scm"
    if isfile(f)
        r1 = r"define initial-reserved-words '\(([^)]+)"
        r2 = r"define \(parse-block s(?: \([^)]+\))?\)\s+\(parse-Nary s (?:parse-eq '\([^(]*|down '\([^)]+\) '[^']+ ')\(([^)]+)"
        body = readstring(f)
        m1, m2 = match(r1, body), match(r2, body)
        if m1 == nothing || m2 == nothing
            error("Unable to extract keywords from 'julia-parser.scm'.")
        else
            s = replace(m1.captures[1]*" "*m2.captures[1], r";;.*?\n", "")
            rw = Set(split(s, r"\W+"))
            @test rw == DataFrames.RESERVED_WORDS
        end
    else
        warn("Unable to validate reserved words against parser. ",
             "Expected if Julia was not built from source.")
    end

    @test DataFrames.countnull([1:3;]) == 0

    data = Vector{Union{Float64, Null}}(rand(20))
    @test DataFrames.countnull(data) == 0
    data[sample(1:20, 11, replace=false)] = null
    @test DataFrames.countnull(data) == 11
    data[1:end] = null
    @test DataFrames.countnull(data) == 20

    pdata = Vector{Union{Int, Null}}(sample(1:5, 20))
    @test DataFrames.countnull(pdata) == 0
    pdata[sample(1:20, 11, replace=false)] = null
    @test DataFrames.countnull(pdata) == 11
    pdata[1:end] = null
    @test DataFrames.countnull(pdata) == 20

    funs = [mean, sum, var, x -> sum(x)]
    if string(funs[end]) == "(anonymous function)" # Julia < 0.5
        @test DataFrames._fnames(funs) == ["mean", "sum", "var", "λ1"]
    else
        @test DataFrames._fnames(funs) == ["mean", "sum", "var", string(funs[end])]
    end

    @testset "describe" begin
        io = IOBuffer()
        df = DataFrame(Any[collect(1:4), Vector{Union{Int, Null}}(2:5),
                           CategoricalArray(3:6),
                           CategoricalArray{Union{Int, Null}}(4:7)],
                       [:arr, :nullarr, :cat, :nullcat])
        describe(io, df)
        DRT = CategoricalArrays.DefaultRefType
        # Julia 0.7
        nullfirst =
            """
            arr
            Summary Stats:
            Mean:           2.500000
            Minimum:        1.000000
            1st Quartile:   1.750000
            Median:         2.500000
            3rd Quartile:   3.250000
            Maximum:        4.000000
            Length:         4
            Type:           $Int

            nullarr
            Summary Stats:
            Mean:           3.500000
            Minimum:        2.000000
            1st Quartile:   2.750000
            Median:         3.500000
            3rd Quartile:   4.250000
            Maximum:        5.000000
            Length:         4
            Type:           Union{Nulls.Null, $Int}
            Number Missing: 0
            % Missing:      0.000000

            cat
            Summary Stats:
            Length:         4
            Type:           CategoricalArrays.CategoricalValue{$Int,$DRT}
            Number Unique:  4

            nullcat
            Summary Stats:
            Length:         4
            Type:           Union{Nulls.Null, CategoricalArrays.CategoricalValue{$Int,$DRT}}
            Number Unique:  4
            Number Missing: 0
            % Missing:      0.000000

            """
        # Julia 0.6
        nullsecond =
            """
            arr
            Summary Stats:
            Mean:           2.500000
            Minimum:        1.000000
            1st Quartile:   1.750000
            Median:         2.500000
            3rd Quartile:   3.250000
            Maximum:        4.000000
            Length:         4
            Type:           $Int

            nullarr
            Summary Stats:
            Mean:           3.500000
            Minimum:        2.000000
            1st Quartile:   2.750000
            Median:         3.500000
            3rd Quartile:   4.250000
            Maximum:        5.000000
            Length:         4
            Type:           Union{$Int, Nulls.Null}
            Number Missing: 0
            % Missing:      0.000000

            cat
            Summary Stats:
            Length:         4
            Type:           CategoricalArrays.CategoricalValue{$Int,$DRT}
            Number Unique:  4

            nullcat
            Summary Stats:
            Length:         4
            Type:           Union{CategoricalArrays.CategoricalValue{$Int,$DRT}, Nulls.Null}
            Number Unique:  4
            Number Missing: 0
            % Missing:      0.000000

            """
            out = String(take!(io))
            @test (out == nullfirst || out == nullsecond)
    end

    @testset "describe" begin
        io = IOBuffer()
        df = DataFrame(Any[collect(1:4), collect(Union{Int, Null}, 2:5),
                           CategoricalArray(3:6),
                           CategoricalArray{Union{Int, Null}}(4:7)],
                       [:arr, :nullarr, :cat, :nullcat])
        describe(io, df)
        @test String(take!(io)) ==
            """
            arr
            Summary Stats:
            Mean:           2.500000
            Minimum:        1.000000
            1st Quartile:   1.750000
            Median:         2.500000
            3rd Quartile:   3.250000
            Maximum:        4.000000
            Length:         4
            Type:           $Int

            nullarr
            Summary Stats:
            Mean:           3.500000
            Minimum:        2.000000
            1st Quartile:   2.750000
            Median:         3.500000
            3rd Quartile:   4.250000
            Maximum:        5.000000
            Length:         4
            Type:           Union{$Int, Nulls.Null}
            Number Missing: 0
            % Missing:      0.000000

            cat
            Summary Stats:
            Length:         4
            Type:           CategoricalArrays.CategoricalValue{$Int,$(CategoricalArrays.DefaultRefType)}
            Number Unique:  4

            nullcat
            Summary Stats:
            Length:         4
            Type:           Union{CategoricalArrays.CategoricalValue{$Int,$(CategoricalArrays.DefaultRefType)}, Nulls.Null}
            Number Unique:  4
            Number Missing: 0
            % Missing:      0.000000

            """
    end
end
