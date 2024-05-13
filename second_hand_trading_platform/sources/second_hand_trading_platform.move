module second_hand_trading_platform::second_hand_trading_platform {
    use sui::sui::SUI;
    use sui::coin::Coin;
    use sui::dynamic_field;
    use sui::dynamic_object_field;
    use sui::event;
    use std::string::{Self, String};

    // ====== error code ======

    const ENotAddZeroStockProduct: u64 = 0;
    const ENotCorrectDescription: u64 = 1;
    const ENotCorrectProductID: u64 = 2;
    const ENotEnoughPayCoin: u64 = 3;
    const ENotPermissionToDestroy: u64 = 4;
    const ENotPermissionToModify: u64 = 5;

    // ====== struct ======

    public struct ProductList has key {
        id: UID,
        product_ids: vector<ID>,
        publisher: address,
    }

    public struct ProductInfo has key, store {
        id: UID,
        name: String,
        price: u64,
        stock: u64,
        desc_keys: vector<String>,
        seller: address,
    }

    public struct ProductEvent has copy, drop {
        product_id: ID,
        product_detailed_infomation: String,
    }

    // ====== function ======

    fun init(ctx: &mut TxContext) {
        transfer::share_object(ProductList {
            id: object::new(ctx),
            product_ids: vector<ID>[],
            publisher: ctx.sender(),
        });
    }

    entry fun add_product(product_list: &mut ProductList, name: String, price: u64, stock: u64, description: vector<String>, ctx: &mut TxContext) {
        // check
        assert!(stock > 0, ENotAddZeroStockProduct);
        assert!(description.length() % 2 == 0, ENotCorrectDescription);

        // create product info
        let mut product_info = ProductInfo {
            id: object::new(ctx),
            name,
            price,
            stock,
            desc_keys: vector<String>[],
            seller: ctx.sender(),
        };

        // dynamic field
        let mut i = 0;
        while (i < description.length()) {
            let key = description[i];
            i = i + 1;
            let value = description[i];
            i = i + 1;

            product_info.desc_keys.push_back(key);
            dynamic_field::add(&mut product_info.id, key, value);
        };

        // dynamic object field
        let product_id = object::id(&product_info);
        product_list.product_ids.push_back(product_id);
        dynamic_object_field::add(&mut product_list.id, product_id, product_info);
    }

    fun splicing(info: &mut String, key: String, value: String) {
        info.append_utf8(b"\n");
        info.append(key);
        info.append_utf8(b": ");
        info.append(value);
        info.append_utf8(b"\n");
    }

    fun num_to_string(mut num: u64): String {
        let mut byte_num = vector<u8>[];
        while (num > 0) {
            byte_num.push_back(b"0"[0] + ((num % 10) as u8));
            num = num / 10;
        };
        byte_num.reverse();
        string::utf8(byte_num)
    }

    entry fun query_product_list(product_list: &ProductList) {
        let mut i = 0;
        let product_ids = &product_list.product_ids;
        while (i < product_ids.length()) {
            // get product id
            let product_id = product_ids[i];
            i = i + 1;
            // get product info
            let product_info: &ProductInfo = dynamic_object_field::borrow(&product_list.id, product_id);

            // init product detailed infomation
            let mut product_detailed_infomation = string::utf8(b"");
            // name, price, stock
            splicing(&mut product_detailed_infomation, string::utf8(b"name"), product_info.name);
            splicing(&mut product_detailed_infomation, string::utf8(b"price"), num_to_string(product_info.price));
            splicing(&mut product_detailed_infomation, string::utf8(b"stock"), num_to_string(product_info.stock));
            // dynamic field desc
            let mut j = 0;
            let desc_keys = &product_info.desc_keys;
            while (j < desc_keys.length()) {
                // get key
                let key = desc_keys[j];
                j = j + 1;
                // get value
                let value: String = *dynamic_field::borrow(&product_info.id, key);
                splicing(&mut product_detailed_infomation, key, value);
            };

            // emit event
            event::emit(ProductEvent {
                product_id,
                product_detailed_infomation,
            });
        };
    }

    entry fun destroy_product(product_id: ID, product_list: &mut ProductList, ctx: &TxContext) {
        // check exist_
        let (has_id, index) = product_list.product_ids.index_of(&product_id);
        assert!(has_id, ENotCorrectProductID);
        // remove
        product_list.product_ids.remove(index);

        // remove and get product info
        let mut product_info: ProductInfo = dynamic_object_field::remove(&mut product_list.id, product_id);

        // check permission
        assert!(product_info.stock == 0 || product_info.seller == ctx.sender(), ENotPermissionToDestroy);

        // remove dynamic field
        while (product_info.desc_keys.length() > 0) {
            let key = product_info.desc_keys.pop_back();
            let _: String = dynamic_field::remove(&mut product_info.id, key);
        };

        // destroy ProductInfo
        let ProductInfo {
            id,
            name: _,
            price: _,
            stock: _,
            desc_keys,
            seller: _,
        } = product_info;
        object::delete(id);
        desc_keys.destroy_empty();
    }

    entry fun buy(product_id: ID, product_list: &mut ProductList, mut pay: Coin<SUI>, ctx: &mut TxContext) {
        // check exist_
        assert!(dynamic_object_field::exists_(&product_list.id, product_id), ENotCorrectProductID);

        // get product info
        let product_info: &mut ProductInfo = dynamic_object_field::borrow_mut(&mut product_list.id, product_id);

        // check price amount
        assert!(pay.value() >= product_info.price, ENotEnoughPayCoin);

        // split accurate coin
        let mut accurate_coin = pay.split(product_info.price, ctx);
        // deal with the remaining coin
        if (pay.value() > 0) {
            transfer::public_transfer(pay, ctx.sender());
        } else {
            pay.destroy_zero();
        };

        // 1% fee to the publisher
        if (product_info.price / 100 > 0) {
            transfer::public_transfer(accurate_coin.split(product_info.price / 100, ctx), product_list.publisher);
        };

        // pay accurate coin
        transfer::public_transfer(accurate_coin, product_info.seller);

        // update stock
        product_info.stock = product_info.stock - 1;

        // sold out and removed from shelves
        if (product_info.stock == 0) {
            destroy_product(product_id, product_list, ctx);
        };
    }

    entry fun modify_dynamic(product_id: ID, product_list: &mut ProductList, description: vector<String>, ctx: &TxContext) {
        // check exist_
        assert!(dynamic_object_field::exists_(&product_list.id, product_id), ENotCorrectProductID);

        // get product info
        let product_info: &mut ProductInfo = dynamic_object_field::borrow_mut(&mut product_list.id, product_id);

        // check permission
        assert!(product_info.seller == ctx.sender(), ENotPermissionToModify);

        // check desc
        assert!(description.length() % 2 == 0, ENotCorrectDescription);

        // modify or add new desc
        let mut i = 0;
        while (i < description.length()) {
            let key = description[i];
            i = i + 1;
            let value = description[i];
            i = i + 1;

            if (dynamic_field::exists_(&product_info.id, key)) {
                *dynamic_field::borrow_mut(&mut product_info.id, key) = value;
            } else {
                product_info.desc_keys.push_back(key);
                dynamic_field::add(&mut product_info.id, key, value);
            };
        };
    }
}