data:extend{
    {
        type = "custom-input",
        name = "cf-toggle-transform",
        key_sequence = "",
    },
    {
        type = "shortcut",
        name = "cf-toggle-transform",
        associated_control_input = "cf-toggle-transform",
        action = "lua",
        toggleable = true,
        icon = {
            filename = "__base__/graphics/icons/car.png",
            priority = "extra-high-no-scale",
            size = 64,
            scale = 1,
            flags = {"gui-icon"}
        },
    },

    {
        type = "custom-input",
        name = "cf-toggle-driving",
        linked_game_control = "toggle-driving",
        key_sequence = "",
    },
}