@doc raw"""
	storage_symmetric!(EP::Model, inputs::Dict, setup::Dict)

Sets up variables and constraints specific to storage resources with symmetric charge and discharge capacities. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_symmetric!(EP::Model, inputs::Dict, setup::Dict)
	# Set up additional variables, constraints, and expressions associated with storage resources with symmetric charge & discharge capacity
	# (e.g. most electrochemical batteries that use same components for charge & discharge)
	# STOR = 1 corresponds to storage with distinct power and energy capacity decisions but symmetric charge/discharge power ratings

	println("Storage Resources with Symmetric Charge/Discharge Capacity Module")

	dfGen = inputs["dfGen"]
	Reserves = setup["Reserves"]
	CapacityReserveMargin = setup["CapacityReserveMargin"]

	T = inputs["T"]     # Number of time steps (hours)

	STOR_SYMMETRIC = inputs["STOR_SYMMETRIC"]

	### Constraints ###

	# Storage discharge and charge power (and reserve contribution) related constraints for symmetric storage resources:
	if Reserves == 1
		storage_symmetric_reserves!(EP, inputs, setup)
	else
		if CapacityReserveMargin > 0
			@constraints(EP, begin
				# Maximum charging rate (including virtual charging to move energy held in reserve back to available storage) must be less than symmetric power rating
				[y in STOR_SYMMETRIC, t in 1:T], EP[:vCHARGE][y,t] + EP[:vCAPRES_charge][y,t] <= EP[:eTotalCap][y]

				# Max simultaneous charge and discharge cannot be greater than capacity
				[y in STOR_SYMMETRIC, t in 1:T], EP[:vP][y,t]+EP[:vCHARGE][y,t]+EP[:vCAPRES_discharge][y,t]+EP[:vCAPRES_charge][y,t] <= EP[:eTotalCap][y]
			end)
		else
			@constraints(EP, begin
				# Maximum charging rate (including virtual charging to move energy held in reserve back to available storage) must be less than symmetric power rating
				[y in STOR_SYMMETRIC, t in 1:T], EP[:vCHARGE][y,t] <= EP[:eTotalCap][y]

				# Max simultaneous charge and discharge cannot be greater than capacity
				[y in STOR_SYMMETRIC, t in 1:T], EP[:vP][y,t]+EP[:vCHARGE][y,t] <= EP[:eTotalCap][y]
			end)
		end
	end

end

@doc raw"""
	storage_symmetric_reserves!(EP::Model, inputs::Dict)

Sets up variables and constraints specific to storage resources with symmetric charge and discharge capacities when reserves are modeled. See ```storage()``` in ```storage.jl``` for description of constraints.
"""
function storage_symmetric_reserves!(EP::Model, inputs::Dict, setup::Dict)

	T = 1:inputs["T"]
	CapacityReserveMargin = setup["CapacityReserveMargin"] > 0

	SYMMETRIC = inputs["STOR_SYMMETRIC"]

	REG = intersect(SYMMETRIC, inputs["REG"])
	RSV = intersect(SYMMETRIC, inputs["RSV"])

    vP = EP[:vP]
    vS = EP[:vS]
    vCHARGE = EP[:vCHARGE]
    vREG = EP[:vREG]
    vRSV = EP[:vRSV]
    vREG_charge = EP[:vREG_charge]
    vRSV_charge = EP[:vRSV_charge]
    vREG_discharge = EP[:vREG_discharge]
    vRSV_discharge = EP[:vRSV_discharge]
    vCAPRES_charge = EP[:vCAPRES_charge]
    vCAPRES_discharge = EP[:vCAPRES_discharge]
    eTotalCap = EP[:eTotalCap]

    # Maximum charging rate plus contribution to regulation down must be less than symmetric power rating
    expr = @expression(EP, [y in SYMMETRIC, t in T], 1 * vCHARGE[y, t]) # NOTE load-bearing "1 *"
    add_similar_to_expression!(expr[REG, :], vREG_charge[REG, :])
    if CapacityReserveMargin
        add_similar_to_expression!(expr[SYMMETRIC, :], vCAPRES_charge[SYMMETRIC, :])
    end
    @constraint(EP, [y in SYMMETRIC, t in T], expr[y, t] <= eTotalCap[y])

    # Max simultaneous charge and discharge rates cannot be greater than symmetric charge/discharge capacity
    expr = @expression(EP, [y in SYMMETRIC, t in T], vP[y, t] + vCHARGE[y, t])
    add_similar_to_expression!(expr[REG, :], vREG_charge[REG, :])
    add_similar_to_expression!(expr[REG, :], vREG_discharge[REG, :])
    add_similar_to_expression!(expr[RSV, :], vRSV_discharge[RSV, :])
    if CapacityReserveMargin
        add_similar_to_expression!(expr[SYMMETRIC, :], vCAPRES_charge[SYMMETRIC, :])
        add_similar_to_expression!(expr[SYMMETRIC, :], vCAPRES_discharge[SYMMETRIC, :])
    end
    @constraint(EP, [y in SYMMETRIC, t in T], expr[y, t] <= eTotalCap[y])
end
