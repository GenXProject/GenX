@doc raw"""
	write_power(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the different values of power generated by the different technologies in operation.
"""
function write_power(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	gen = inputs["RESOURCES"]
	zones = zone_id.(gen)

	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	# Power injected by each resource in each time step
	dfPower = DataFrame(Resource = inputs["RESOURCE_NAMES"], Zone = zones, AnnualSum = Array{Union{Missing,Float64}}(undef, G))
	power = value.(EP[:vP])
	if setup["ParameterScale"] == 1
		power *= ModelScalingFactor
	end
	dfPower.AnnualSum .= power * inputs["omega"]
	dfPower = hcat(dfPower, DataFrame(power, :auto))

	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfPower,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfPower[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	total[:, 4:T+3] .= sum(power, dims = 1)

	rename!(total,auxNew_Names)
	dfPower = vcat(dfPower, total)
	CSV.write(joinpath(path, "power.csv"), dftranspose(dfPower, false), writeheader=false)
	return dfPower
end
