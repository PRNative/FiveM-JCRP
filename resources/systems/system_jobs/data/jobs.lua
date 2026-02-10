-- Job Definitions
Jobs = {
    unemployed = {
        label = "Unemployed",
        default_duty = false,
        grades = {
            [0] = {
                label = "Unemployed",
                salary = 50,
                permissions = {}
            }
        }
    },
    
    police = {
        label = "Los Santos Police Department",
        default_duty = false,
        grades = {
            [0] = {
                label = "Cadet",
                salary = 1500,
                permissions = {"arrest", "search"}
            },
            [1] = {
                label = "Officer",
                salary = 2000,
                permissions = {"arrest", "search", "impound"}
            },
            [2] = {
                label = "Senior Officer",
                salary = 2500,
                permissions = {"arrest", "search", "impound", "fine"}
            },
            [3] = {
                label = "Sergeant",
                salary = 3000,
                permissions = {"arrest", "search", "impound", "fine", "hire"}
            },
            [4] = {
                label = "Lieutenant",
                salary = 3500,
                permissions = {"arrest", "search", "impound", "fine", "hire", "fire"}
            },
            [5] = {
                label = "Captain",
                salary = 4000,
                permissions = {"arrest", "search", "impound", "fine", "hire", "fire", "promote"}
            },
            [6] = {
                label = "Chief",
                salary = 5000,
                permissions = {"arrest", "search", "impound", "fine", "hire", "fire", "promote", "manage"}
            }
        }
    },
    
    ambulance = {
        label = "Emergency Medical Services",
        default_duty = false,
        grades = {
            [0] = {
                label = "Trainee",
                salary = 1200,
                permissions = {"heal"}
            },
            [1] = {
                label = "Paramedic",
                salary = 1800,
                permissions = {"heal", "revive"}
            },
            [2] = {
                label = "Doctor",
                salary = 2500,
                permissions = {"heal", "revive", "surgery"}
            },
            [3] = {
                label = "Surgeon",
                salary = 3200,
                permissions = {"heal", "revive", "surgery", "hire"}
            },
            [4] = {
                label = "Chief Medical Officer",
                salary = 4000,
                permissions = {"heal", "revive", "surgery", "hire", "fire", "promote", "manage"}
            }
        }
    },
    
    mechanic = {
        label = "Mechanic",
        default_duty = false,
        grades = {
            [0] = {
                label = "Apprentice",
                salary = 800,
                permissions = {"repair"}
            },
            [1] = {
                label = "Mechanic",
                salary = 1200,
                permissions = {"repair", "upgrade"}
            },
            [2] = {
                label = "Master Mechanic",
                salary = 1800,
                permissions = {"repair", "upgrade", "customize"}
            },
            [3] = {
                label = "Shop Owner",
                salary = 2500,
                permissions = {"repair", "upgrade", "customize", "hire", "fire", "manage"}
            }
        }
    },
    
    realestate = {
        label = "Real Estate",
        default_duty = false,
        grades = {
            [0] = {
                label = "Agent",
                salary = 1000,
                permissions = {"sell_property"}
            },
            [1] = {
                label = "Senior Agent",
                salary = 1500,
                permissions = {"sell_property", "rent_property"}
            },
            [2] = {
                label = "Broker",
                salary = 2000,
                permissions = {"sell_property", "rent_property", "hire", "fire", "manage"}
            }
        }
    },
    
    taxi = {
        label = "Taxi Driver",
        default_duty = true,
        grades = {
            [0] = {
                label = "Driver",
                salary = 600,
                permissions = {}
            },
            [1] = {
                label = "Senior Driver",
                salary = 900,
                permissions = {}
            }
        }
    },
    
    bus = {
        label = "Bus Driver",
        default_duty = true,
        grades = {
            [0] = {
                label = "Driver",
                salary = 700,
                permissions = {}
            }
        }
    },
    
    trucker = {
        label = "Trucker",
        default_duty = true,
        grades = {
            [0] = {
                label = "Driver",
                salary = 800,
                permissions = {}
            },
            [1] = {
                label = "Experienced Driver",
                salary = 1200,
                permissions = {}
            }
        }
    }
}

-- Get job definition
function GetJobDefinition(jobName)
    return Jobs[jobName]
end

-- Get grade info
function GetGradeInfo(jobName, grade)
    local job = Jobs[jobName]
    if job and job.grades and job.grades[grade] then
        return job.grades[grade]
    end
    return nil
end

-- Check if job has permission
function JobHasPermission(jobName, grade, permission)
    local gradeInfo = GetGradeInfo(jobName, grade)
    if not gradeInfo or not gradeInfo.permissions then
        return false
    end
    
    for _, perm in ipairs(gradeInfo.permissions) do
        if perm == permission then
            return true
        end
    end
    
    return false
end
