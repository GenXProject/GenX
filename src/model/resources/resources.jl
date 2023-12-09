abstract type AbstractResource end

const resources_type = (:ELECTROLYZER, :FLEX, :HYDRO, :STOR, :THERM, :VRE)
for r in resources_type
    let nt = Symbol("nt"), r = r
        @eval begin
            struct $r{names,T} <: AbstractResource
                $nt::NamedTuple{names,T}
            end
            Base.parent(e::$r) = getfield(e, $(QuoteNode(nt)))
        end
    end
end

function Base.getproperty(r::AbstractResource, sym::Symbol)
    haskey(parent(r), sym) && return getproperty(parent(r), sym)
    throw(ErrorException("type $(nameof(typeof(r))) has no field $(string(sym))"))
end
# Base.getproperty(x::MyStruct,y::Symbol) = Base.getproperty(getfield(x,:nt),y)
Base.setproperty!(r::AbstractResource, sym::Symbol, value) = throw(ErrorException("setfield!: immutable struct of type $(nameof(typeof(r))) cannot be changed"))

function Base.haskey(r::AbstractResource, sym::Symbol)
    return haskey(parent(r), sym)
end

function Base.get(r::AbstractResource, sym::Symbol, default) 
    return haskey(r, sym) ? getproperty(r,sym) : default
end

function Base.getproperty(rs::Vector{AbstractResource}, sym::Symbol)
    # if sym is Type then return all resources of that type
    sym ∈ resources_type && return rs[isa.(rs, GenX.eval(sym))]
    # if sym is a field of the resource then return that field for all resources
    return [getproperty(r, sym) for r in rs]
end

Base.pairs(r::AbstractResource) = pairs(parent(r))

function Base.show(io::IO, r::AbstractResource) 
    for (k,v) in pairs(r)
        println(io, "$k: $v")
    end
end

# For backward compatibility
const GenXResource = Dict{Symbol, Any}

# interface with generators_data.csv
# acts as a global variable
resource_attribute_not_set() = 0

# interface for all resources
resource_name(r::GenXResource) = r[:Resource]
resource_name(r::AbstractResource)::String = r.resource

zone_id(r::GenXResource) = r[:Zone]
zone_id(r::AbstractResource) = r.zone

start_cost_per_mw(r::AbstractResource)::Float64 = r.start_cost_per_mw

cap_size(r::AbstractResource)::Float64 = r.cap_size

function is_buildable(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :new_build, resource_attribute_not_set()) == 1, rs)
end

function is_retirable(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :can_retire, resource_attribute_not_set()) == 1, rs)
end

# TODO: default values for resource attributes
function has_max_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :max_cap_mw, resource_attribute_not_set()) != 0, rs)
end


function has_existing_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :existing_cap_mw, resource_attribute_not_set()) != 0, rs)
end

function has_fuel(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :fuel, resource_attribute_not_set()) != "None", rs)
end

# STOR interface
storage(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,STOR), rs)

function symmetric_storage(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> isa(r,STOR) && r.type == 1, rs)
end

function asymmetric_storage(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> isa(r,STOR) && r.type == 2, rs)
end

function is_LDS(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :LDS, resource_attribute_not_set()) > 0, rs)
end

function is_SDS(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :LDS, resource_attribute_not_set()) == 0, rs)
end

function has_max_capacity_mwh(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :max_cap_mwh, resource_attribute_not_set()) != 0, rs)
end

function has_existing_capacity_mwh(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :existing_cap_mwh, resource_attribute_not_set()) >= 0, rs)
end

function has_max_charge_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :max_charge_cap_mw, resource_attribute_not_set()) != 0, rs)
end

function has_existing_charge_capacity_mw(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :existing_charge_cap_mw, resource_attribute_not_set()) >= 0, rs)
end

# HYDRO interface
hydro(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,HYDRO), rs)
function has_hydro_energy_to_power_ratio(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :hydro_energy_to_power_ratio, resource_attribute_not_set()) > 0, rs)
end

# Retrofit
function has_retrofit(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :retro, resource_attribute_not_set()) > 0, rs)
end

## THERM interface
thermal(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,THERM), rs)
# Unit commitment
function has_unit_commitment(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> isa(r,THERM) && r.type == 1, rs)
end
# Without unit commitment
function no_unit_commitment(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> isa(r,THERM) && r.type == 2, rs)
end

# Reserves
function has_regulation_reserve_requirements(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :reg_max, resource_attribute_not_set()) > 0, rs)
end

function has_spinning_reserve_requirements(rs::Vector{T}) where T <: AbstractResource
    return findall(r -> get(r, :rsv_max, resource_attribute_not_set()) > 0, rs)
end

# VRE interface
vre(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,VRE), rs)

# Electrolyzer interface
electrolyzer(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,ELECTROLYZER), rs)

# Flex interface
flex_demand(rs::Vector{T}) where T <: AbstractResource = findall(r -> isa(r,FLEX), rs)



@doc raw"""
	check_resource_type_flags(r::GenXResource)

Make sure that a resource is not more than one of a set of mutually-exclusive models
"""
function check_resource_type_flags(r::GenXResource)
    exclusive_flags = [:THERM, :MUST_RUN, :STOR, :FLEX, :HYDRO, :VRE, :VRE_STOR, :ELECTROLYZER]
    not_set = resource_attribute_not_set()
    check_for_flag_set(el) = get(r, el, not_set) > 0

    statuses = check_for_flag_set.(exclusive_flags)
    number_set = count(statuses)

    error_strings = String[]
    if number_set == 0
        e = string("Resource ", resource_name(r), " has none of ", exclusive_flags, " set.\n",
                   "Exactly one of these should be non-$not_set.")
        push!(error_strings, e)
    elseif number_set > 1
        set_flags = exclusive_flags[statuses]
        e = string("Resource ", resource_name(r), " has both ", set_flags, " ≠ $not_set.\n",
                   "Exactly one of these should be non-$not_set.")
        push!(error_strings, e)
    end
    return error_strings
end

@doc raw"""
	check_mustrun_reserve_contribution(r::GenXResource)

Make sure that a MUST_RUN resource has Reg_Max and Rsv_Max set to 0 (since they cannot contribute to reserves).
"""
function check_mustrun_reserve_contribution(r::GenXResource)
    not_set = resource_attribute_not_set()
    value = get(r, :MUST_RUN, not_set)

    error_strings = String[]

    if value == not_set
        # not MUST_RUN so the rest is not applicable
        return error_strings
    end

    reg_max = get(r, :Reg_Max, not_set)
    if reg_max != 0
        e = string("Resource ", resource_name(r), " has :MUST_RUN = ", value, " but :Reg_Max = ", reg_max, ".\n",
                    "MUST_RUN units must have Reg_Max = 0 since they cannot contribute to reserves.")
        push!(error_strings, e)
    end
    rsv_max = get(r, :Rsv_Max, not_set)
    if rsv_max != 0
        e = string("Resource ", resource_name(r), " has :MUST_RUN = ", value, " but :Rsv_Max = ", rsv_max, ".\n",
                   "MUST_RUN units must have Rsv_Max = 0 since they cannot contribute to reserves.")
        push!(error_strings, e)
    end
    return error_strings
end

@doc raw"""
	check_longdurationstorage_applicability(r::GenXResource)

Check whether the LDS flag is set appropriately
"""
function check_longdurationstorage_applicability(r::GenXResource)
    applicable_resources = [:STOR, :HYDRO]

    not_set = resource_attribute_not_set()
    lds_value = get(r, :LDS, not_set)

    error_strings = String[]

    if lds_value == not_set
        # not LDS so the rest is not applicable
        return error_strings
    end

    check_for_flag_set(el) = get(r, el, not_set) > 0
    statuses = check_for_flag_set.(applicable_resources)

    if count(statuses) == 0
        e = string("Resource ", resource_name(r), " has :LDS = ", lds_value, ".\n",
                   "This setting is valid only for resources where the type is one of $applicable_resources.")
        push!(error_strings, e)
    end
    return error_strings
end

function check_LDS_applicability(r::AbstractResource)
    applicable_resources = Union{STOR, HYDRO}
    not_set = resource_attribute_not_set()
    error_strings = String[]
    lds_value = get(r, :LDS, not_set)
    # LDS is available onlåy for Hydro and Storage
    if !isa(r, applicable_resources) && lds_value > 0
        e = string("Resource ", resource_name(r), " has :LDS = ", lds_value, ".\n",
                   "This setting is valid only for resources where the type is one of $applicable_resources.")
        push!(error_strings, e)
    end
    return error_strings
end

@doc raw"""
	check_maintenance_applicability(r::GenXResource)

Check whether the MAINT flag is set appropriately
"""
function check_maintenance_applicability(r::GenXResource)
    applicable_resources = [:THERM]

    not_set = resource_attribute_not_set()
    value = get(r, :MAINT, not_set)

    error_strings = String[]

    if value == not_set
        # not MAINT so the rest is not applicable
        return error_strings
    end

    check_for_flag_set(el) = get(r, el, not_set) > 0
    statuses = check_for_flag_set.(applicable_resources)

    if count(statuses) == 0
        e = string("Resource ", resource_name(r), " has :MAINT = ", value, ".\n",
                   "This setting is valid only for resources where the type is \n",
                   "one of $applicable_resources. \n",
                  )
        push!(error_strings, e)
    end
    if get(r, :THERM, not_set) == 2
        e = string("Resource ", resource_name(r), " has :MAINT = ", value, ".\n",
                   "This is valid only for resources with unit commitment (:THERM = 1);\n",
                   "this has :THERM = 2.")
        push!(error_strings, e)
    end
    return error_strings
end

function check_maintenance_applicability(r::AbstractResource)
    applicable_resources = THERM

    not_set = resource_attribute_not_set()
    maint_value = get(r, :MAINT, not_set)
    
    error_strings = String[]
    
    if maint_value == not_set
        # not MAINT so the rest is not applicable
        return error_strings
    end

    # MAINT is available only for Thermal
    if !isa(r, applicable_resources) && maint_value > 0
        e = string("Resource ", resource_name(r), " has :MAINT = ", maint_value, ".\n",
                   "This setting is valid only for resources where the type is one of $applicable_resources.")
        push!(error_strings, e)
    end
    if get(r, :THERM, not_set) == 2
        e = string("Resource ", resource_name(r), " has :MAINT = ", maint_value, ".\n",
                   "This is valid only for resources with unit commitment (:THERM = 1);\n",
                   "this has :THERM = 2.")
        push!(error_strings, e)
    end
    return error_strings
end

@doc raw"""
    check_resource(r::GenXResource)::Vector{String}

Top-level function for validating the self-consistency of a GenX resource.
Reports any errors in a list of strings.
"""
function check_resource(r::GenXResource)::Vector{String}
    e = String[]
    e = [e; check_resource_type_flags(r)]
    e = [e; check_longdurationstorage_applicability(r)]
    e = [e; check_maintenance_applicability(r)]
    e = [e; check_mustrun_reserve_contribution(r)]
    return e
end

function check_resource(r::AbstractResource)::Vector{String}
    e = String[]
    e = [e; check_LDS_applicability(r)]
    e = [e; check_maintenance_applicability(r)]
    return e
end

@doc raw"""
    check_resource(resources::Vector{GenXResource})::Vector{String}

Validate the consistency of a vector of GenX resources
Reports any errors in a list of strings.
"""
function check_resource(resources::T)::Vector{String} where T <: Union{Vector{GenXResource}, Vector{AbstractResource}}
    e = String[]
    for r in resources
        e = [e; check_resource(r)]
    end
    return e
end

function announce_errors_and_halt(e::Vector{String})    
    error_count = length(e)
    for error_message in e
        @error(error_message)
    end
    s = string(error_count, " problems were detected with the input data. Halting.")
    error(s)
end

function validate_resources(resources::T) where T <: Union{Vector{GenXResource}, Vector{AbstractResource}}
    e = check_resource(resources)
    if length(e) > 0
        announce_errors_and_halt(e)
    end
end

function dataframerow_to_dict(dfr::DataFrameRow)
    return Dict(pairs(dfr))
end

function dataframerow_to_tuple(dfr::DataFrameRow)
    return NamedTuple(pairs(dfr))
end


## Utility functions for working with resources

function in_zone(resource::GenXResource, zone::Int)::Bool
    zone_id(resource) == zone
end
in_zone(r::AbstractResource, zone::Int)::Bool = r.zone == zone

@doc raw"""
    resources_in_zone(resources::Vector{GenXResource}, zone::Int)::Vector{GenXResources)
Find resources in a zone.
"""
function resources_in_zone(resources::Vector{GenXResource}, zone::Int)::Vector{GenXResource}
    return filter(r -> in_zone(r, zone), resources)
end
resources_in_zone(rs::Vector{AbstractResource}, zone::Int)::Vector{AbstractResource} = filter(r -> in_zone(r, zone), rs)

@doc raw"""
    resources_in_zone_by_name(inputs::Dict, zone::Int)::Vector{String}
Find names of resources in a zone.
"""
function resources_in_zone_by_name(inputs::Dict, zone::Int)::Vector{String}
    resources_d = inputs["resources_d"]
    return resource_name.(resources_in_zone(resources_d, zone))
end

@doc raw"""
    resources_in_zone_by_rid(df::DataFrame, zone::Int)::Vector{Int}
Find R_ID's of resources in a zone.
"""
function resources_in_zone_by_rid(df::DataFrame, zone::Int)::Vector{Int}
    return df[df.Zone .== zone, :R_ID]
end

@doc raw"""
    resources_in_zone_by_rid(inputs::Dict, zone::Int)::Vector{Int}
Find R_ID's of resources in a zone.
"""
function resources_in_zone_by_rid(inputs::Dict, zone::Int)::Vector{Int}
    df = inputs["dfGen"]
    return resources_in_zone_by_rid(df, zone)
end