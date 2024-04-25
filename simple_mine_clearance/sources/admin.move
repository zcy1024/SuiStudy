module simple_mine_clearance::admin {
    use sui::sui::SUI;
    use sui::coin;
    use sui::balance::{Self, Balance};
    use sui::package::{Self, Publisher};

    // ====== error code ======

    const ENotEarnBalance: u64 = 0;

    // ====== publisher struct ======

    public struct ADMIN has drop {}

    public struct GameCap has key {
        id: UID,
        balance: Balance<SUI>,
        publisher_address: address,
    }

    // ====== publisher function ======

    fun init(otw: ADMIN, ctx: &mut TxContext) {
        // create and transfer Publisher
        package::claim_and_keep(otw, ctx);

        // create and transfer GameCap
        let game_cap = GameCap {
            id: object::new(ctx),
            balance: balance::zero(),
            publisher_address: ctx.sender(),
        };
        transfer::share_object(game_cap);
    }

    public(package) fun withdraw_(game_cap: &mut GameCap, ctx: &mut TxContext) {
        // check the balance value
        assert!(game_cap.balance.value() > 0, ENotEarnBalance);

        // withdraw all the balance
        let all = game_cap.balance.withdraw_all();
        transfer::public_transfer(coin::from_balance(all, ctx), game_cap.publisher_address);
    }

    entry fun withdraw(_: &Publisher, game_cap: &mut GameCap, ctx: &mut TxContext) {
        withdraw_(game_cap, ctx);
    }

    public fun borrow_balance_mut(game_cap: &mut GameCap): &mut Balance<SUI> {
        &mut game_cap.balance
    }
}