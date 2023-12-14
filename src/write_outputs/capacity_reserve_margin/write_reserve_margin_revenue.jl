@doc raw"""
	write_reserve_margin_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the capacity revenue earned by each generator listed in the input file.
    GenX will print this file only when capacity reserve margin is modeled and the shadow price can be obtained form the solver.
    Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue from each capacity reserve margin constraint.
    The revenue is calculated as the capacity contribution of each time steps multiplied by the shadow price, and then the sum is taken over all modeled time steps.
    The last column is the total revenue received from all capacity reserve margin constraints.
    As a reminder, GenX models the capacity reserve margin (aka capacity market) at the time-dependent level, and each constraint either stands for an overall market or a locality constraint.
"""
function write_reserve_margin_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
	
	res =  inputs["RESOURCES"]
	regions = region.(res)
	clusters = cluster.(res)
	zones = zone_id.(res)


	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	THERM_ALL = inputs["THERM_ALL"]
	VRE = inputs["VRE"]
	HYDRO_RES = inputs["HYDRO_RES"]
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	MUST_RUN = inputs["MUST_RUN"]
	VRE_STOR = inputs["VRE_STOR"]
	dfVRE_STOR = inputs["dfVRE_STOR"]
	if !isempty(VRE_STOR)
		VRE_STOR_STOR = inputs["VS_STOR"]
		DC_DISCHARGE = inputs["VS_STOR_DC_DISCHARGE"]
		AC_DISCHARGE = inputs["VS_STOR_AC_DISCHARGE"]
		DC_CHARGE = inputs["VS_STOR_DC_CHARGE"]
		AC_CHARGE = inputs["VS_STOR_AC_CHARGE"]
		dfVRE_STOR = inputs["dfVRE_STOR"]
	end
	dfResRevenue = DataFrame(Region = regions, Resource = inputs["RESOURCE_NAMES"], Zone = zones, Cluster = clusters)
	annual_sum = zeros(G)
	for i in 1:inputs["NCapacityReserveMargin"]
		weighted_price = capacity_reserve_margin_price(EP, inputs, setup, i) .* inputs["omega"]
		tempresrev = zeros(G)
		tempresrev[THERM_ALL] = thermal_plant_effective_capacity(EP, inputs, THERM_ALL, i)' * weighted_price
		tempresrev[VRE] = derated_capacity.(gen.VRE, tag=i) .* (value.(EP[:eTotalCap][VRE])) .* (inputs["pP_Max"][VRE, :] * weighted_price)
		tempresrev[MUST_RUN] = derated_capacity.(gen.MUST_RUN, tag=i) .* (value.(EP[:eTotalCap][MUST_RUN])) .* (inputs["pP_Max"][MUST_RUN, :] * weighted_price)
		tempresrev[HYDRO_RES] = derated_capacity.(gen.HYDRO, tag=i) .* (value.(EP[:vP][HYDRO_RES, :]) * weighted_price)
		if !isempty(STOR_ALL)
			tempresrev[STOR_ALL] = derated_capacity.(gen.STOR, tag=i) .* ((value.(EP[:vP][STOR_ALL, :]) - value.(EP[:vCHARGE][STOR_ALL, :]).data + value.(EP[:vCAPRES_discharge][STOR_ALL, :]).data - value.(EP[:vCAPRES_charge][STOR_ALL, :]).data) * weighted_price)
		end
		if !isempty(FLEX)
			tempresrev[FLEX] = derated_capacity.(gen.FLEX, tag=i) .* ((value.(EP[:vCHARGE_FLEX][FLEX, :]).data - value.(EP[:vP][FLEX, :])) * weighted_price)
		end
		if !isempty(VRE_STOR)
			sym_vs = Symbol("CapResVreStor_$i")
			tempresrev[VRE_STOR] = dfVRE_STOR[!, sym_vs] .* ((value.(EP[:vP][VRE_STOR, :])) * weighted_price)
			tempresrev[VRE_STOR_STOR] .-= dfVRE_STOR[((dfVRE_STOR.STOR_DC_DISCHARGE.!=0) .| (dfVRE_STOR.STOR_DC_CHARGE.!=0) .| (dfVRE_STOR.STOR_AC_DISCHARGE.!=0) .|(dfVRE_STOR.STOR_AC_CHARGE.!=0)), sym_vs] .* (value.(EP[:vCHARGE_VRE_STOR][VRE_STOR_STOR, :]).data * weighted_price)
			tempresrev[DC_DISCHARGE] .+= dfVRE_STOR[(dfVRE_STOR.STOR_DC_DISCHARGE.!=0), sym_vs] .* ((value.(EP[:vCAPRES_DC_DISCHARGE][DC_DISCHARGE, :]).data .* dfVRE_STOR[(dfVRE_STOR.STOR_DC_DISCHARGE.!=0), :EtaInverter]) * weighted_price)
			tempresrev[AC_DISCHARGE] .+= dfVRE_STOR[(dfVRE_STOR.STOR_AC_DISCHARGE.!=0), sym_vs] .* ((value.(EP[:vCAPRES_AC_DISCHARGE][AC_DISCHARGE, :]).data) * weighted_price)
			tempresrev[DC_CHARGE] .-= dfVRE_STOR[(dfVRE_STOR.STOR_DC_CHARGE.!=0), sym_vs] .* ((value.(EP[:vCAPRES_DC_CHARGE][DC_CHARGE, :]).data ./ dfVRE_STOR[(dfVRE_STOR.STOR_DC_CHARGE.!=0), :EtaInverter]) * weighted_price)
			tempresrev[AC_CHARGE] .-= dfVRE_STOR[(dfVRE_STOR.STOR_AC_CHARGE.!=0), sym_vs] .* ((value.(EP[:vCAPRES_AC_CHARGE][AC_CHARGE, :]).data) * weighted_price)
		end
		tempresrev *= scale_factor
		annual_sum .+= tempresrev
		dfResRevenue = hcat(dfResRevenue, DataFrame([tempresrev], [sym]))
	end
	dfResRevenue.AnnualSum = annual_sum
	CSV.write(joinpath(path, "ReserveMarginRevenue.csv"), dfResRevenue)
	return dfResRevenue
end
