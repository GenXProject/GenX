@doc raw"""
	write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the costs pertaining to the objective function (fixed, variable O&M etc.).
"""
function write_costs(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Cost results
	dfGen = inputs["dfGen"]
	SEG = inputs["SEG"]  # Number of lines
	Z = inputs["Z"]     # Number of zones
	T = inputs["T"]     # Number of time steps (hours)
	STOR_ALL = inputs["STOR_ALL"]
	FLEX = inputs["FLEX"]
	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"]


	dfCost = DataFrame(Costs = ["cTotal", "cInv", "cFOM", "cFuel", "cVOM", "cNSE", "cStart", "cUnmetRsv", "cNetworkExp", "cUnmetPolicyPenalty"])
	cInv = value(EP[:eTotalCInv]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCInvEnergy]) : 0.0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCInvCharge]) : 0.0)
	cFOM = value(EP[:eTotalCFOM]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFOMEnergy]) : 0.0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFOMCharge]) : 0.0)
	cFuel = value(EP[:eTotalCFuelOut])
	cVOM = value(EP[:eTotalCVOMOut]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0.0) + (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0.0)
	dfCost[!,Symbol("Total")] = [objective_value(EP), cInv, cFOM, cFuel, cVOM, value(EP[:eTotalCNSE]), 0.0, 0.0, 0.0, 0.0]

	if setup["InvestmentCredit"] == 1
		dfCost[2,2] -= value(EP[:eCTotalInvCredit])
	end

	if setup["CO2Tax"] == 1
		dfCost[5,2] += value(EP[:eTotalCCO2Tax])
	end

	# CO2 Capture Cost is counted as an VOM cost
    if setup["CO2Capture"] == 1	
        dfCost[5,2] += value(EP[:eTotaleCCO2Sequestration])
        if setup["CO2Credit"] == 1
            dfCost[5,2] -= value(EP[:eTotalCCO2Credit])
        end
    end

	# Energy Credit cost is counted as an VOM cost
	if setup["EnergyCredit"] == 1
		dfCost[5,2] -= value(EP[:eCTotalEnergyCredit])
	end

	if setup["UCommit"]>=1
		dfCost[7,2] = value(EP[:eTotalCStart])
	end

	if setup["Reserves"]==1
		dfCost[8,2] = value(EP[:eTotalCRsvPen])
	end

	if setup["NetworkExpansion"] == 1 && Z > 1
		dfCost[9,2] = value(EP[:eTotalCNetworkExp])
	end

	if setup["EnergyShareRequirement"] == 1
		dfCost[10,2] += value(EP[:eCTotalESRSlack])
	end

	if setup["CapacityReserveMargin"] == 1
		dfCost[10,2] += value(EP[:eCTotalCapResSlack])
	end

	if setup["CO2Cap"] == 1
		dfCost[10,2] += value(EP[:eCTotalCO2Emissions_mass_slack])
	end

	if setup["CO2GenRateCap"] == 1
		dfCost[10,2] += value(EP[:eCTotalCO2Emissions_genrate_slack])
	end

	if setup["CO2LoadRateCap"] == 1
		dfCost[10,2] += value(EP[:eCTotalCO2Emissions_loadrate_slack])
	end

	if setup["MinCapReq"] == 1
		dfCost[10,2] += value(EP[:eTotalCMinCap_slack])
	end

	if setup["MaxCapReq"] == 1
		dfCost[10,2] += value(EP[:eTotalCMaxCap_slack])
	end

	if setup["MaxInvReq"] == 1
		dfCost[10,2] += value(EP[:eTotalCMaxInv_slack])
	end

	if setup["TFS"] == 1
		dfCost[10,2] += value(EP[:eCTotalTFSSlack])
		NumberofTFS = inputs["NumberofTFS"]
		if NumberofTFS > 1
			dfCost[10,2] += value(EP[:eTFSTotalTranscationCost])
		end
		dfCost[10,2] += value(EP[:eCTotalCOSlack])
	end

	if setup["ParameterScale"] == 1
		dfCost.Total *= ModelScalingFactor^2
	end

	# Grab zonal cost, because nonmet reserve cost, and transmission expansion cost is system wide,
	# They are put as zero.
	tempzonalcost = zeros(10, Z)
	# Investment Cost
	tempzonalcost[2, :] += vec(value.(EP[:eZonalCInv]))
	if !isempty(STOR_ALL)
		tempzonalcost[2, :] += vec(value.(EP[:eZonalCInvEnergyCap]))
	end
	if !isempty(STOR_ASYMMETRIC)
		tempzonalcost[2, :] += vec(value.(EP[:eZonalCInvChargeCap]))
	end

	if setup["InvestmentCredit"] == 1
		tempzonalcost[2, :] -= vec(value.(EP[:eCZonalTotalInvCredit]))
	end

	# FOM Cost
	tempzonalcost[3, :] += vec(value.(EP[:eZonalCFOM]))
	if !isempty(STOR_ALL)
		tempzonalcost[3, :] += vec(value.(EP[:eZonalCFOMEnergyCap]))
	end
	if !isempty(STOR_ASYMMETRIC)
		tempzonalcost[3, :] += vec(value.(EP[:eZonalCFOMChargeCap]))
	end	

	# Fuel Cost
	tempzonalcost[4, :] += vec(value.(EP[:eZonalCFuelOut]))

	# Variable OM Cost
	tempzonalcost[5, :] += vec(value.(EP[:eZonalCVOMOut]))
	if !isempty(STOR_ALL)
		tempzonalcost[5, :] += vec(value.(EP[:eZonalCVarIn]))
	end
	if !isempty(FLEX)
		tempzonalcost[5, :] += vec(value.(EP[:eZonalCVarFlexIn]))
	end
	if setup["CO2Tax"] == 1
		tempzonalcost[5, :] += vec(value.(EP[:eZonalCCO2Tax]))
	end
	if setup["CO2Capture"] == 1
		tempzonalcost[5, :] += vec(value.(EP[:eZonalCCO2Sequestration]))
		if setup["CO2Credit"] == 1
			tempzonalcost[5, :] -= vec(value.(EP[:eZonalCCO2Credit]))
		end
	end
	if setup["EnergyCredit"] == 1
		tempzonalcost[5, :] -= vec(value.(EP[:eCEnergyCreditZonalTotal]))
	end

	# Start up cost
	if setup["UCommit"] >= 1
		tempzonalcost[6, :] += vec(value.(EP[:eZonalCStart]))
	end

	# NSE Cost
	tempzonalcost[7, :] += vec(value.(EP[:eZonalCNSE]))

	# Sum of the total
	tempzonalcost[1, :] = vec(sum(tempzonalcost[2:end, :], dims = 1))

	# build the dataframe to append on total
	dfCost = hcat(dfCost, DataFrame(tempzonalcost, [Symbol("Zone$z") for z in 1:Z]))

	CSV.write(joinpath(path, "costs.csv"), dfCost)
end
