module king_knight::knight {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::string::{Self, String};
    use sui::package;
    use sui::display;

    struct KNIGHT has drop {}

    struct Knight has key {
        id: UID,
        name: String,
        ability: u64,
    }

    fun init(otw: KNIGHT, ctx: &mut TxContext) {
        let keys = vector[
            string::utf8(b"name is"),
            string::utf8(b"ability is"),
        ];

        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{ability}"),
        ];

        let publisher = package::claim(otw, ctx);

        let display = display::new_with_fields<Knight>(&publisher, keys, values, ctx);
        display::update_version(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    public fun create_knight(name: String, ability: u64, ctx: &mut TxContext) {
        let knight = Knight {
            id: object::new(ctx),
            name,
            ability,
        };
        transfer::freeze_object(knight);
    }
}