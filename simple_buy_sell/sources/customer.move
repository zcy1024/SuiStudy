module simple_buy_sell::customer {
    use sui::sui::SUI;
    use sui::coin::Coin;
    use std::string::String;

    use simple_buy_sell::shop::Shop;

    const ErrNotEnoughPrice: u64 = 3;

    public struct Product has key {
        id: UID,
        item_id: ID,
        name: String,
        introduction: String,
    }

    entry fun buy(shop: &mut Shop, item_id: ID, mut sui: Coin<SUI>, ctx: &mut TxContext) {
        let (name, introduction, price) = shop.get(item_id);

        // assert the coin value
        assert!(sui.value() >= price, ErrNotEnoughPrice);

        // transfer coin
        let pay_coin = sui.split(price, ctx);
        shop.join(pay_coin);

        // deal with remaining currency
        if (sui.value() == 0) {
            sui.destroy_zero();
        } else {
            transfer::public_transfer(sui, tx_context::sender(ctx));
        };

        // get the product
        transfer::transfer(Product {
            id: object::new(ctx),
            item_id,
            name,
            introduction,
        }, tx_context::sender(ctx));
    }
}