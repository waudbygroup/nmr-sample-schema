using Test
using JSON

const REPO_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const MIGRATION_CODE_DIR = joinpath(REPO_ROOT, "migration-code")
const FIXTURES_DIR = joinpath(REPO_ROOT, "tests", "fixtures")
const PATCH_PATH = joinpath(REPO_ROOT, "current", "patch.json")

include(joinpath(MIGRATION_CODE_DIR, "migrate.jl"))
using .SchemaMigrate

const LATEST_VERSION = "0.4.0"
const LATEST_SCHEMA_SOURCE = "https://raw.githubusercontent.com/nmr-samples/schema/main/versions/v0.4.0/schema.json"

load_fixture(name) = JSON.parsefile(joinpath(FIXTURES_DIR, name); dicttype=Dict{String,Any})
migrate!(data) = update_to_latest_schema!(data, PATCH_PATH)

function assert_current(data)
    @test data["metadata"]["schema_version"] == LATEST_VERSION
    @test data["metadata"]["schema_source"] == LATEST_SCHEMA_SOURCE
end

@testset "SchemaMigrate" begin

    @testset "Core DSL — wildcards over arrays" begin
        # set wildcard on array adds field to every element
        data = Dict{String,Any}(
            "items" => Any[
                Dict{String,Any}("name" => "a"),
                Dict{String,Any}("name" => "b"),
                Dict{String,Any}("name" => "c"),
            ],
        )
        SchemaMigrate._apply_set(data, Dict("op" => "set", "path" => "/items/*/flag", "value" => nothing))
        @test all(haskey(c, "flag") && c["flag"] === nothing for c in data["items"])

        # set wildcard on empty array is no-op
        data = Dict{String,Any}("items" => Any[])
        SchemaMigrate._apply_set(data, Dict("op" => "set", "path" => "/items/*/flag", "value" => nothing))
        @test data["items"] == Any[]

        # set wildcard on missing key is silent no-op (no intermediate created)
        data = Dict{String,Any}()
        SchemaMigrate._apply_set(data, Dict("op" => "set", "path" => "/items/*/flag", "value" => nothing))
        @test !haskey(data, "items")

        # rename_key wildcard renames on every element
        data = Dict{String,Any}(
            "items" => Any[
                Dict{String,Any}("Old" => 1),
                Dict{String,Any}("Old" => 2),
                Dict{String,Any}("Other" => 3),
            ],
        )
        SchemaMigrate._apply_rename_key(
            data, Dict("op" => "rename_key", "path" => "/items/*/Old", "to" => "new"),
        )
        @test data["items"][1] == Dict{String,Any}("new" => 1)
        @test data["items"][2] == Dict{String,Any}("new" => 2)
        @test data["items"][3] == Dict{String,Any}("Other" => 3)

        # map wildcard replaces only matching values
        data = Dict{String,Any}(
            "items" => Any[
                Dict{String,Any}("u" => "equiv"),
                Dict{String,Any}("u" => "mM"),
                Dict{String,Any}("u" => "equiv"),
            ],
        )
        SchemaMigrate._apply_map(
            data, Dict("op" => "map", "path" => "/items/*/u", "from" => "equiv", "to" => ""),
        )
        @test [c["u"] for c in data["items"]] == ["", "mM", ""]
    end

    @testset "parse_path" begin
        @test_throws Exception SchemaMigrate._parse_path("no-leading-slash")
        @test SchemaMigrate._parse_path("/a~1b/c~0d") == ["a/b", "c~d"]
    end

    @testset "v0.0.2 multi-component: every rename applied" begin
        data = load_fixture("sample_v0.0.2_multi.json")
        migrate!(data)
        assert_current(data)

        # top-level keys renamed
        for old in ("Sample", "Buffer", "NMR Tube", "Laboratory Reference", "Notes")
            @test !haskey(data, old)
        end
        @test haskey(data, "sample")
        @test haskey(data, "people")
        @test data["people"]["users"] == Any["Alice", "Bob"]

        # per-component renames
        comps = data["sample"]["components"]
        @test length(comps) == 3
        for c in comps
            @test !haskey(c, "Name")
            @test !haskey(c, "Concentration")
            @test !haskey(c, "Unit")
            @test !haskey(c, "Isotopic labelling")
            @test haskey(c, "name")
            @test haskey(c, "concentration_or_amount")
            @test haskey(c, "unit")
            @test haskey(c, "isotopic_labelling")
            @test haskey(c, "molecular_weight")
            @test haskey(c, "type")
            @test c["type"] === nothing
        end
        @test !any(c["unit"] == "equiv" for c in comps)

        # diameter mapped from "5 mm" to 5.0 and renamed to diameter_mm
        @test !haskey(data["nmr_tube"], "diameter")
        @test data["nmr_tube"]["diameter_mm"] == 5.0
    end

    @testset "v0.2.0 multi-component: wildcard map + set over arrays" begin
        data = load_fixture("sample_v0.2.0_multi.json")
        migrate!(data)
        assert_current(data)

        comps = data["sample"]["components"]
        @test length(comps) == 3
        for c in comps
            @test c["unit"] != "equiv"
            @test haskey(c, "molecular_weight")
            @test haskey(c, "type")
            @test c["type"] === nothing
        end
    end

    @testset "v0.3.0 multi-component: type added to every component" begin
        data = load_fixture("sample_v0.3.0_multi.json")
        migrate!(data)
        assert_current(data)

        comps = data["sample"]["components"]
        @test length(comps) == 3
        for c in comps
            @test haskey(c, "type")
            @test c["type"] === nothing
            @test haskey(c, "molecular_weight")
            @test haskey(c, "isotopic_labelling")
        end
    end

    @testset "Edge cases: empty and missing components" begin
        data = load_fixture("sample_v0.2.0_empty_components.json")
        migrate!(data)
        assert_current(data)
        @test data["sample"]["components"] == Any[]

        data = load_fixture("sample_v0.2.0_no_components.json")
        migrate!(data)
        assert_current(data)
        @test !haskey(data["sample"], "components")
    end

    @testset "Already current is no-op and idempotent" begin
        data = load_fixture("sample_v0.4.0_already_current.json")
        before = deepcopy(data)
        migrate!(data)
        @test data == before
        @test data["sample"]["components"][1]["isotopic_labelling"] == "19F"

        # idempotency from an older version
        data = load_fixture("sample_v0.0.2_multi.json")
        migrate!(data)
        first = deepcopy(data)
        migrate!(data)
        @test data == first
    end

    @testset "Stress: 50-element component array" begin
        data = Dict{String,Any}(
            "sample" => Dict{String,Any}(
                "components" => Any[
                    Dict{String,Any}(
                        "Name" => "c$i",
                        "Concentration" => i,
                        "Unit" => iseven(i) ? "mM" : "equiv",
                    ) for i in 1:50
                ],
            ),
            "metadata" => Dict{String,Any}("schema_version" => "0.0.2"),
        )
        migrate!(data)
        comps = data["sample"]["components"]
        @test length(comps) == 50
        for c in comps
            @test haskey(c, "name")
            @test haskey(c, "concentration_or_amount")
            @test c["unit"] != "equiv"
            @test c["type"] === nothing
            @test haskey(c, "molecular_weight")
        end
    end

    @testset "load_sample convenience function" begin
        data = load_sample(joinpath(FIXTURES_DIR, "sample_v0.3.0_multi.json"), PATCH_PATH)
        assert_current(data)
        @test length(data["sample"]["components"]) == 3
    end
end
