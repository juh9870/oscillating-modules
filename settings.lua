data:extend({
    {
        type = "string-setting",
        name = "oscillating-modules-preset",
        setting_type = "startup",
        default_value = "sine",
        allowed_values = {
            "sine",
            "toggle",
            "decay",
            "custom",
        }
    },
    {
        type = "int-setting",
        name = "oscillating-modules-steps-amount",
        setting_type = "startup",
        default_value = 60,
        minimum_value = 2,
    },
    {
        type = "string-setting",
        name = "oscillating-spoil-ticks-formula",
        setting_type = "startup",
        default_value = "60"
    },
    {
        type = "string-setting",
        name = "oscillating-spoil-effect-strength-formula",
        setting_type = "startup",
        default_value = "sin(pi * x / 50) + 1"
    },
})