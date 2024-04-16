module simple_buy_sell::shop {
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use std::string::String;

    const ErrNotBalance: u64 = 0;
    const ErrNotItem: u64 = 1;
    const ErrNotEnoughItem: u64 = 2;

    public struct ShopCap has key {
        id: UID,
    }

    public struct Shop has key {
        id: UID,
        name: String,
        balance: Balance<SUI>,
        commodity: vector<Item>,
    }

    public struct Item has store, drop {
        id: ID,
        name: String,
        introduction: String,
        stock: u64,
        price: u64,
    }

    entry fun create_shop(name: String, ctx: &mut TxContext) {
        // only ShopCap holders can make subsequent modifications to the shop
        transfer::transfer(ShopCap {id: object::new(ctx)}, tx_context::sender(ctx));

        // anyone can view shop information
        transfer::share_object(Shop {
            id: object::new(ctx),
            name,
            balance: balance::zero(),
            commodity: vector::empty<Item>(),
        });
    }

    entry fun withdraw(_shop_cap: &ShopCap, shop: &mut Shop, ctx: &mut TxContext) {
        // assert the balance
        assert!(shop.balance.value() > 0, ErrNotBalance);

        // take all balance
        let all = shop.balance.withdraw_all();

        // transfer the coin
        transfer::public_transfer(coin::from_balance(all, ctx), tx_context::sender(ctx));
    }

    entry fun destroy_shop(shop_cap: ShopCap, mut shop: Shop, ctx: &mut TxContext) {
        // withdraw
        if (shop.balance.value() > 0) {
            withdraw(&shop_cap, &mut shop, ctx);
        };

        // destroy ShopCap
        let ShopCap {id} = shop_cap;
        object::delete(id);

        // destroy Shop
        let Shop {
            id,
            name: _,
            balance,
            mut commodity,
        } = shop;
        object::delete(id);
        // destroy balance
        balance.destroy_zero();
        // destroy vector
        while (commodity.length() > 0) {
            commodity.pop_back();
        };
        commodity.destroy_empty();
    }

    entry fun create_item(
        _shop_cap: &ShopCap,
        shop: &mut Shop,
        name: String,
        introduction: String,
        stock: u64,
        price: u64,
        ctx: &mut TxContext
    ) {
        // create Item
        let item = Item {
            id: tx_context::fresh_object_address(ctx).to_id(), // address.to_id()
            name,
            introduction,
            stock,
            price,
        };

        // store it
        shop.commodity.push_back(item);
    }

    entry fun modify_stock(_shop_cap: &ShopCap, shop: &mut Shop, id: ID, stock: u64) {
        let mut i = 0;
        let mut modify_success = false;

        while (i < shop.commodity.length()) {
            let item = &mut shop.commodity[i];

            // check if the correct item
            if (id != item.id) {
                i = i + 1;
                continue
            };

            // modify the stock and break this while
            modify_success = true;
            item.stock = stock;
            break
        };

        // assert success
        assert!(modify_success, ErrNotItem);
    }

    entry fun remove_item(_shop_cap: &ShopCap, shop: &mut Shop, id: ID) {
        let mut i = 0;
        let mut modify_success = false;

        while (i < shop.commodity.length()) {
            let item = &mut shop.commodity[i];

            // check if the correct item
            if (id != item.id) {
                i = i + 1;
                continue
            };

            // remove the item and break this while
            modify_success = true;
            shop.commodity.remove(i);
            break
        };

        // assert success
        assert!(modify_success, ErrNotItem);
    }

    public fun get(shop: &mut Shop, id: ID): (String, String, u64) {
        let mut i = 0;
        while (i < shop.commodity.length() && shop.commodity[i].id != id) {
            i = i + 1;
        };

        // assert the correct item id
        assert!(i < shop.commodity.length(), ErrNotItem);

        let item = &mut shop.commodity[i];
        // assert the stock
        assert!(item.stock > 0, ErrNotEnoughItem);
        // decrease the stock
        item.stock = item.stock - 1;

        // return
        (item.name, item.introduction, item.price)
    }

    public fun join(shop: &mut Shop, coin: Coin<SUI>) {
        shop.balance.join(coin.into_balance());
    }
}