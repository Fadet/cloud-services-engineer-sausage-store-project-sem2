ALTER TABLE order_product
    ADD CONSTRAINT fk_order_product_order
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE;

ALTER TABLE order_product
    ADD CONSTRAINT fk_order_product_product
        FOREIGN KEY (product_id) REFERENCES product (id);

ALTER TABLE order_product
    ADD CONSTRAINT chk_order_product_quantity CHECK (quantity > 0);
