-- Apartment Definitions
Apartments = {
    {
        property_id = 'apartment_complex_1',
        type = 'apartment',
        label = 'South Rockford Drive Apartments',
        entry_coords = {x = -667.02, y = -854.96, z = 24.5, heading = 0.0},
        units = {
            {unit_label = 'Unit 1A', interior_id = 1},
            {unit_label = 'Unit 1B', interior_id = 1},
            {unit_label = 'Unit 1C', interior_id = 1},
            {unit_label = 'Unit 1D', interior_id = 1},
            {unit_label = 'Unit 2A', interior_id = 1},
            {unit_label = 'Unit 2B', interior_id = 1},
            {unit_label = 'Unit 2C', interior_id = 1},
            {unit_label = 'Unit 2D', interior_id = 1}
        }
    },
    {
        property_id = 'apartment_complex_2',
        type = 'apartment',
        label = 'Integrity Way Apartments',
        entry_coords = {x = -47.26, y = -585.86, z = 37.95, heading = 0.0},
        units = {
            {unit_label = 'Unit 1A', interior_id = 1},
            {unit_label = 'Unit 1B', interior_id = 1},
            {unit_label = 'Unit 1C', interior_id = 1},
            {unit_label = 'Unit 1D', interior_id = 1}
        }
    },
    {
        property_id = 'apartment_complex_3',
        type = 'apartment',
        label = 'Tinsel Towers',
        entry_coords = {x = -619.29, y = 37.72, z = 43.59, heading = 0.0},
        units = {
            {unit_label = 'Unit 1A', interior_id = 1},
            {unit_label = 'Unit 1B', interior_id = 1},
            {unit_label = 'Unit 1C', interior_id = 1},
            {unit_label = 'Unit 1D', interior_id = 1}
        }
    }
}

-- Interior spawn points (simplified, can be expanded)
Interiors = {
    [1] = {
        spawn = {x = -781.69, y = 318.12, z = 217.64, heading = 180.0},
        stash_coords = {x = -795.42, y = 331.35, z = 217.64},
        logout_coords = {x = -774.22, y = 330.69, z = 217.64}
    }
}
